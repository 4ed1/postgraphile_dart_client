import 'dart:async';
import 'dart:convert';

import 'package:postgraphile_dart_client/actor.dart';

class NotFoundException implements Exception {}
class AlreadyCreatedException implements Exception {}

abstract class EntityModel<T,K> {
  String get tableNameInCamelCase => camelCase(tableName);
  String get tableNameInCamelCasePlural => pluralize(tableNameInCamelCase);
  String get capitalizedTableNameInCamelCase => capitalize(tableNameInCamelCase);
  String get capitalizedTableNameInCamelCasePlural => capitalize(tableNameInCamelCasePlural);

  String get tableName;

  String get allFields;

  const EntityModel();

  String camelCase(String s) {
    final parts = s.split('_');
    return parts[0] + parts.sublist(1).map(capitalize).join();
  }
  String capitalize(String s) => s[0].toUpperCase() + s.substring(1);
  String pluralize(String s) {
    if (s.endsWith('es'))
      return s;
    if (s.endsWith('s'))
      return s + 'es';
    if (s.endsWith('ey'))
      return s + 's';
    if (s.endsWith('y'))
      return s.substring(0, s.length - 1) + 'ies';
    return s + 's';
  }

  Future<T> fetchOne(Actor actor, String unwrap, String query, {Map<String,String> variables}) async {
    final json = (await actor.api.query(actor.jwt, query))[unwrap];
    if (json == null)
      throw NotFoundException();
    else
      return instanceFromJson(json);
  }

  Future<List<T>> fetch(Actor actor, String unwrap, String query, {Map<String,String> variables}) async =>
      instanceListFromJson((await actor.api.query(actor.jwt, query))[unwrap]).cast<T>();

  Future<T> fetchOneById(Actor actor, K id, String select) async =>
    fetchOne(actor, '${tableNameInCamelCase}ById', '{${tableNameInCamelCase}ById(id: ${json.encode(id)}) { $select }}');

  Future<List<T>> fetchAll(Actor actor, String select, {String parameters}) {
    final key = 'all${capitalizedTableNameInCamelCasePlural}List';
    return fetch(actor, key, '{$key${parameters != null ? '($parameters)' : ''} { $select }}');
  }

  Future<int> fetchCount(Actor actor, {String parameters}) async {
    final key = 'all$capitalizedTableNameInCamelCasePlural';
    return (await actor.api.query(actor.jwt,
      '{$key${parameters != null ? '($parameters)' : ''} { totalCount }}'))[key]['totalCount'];
  }

  List<T> instanceListFromJson(List<dynamic> jsonList) => jsonList.map((j) => tryInstanceFromJson(j)).toList();

  T ifNotNull<T>(dynamic objectOrNull, T Function(dynamic object) f) =>
      objectOrNull != null ? f(objectOrNull) : null;

  T instanceFromJson(Map<String, dynamic> json);

  T tryInstanceFromForeign(dynamic json, String foreignKey) {
    final populatedKey = '${tableNameInCamelCase}By${capitalize(camelCase(foreignKey))}';
    if (json[populatedKey] != null)
      return instanceFromJson(json[populatedKey]);

    final value = json[foreignKey];
    if (value == null)
      return null;
    else if (value is K)
      return instanceFromJson({'id': value});
    else
      return null;
  }

  List<T> tryInstanceListFromForeign(dynamic json, String foreignKey) {
    final key = '${tableNameInCamelCasePlural}By${capitalize(camelCase(foreignKey))}List';
    return json[key] == null ? null : instanceListFromJson(json[key]);
  }

  /// Examines the passed field first: If [json] is [null], return [null]. If [json]
  /// is of the key type, we first wrap it in an id field and parse it as an entity
  /// for which only the id was set.
  T tryInstanceFromJson(dynamic json) => json == null ? null : instanceFromJson(json is Map ? json : {'id': json});
}

/// Base for our entity class so that we can specify that every
/// type T will have an [id] attribute.
abstract class EntityBase<K> {
  K id;
}

/// Base class for entity model classes. The [K] generic denotes the type of
/// the key, typically [String] or [int].
///
/// If you find yourself using a composite key, refer to this implementation
/// on which methods to override to change the assumption that [id] will contain
/// the key. Most notably, [delete] and [patch] will require adapting, while
/// [create] will just assign [null] if the key is missing.
abstract class Entity<T extends EntityBase,K> extends EntityBase<K> {
  Future<T> createFuture;
  final EntityModel model;

  Entity([this.model]);

  @override
  String toString() => 'entity $id from $runtimeType';

  /// Two entities are considered if they are of the exact same type and if their ids
  /// are equal. If our side does not have an id, so it has not been created yet, check
  /// if the objects are identical.
  @override
  bool operator==(o) => o is T &&
    ((id != null && id == o.id) || (id == null && identical(o, this)));

  @override
  int get hashCode => id != null ? id.hashCode : super.hashCode;

  Future<T> create(Actor actor, [List<String> onlyKeys]) {
    return createFuture = _create(actor, onlyKeys);
  }

  Future<T> _create(Actor actor, [List<String> onlyKeys]) async {
    assert(actor.api != null && actor.jwt != null);

    if (id != null && automaticId)
      throw AlreadyCreatedException();

    final json = (automaticId ? toJsonNoId() : toJson());
    if (onlyKeys != null)
        json.removeWhere((key, value) => !onlyKeys.contains(key));
    final data = formatGQLData(json);
    final select = automaticId ? '${model.tableNameInCamelCase} { id }' : 'clientMutationId';

    final res = (await actor.api.query(actor.jwt, '''mutation {
      create${model.capitalizedTableNameInCamelCase}(input: {${model.tableNameInCamelCase}: {$data}}) {
        $select
      }
    }'''));

    if (automaticId)
      id = res['create${model.capitalizedTableNameInCamelCase}'][model.tableNameInCamelCase]['id'];

    return this as T;
  }

  /// Whether ids are generated automatically server-side, e.g. by incrementing
  /// or generating UUIDs.
  bool get automaticId => true;

  /// Will either return immediately if the entity is already created or wait
  /// for it to be created.
  Future<T> ensureCreated(Actor actor) {
    if (id == null)
      return create(actor);
    return Future.value(this as T);
  }

  Map<String,dynamic> toJson();
  Map<String,dynamic> toJsonNoId() {
    final j = toJson();
    j.remove('id');
    return j;
  }

  bool get created => id != null;
  bool deleted = false;

  Future<void> delete(Actor actor) async {
    await actor.api.query(actor.jwt, 'mutation {delete${model.capitalizedTableNameInCamelCase}ById(input: {id: ${json.encode(id)}}){clientMutationId}}');
    deleted = true;
  }

  String formatGQLData(Map<String, dynamic> data) => data.entries.fold('', (sum, entry) => sum + '${entry.key}: ${formatGQLValue(entry.key, entry.value)} ');

  String formatGQLValue(String key, dynamic value) {
    if (value is DateTime)
      return json.encode(value.toIso8601String());
    if (value is String || value is int || value == null || value is bool || value is List<int>)
      return json.encode(value);
    if (value is Map)
      return '{${value.entries.map((e) => '${e.key}: ${formatGQLValue(e.key, e.value)}').join(' ')}}';
    if (value is List)
      return '[${value.map((e) => formatGQLValue(null, e)).join(',')}]';
    throw Exception('Unsupported type ${value.runtimeType} for GQL serialization: $value');
  }

  Future<dynamic> patch(Actor actor, Map<String,dynamic> data, {String select}) async {
    final key = 'update${model.capitalizedTableNameInCamelCase}ById';
    final res = (await actor.api.mutate(actor.jwt, '''
      $key(input: {id: ${json.encode(id)} ${model.tableNameInCamelCase}Patch: {${formatGQLData(data)}}}) {
        ${select != null ? '${model.tableNameInCamelCase}{$select}' : 'clientMutationId'}
      }'''));
    return select != null ? res[key][model.tableNameInCamelCase] : null;
  }

  /// [patch] the listed keys. This indirection has the advantage that the entity's
  /// [toJson] will be used to serialize data before patching.
  Future<void> save(Actor actor, List<String> keys, {String select}) =>
    patch(actor, toJson()..removeWhere((key, value) => !keys.contains(key)), select: select);
}


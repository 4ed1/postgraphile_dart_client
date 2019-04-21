import 'dart:async';

import 'package:postgraphile_dart/actor.dart';
import 'package:postgraphile_dart/entity.dart';

import 'package:collection/collection.dart';

mixin EntityCompositeKeyMixin<T extends EntityBase, K> on Entity<T, K> {
  List<String> compositeKeyFields();
  List<dynamic> compositeKeyValues();

  @override
  Future<void> delete(Actor actor) async {
    await actor.api.mutate(actor.jwt,
      'delete${compositeKeySelectorString()}(input: {${compositeKeyInputString()}}) {clientMutationId}');
    deleted = true;
  }

  String compositeKeySelectorString() => '${model.capitalizedTableNameInCamelCase}By${compositeKeyFields().map((key) => model.capitalize(key)).join('And')}';

  String compositeKeyInputString() {
    final values = compositeKeyValues();
    assert(values.every((v) => v != null));
    var input = '';
    for (var i = 0; i < values.length; i++)
      input += '${compositeKeyFields()[i]}: ${formatGQLValue(compositeKeyFields()[i], values[i])} ';
    return input;
  }

  String compositeKeyPrintString() {
    final values = compositeKeyValues();
    var input = '';
    for (var i = 0; i < values.length; i++)
      input += '${compositeKeyFields()[i]}=${values[i]},';
    return input;
  }

  @override
  Future<dynamic> patch(Actor actor, Map<String,dynamic> data, {String select}) =>
    actor.api.mutate(actor.jwt, '''update${compositeKeySelectorString()}(input: {
      ${compositeKeyInputString()}
      ${model.tableNameInCamelCase}Patch: {${formatGQLData(data)}}}) {
        ${select == null ? 'clientMutationId' : '${model.tableNameInCamelCase} { $select }'}
      }
    ''');

  @override
  bool get automaticId => false;

  @override
  bool operator==(o) => o is T && const ListEquality().equals(compositeKeyValues(),
      (o as EntityCompositeKeyMixin).compositeKeyValues());

  @override
  int get hashCode => compositeKeyValues().fold<int>(0, (x, k) => x ^ k.hashCode);

  @override
  String toString() => 'entity (${compositeKeyPrintString()}) from $runtimeType';
}


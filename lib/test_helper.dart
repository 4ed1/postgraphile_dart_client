import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'package:postgraphile_dart/gql.dart';
import 'package:postgraphile_dart/entity.dart';
import 'package:postgraphile_dart/actor.dart';

typedef EntityCreator = Future<Entity> Function(Entity, {Entity cleanupAfter});
typedef CleanupMarker = Entity Function(Entity, {Entity after, bool unmark});
typedef ManagedTester = Future<void> Function(EntityCreator, CleanupMarker);
typedef ManagedTest = void Function(String label, ManagedTester tester, {bool skip});

class BrokenGQL extends GQL {
  BrokenGQL() : super(null);

  @override
  Future<dynamic> query(String jwt, String query, [Map<String,dynamic> variables = const {}]) async =>
    throw Exception();
}

/// A test that manages all created entities and cleans them up after
/// running. Create entities by using the create function provided to
/// the [tester] function. Use the [cleanup] function to mark entities
/// that your test creates for being deleted. You will likely want to
/// mark entites in the same order that you created them, so that
/// depedency issues are resolved automatically. Further, call cleanup
/// as soon as possible to make sure unexpected exceptions don't cause
/// the entity to leak.
@isTest
void managedTest(String label, Actor actor, ManagedTester tester, {bool skip = false}) async {
  final resources = <Entity>[];

  final EntityCreator create = (Entity e, {Entity cleanupAfter}) async {
    final res = await e.create(actor);
    if (cleanupAfter != null)
      resources.insert(resources.indexOf(cleanupAfter), e);
    else
      resources.add(res);
    return res;
  };

  final CleanupMarker cleanup = (Entity e, {Entity after, bool unmark = false}) {
    if (unmark ?? false) {
      resources.remove(e);
      return e;
    }

    if (after != null)
      resources.insert(resources.indexOf(after), e);
    else
      resources.add(e);
    return e;
  };

  test(label, () async {
    try {
      await tester(create, cleanup);
    } finally {
      for (final e in resources.reversed) {
        try {
          await e.delete(actor);
        } catch (error) {
          print('Resource $e could not be cleaned: $error');
        }
      }
    }
  }, skip: skip);
}

class TestHelper {
  static ManagedTest setUpManaged(Actor actor, String endpoint) {
    configureAdmin(actor, endpoint: endpoint);
    return (String label, ManagedTester tester, {bool skip = false}) {
      managedTest(label, actor, tester, skip: skip ?? false);
    };
  }

  static Actor configureAdmin(Actor actor, {String endpoint}) => actor
    ..api ??= GQL(endpoint)
    ..jwt = _readCredentials()['admin_token'];

  static Actor configureAuthenticator(Actor actor, {String endpoint}) => actor
    ..api ??= GQL(endpoint)
    ..jwt = _readCredentials()['authenticator_token'];

  static Map<String,dynamic> _readCredentials() {
    // credentials are placed outside of sources to prevent inclusion as
    // string in bundled source code
    return json.decode(File('dev_token.json').readAsStringSync());
  }

  /// Temporarily replace the given [actor]'s API with one that throws errors on every
  /// action. NB: make sure that the function you're calling is listed below, not all
  /// are currently included.
  static Future<void> useBrokenApi(Actor actor, Future<void> Function() callback) async {
    final oldApi = actor.api;
    try {
      actor.api = BrokenGQL();
      await callback();
    } finally {
      actor.api = oldApi;
    }
  }

  /// Return a random string of at least five characters length
  static String randomString() => Random().nextDouble().toString().substring(2) + 'xxxxx';

  static String randomEmail() => '${randomString()}@example.com';
}


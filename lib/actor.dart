import 'package:postgraphile_dart/gql.dart';

/// An abstraction around whatever entity authorizes queries against
/// your postgraphile endpoint.
abstract class Actor {
  String get jwt;
  GQL get api;
}

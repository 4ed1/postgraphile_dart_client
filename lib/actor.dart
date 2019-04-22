import 'package:postgraphile_dart_client/gql.dart';

/// An abstraction around whatever entity authorizes queries against
/// your postgraphile endpoint.
abstract class Actor {
  String get jwt;
  set jwt(String jwt);

  GQL get api;
  set api(GQL api);
}

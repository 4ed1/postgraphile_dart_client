import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class GQL {
  static const requestQuery = 'query';
  static const requestVariables = 'variables';
  static const responseErrors = 'errors';
  static const responseData = 'data';

  final String endpoint;

  const GQL(this.endpoint);

  /// Run a query against the GraphQL endpoint.
  ///
  /// NOTE: this function will throw errors more strictly than it should. As per the spec,
  ///       a GraphQL query may return both data and errors. When we map this to a future
  ///       we consider every reported error fatal and ignore the data.
  Future<dynamic> query(String jwt, String query, [Map<String,dynamic> variables = const {}]) async {
    // print(query);
    final response = json.decode((await http.post(endpoint, body: json.encode({
      requestQuery: query,
      requestVariables: variables
    }), headers: headers(jwt))).body);

    // print(response);
    if (response[responseErrors] != null)
      throw GQLException(response[responseErrors], query);
    else
      return response[responseData];
  }

  Future<dynamic> mutate(String jwt, String mutation) => query(jwt, 'mutation { $mutation }');

  Map<String,String> headers(String token, {bool isJson = true}) {
    final data = <String,String>{};
    if (isJson)
      data['Content-Type'] = 'application/json';
    if (token != null)
      data['Authorization'] = 'Bearer $token';
    return data;
  }
}

class GQLLocation {
  final int line;
  final int column;
  GQLLocation(this.line, this.column);
  @override
  String toString() => '$line:$column';
}

class GQLError {
  final List<GQLLocation> locations;
  final String message;
  final List<String> path;
  GQLError.fromJson(Map<String,dynamic> data) :
    message = data['message'],
    path = data['path']?.cast<String>(),
    locations = (data['locations'] ?? []).map<GQLLocation>((l) => GQLLocation(l['line'], l['column'])).toList(growable: false);
  @override
  String toString() => '[${locations.map((l) => l.toString()).join(';')}]: $message';
}

class GQLException {
  final List<GQLError> errors;
  final String query;

  GQLException(List<dynamic> errors, this.query) :
    errors = errors.map((e) => GQLError.fromJson(e)).toList(growable: false);

  @override
  String toString() => '${errors.map<String>((error) => error.toString()).join('; ')} ($query)';
}


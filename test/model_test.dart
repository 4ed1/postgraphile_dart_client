import 'package:test/test.dart';

import 'package:postgraphile_dart/test_helper.dart';

import './models.dart';

void main() {
  final admin = User();
  final managedTest = TestHelper.setUpManaged(admin, 'http://127.0.0.1:3000/graphql');

  managedTest('create user model', (create, cleanup) async {
    final user = await create(User(name: 'Joe'));
    expect((await UserModel().fetchOneById(admin, user.id, 'name')).name, 'Joe');
  });
}

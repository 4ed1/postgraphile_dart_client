import 'package:postgraphile_dart/entity.dart';
import 'package:postgraphile_dart/composite_key_mixin.dart';
import 'package:postgraphile_dart/actor.dart';
import 'package:postgraphile_dart/gql.dart';

class UserModel extends EntityModel<User, int> {
  static const keyName = 'name';
  static const keyGroup = 'group';
  static const keyCurrentBook = 'currentBook';
  static const keyId = 'id';
  static const keyRole = 'role';
  static const keyPassword = 'password';
  @override
  String get allFields => '$keyName $keyGroup $keyCurrentBook $keyId $keyRole $keyPassword';

  const UserModel();

  @override
  User instanceFromJson(Map<String, dynamic> json) => User(
    id: json[keyId],
    name: json[keyName],
    role: json[keyRole],
    password: json[keyPassword],
    currentBook: BookModel().tryInstanceFromForeign(json, keyCurrentBook),
    group: GroupModel().tryInstanceFromForeign(json, keyGroup)
  );

  @override
  String get tableName => 'user';
}
class User extends Entity<User, int> with Actor {
  String name;
  Group group;
  Book currentBook;
  String role;
  String password;
  int id;
  @override
  GQL api;
  @override
  String jwt;

  User({
    this.name,
    this.group,
    this.currentBook,
    this.role,
    this.password,
    this.id,
  }) : super(UserModel());

  @override
  Map<String, dynamic> toJson() => {
    UserModel.keyName: name,
    UserModel.keyCurrentBook: currentBook?.id,
    UserModel.keyId: id,
    UserModel.keyPassword: password,
    UserModel.keyRole: role,
    UserModel.keyGroup: group?.id,
  };
}

class BookModel extends EntityModel<Book, int> {
  static const keyName = 'name';
  static const keyId = 'id';
  @override
  String get allFields => '$keyName $keyId';

  const BookModel();

  @override
  Book instanceFromJson(Map<String, dynamic> json) => Book(
    name: json[keyName],
    id: json[keyId],
  );

  @override
  String get tableName => 'book';
}
class Book extends Entity<Book, int> {
  int id;
  String name;

  Book({this.id, this.name}) : super(BookModel());

  @override
  Map<String, dynamic> toJson() => {
    GroupModel.keyName: name,
    GroupModel.keyId: id,
  };
}

class GroupModel extends EntityModel<Group, int> {
  static const keyName = 'name';
  static const keyId = 'id';
  @override
  String get allFields => '$keyName $keyId';

  const GroupModel();

  @override
  Group instanceFromJson(Map<String, dynamic> json) => Group(
    name: json[keyName],
    id: json[keyId],
    bookChoices: BookChoiceModel().tryInstanceListFromForeign(json, BookChoiceModel.keyGroup),
  );

  @override
  String get tableName => 'group';
}
class Group extends Entity<Group, int> {
  String name;
  int id;
  List<User> users;
  List<BookChoice> bookChoices;

  Group({this.name, this.id, this.bookChoices}) : super(GroupModel());

  @override
  Map<String, dynamic> toJson() => {
    GroupModel.keyName: name,
    GroupModel.keyId: id,
  };
}

class BookChoiceModel extends EntityModel<BookChoice, int> {
  static const keyBook = 'book';
  static const keyGroup = 'group';
  @override
  String get allFields => '$keyBook $keyGroup';

  const BookChoiceModel();

  @override
  BookChoice instanceFromJson(Map<String, dynamic> json) => BookChoice(
    group: GroupModel().tryInstanceFromForeign(json, keyGroup),
    book: BookModel().tryInstanceFromForeign(json, keyBook),
  );

  @override
  String get tableName => 'group';
}
class BookChoice extends Entity<BookChoice, void> with EntityCompositeKeyMixin {
  Group group;
  Book book;

  BookChoice({this.group, this.book}) : super(BookChoiceModel());

  @override
  Map<String, dynamic> toJson() => {
    BookChoiceModel.keyBook: book?.id,
    BookChoiceModel.keyGroup: group?.id,
  };

  @override
  List<String> compositeKeyFields() => [BookChoiceModel.keyGroup, BookChoiceModel.keyBook];

  @override
  List<dynamic> compositeKeyValues() => [group?.id, book?.id];
}

import 'package:flutter_observation/flutter_observation.dart';

part 'user.g.dart';

@observableModel
class Address extends _$Address {
  Address({String city = 'Shanghai', String district = 'Pudong'})
    : super(city, district);
}

@observableModel
class User extends _$User {
  User({
    String name = '',
    int age = 18,
    required Address address,
    required ObservableList<String> tags,
  }) : super(name, age, address, tags);

  void celebrateBirthday() => age++;

  void moveCity() {
    address.city = address.city == 'Shanghai' ? 'Hangzhou' : 'Shanghai';
  }

  void replaceAddress() {
    address = address.city == 'Shenzhen'
        ? Address(city: 'Beijing', district: 'Chaoyang')
        : Address(city: 'Shenzhen', district: 'Nanshan');
  }

  void addTag() => tags.add('Tag ${tags.length + 1}');
}

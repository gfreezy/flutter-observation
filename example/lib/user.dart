import 'package:flutter_observation/flutter_observation.dart';

part 'user.g.dart';

@ObservableModel()
class Address extends _$Address {
  Address({String super.city = 'Shanghai', String super.district = 'Pudong'});
}

@ObservableModel()
class User extends _$User {
  User({
    String super.name = '',
    int super.age = 18,
    required Address super.address,
    required ObservableList<String> super.tags,
  });

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

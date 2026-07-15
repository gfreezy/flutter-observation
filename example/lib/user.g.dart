// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// ObservableGenerator
// **************************************************************************

abstract class _$Address with ObservableModelMixin {
  _$Address(String city, String district) : _city = city, _district = district;
  final ObservationKey<String> _cityKey = ObservationKey<String>(
    'Address.city',
  );
  String _city;

  String get city {
    observationAccess(_cityKey);
    return _city;
  }

  set city(String value) {
    if (_city == value) return;
    observationMutation(_cityKey, () {
      _city = value;
    });
  }

  final ObservationKey<String> _districtKey = ObservationKey<String>(
    'Address.district',
  );
  String _district;

  String get district {
    observationAccess(_districtKey);
    return _district;
  }

  set district(String value) {
    if (_district == value) return;
    observationMutation(_districtKey, () {
      _district = value;
    });
  }
}

abstract class _$User with ObservableModelMixin {
  _$User(String name, int age, Address address, ObservableList<String> tags)
    : _name = name,
      _age = age,
      _address = address,
      _tags = tags;
  final ObservationKey<String> _nameKey = ObservationKey<String>('User.name');
  String _name;

  String get name {
    observationAccess(_nameKey);
    return _name;
  }

  set name(String value) {
    if (_name == value) return;
    observationMutation(_nameKey, () {
      _name = value;
    });
  }

  final ObservationKey<int> _ageKey = ObservationKey<int>('User.age');
  int _age;

  int get age {
    observationAccess(_ageKey);
    return _age;
  }

  set age(int value) {
    if (_age == value) return;
    observationMutation(_ageKey, () {
      _age = value;
    });
  }

  final ObservationKey<Address> _addressKey = ObservationKey<Address>(
    'User.address',
  );
  Address _address;

  Address get address {
    observationAccess(_addressKey);
    return _address;
  }

  set address(Address value) {
    if (_address == value) return;
    observationMutation(_addressKey, () {
      _address = value;
    });
  }

  final ObservationKey<ObservableList<String>> _tagsKey =
      ObservationKey<ObservableList<String>>('User.tags');
  ObservableList<String> _tags;

  ObservableList<String> get tags {
    observationAccess(_tagsKey);
    return _tags;
  }

  set tags(ObservableList<String> value) {
    if (_tags == value) return;
    observationMutation(_tagsKey, () {
      _tags = value;
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_observation/flutter_observation.dart';

import 'user.dart';

part 'main.g.dart';

void main() => runApp(const ObservationExample());

@observationWidget
class ObservationExample extends _$ObservationExample {
  const ObservationExample({super.key});

  @observableState
  User createUser() {
    return User(address: Address(), tags: ObservableList(['Flutter']));
  }

  @override
  Widget build(BuildContext context, {required User user}) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Observation')),
        body: Center(child: UserCard(user: user)),
        floatingActionButton: FloatingActionButton(
          onPressed: () => user.name = user.name == 'Tom' ? 'Alice' : 'Tom',
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }
}

@observationWidget
class UserCard extends _$UserCard {
  const UserCard({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Name: ${user.name}'),
        Text('Age: ${user.age}'),
        Text('Tags: ${user.tags.join(', ')}'),
        const SizedBox(height: 12),
        AddressCard(user: user),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: user.celebrateBirthday,
          child: const Text('Birthday'),
        ),
        TextButton(onPressed: user.addTag, child: const Text('Add tag')),
      ],
    );
  }
}

@observationWidget
class AddressCard extends _$AddressCard {
  const AddressCard({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) {
    final address = user.address;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nested observable address'),
            Text('City: ${address.city}'),
            Text('District: ${address.district}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: user.moveCity,
                  child: const Text('Change city'),
                ),
                OutlinedButton(
                  onPressed: user.replaceAddress,
                  child: const Text('Replace address'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

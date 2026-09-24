import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  String name;
  String phone;

  EmergencyContact({
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
    };
  }

  factory EmergencyContact.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends State<EmergencyContactsScreen> {
  static const String _contactsKey = 'emergency_contacts';

  final List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Load previously saved contacts from the phone.
  Future<void> _loadContacts() async {
    final preferences = await SharedPreferences.getInstance();

    final savedContacts =
        preferences.getStringList(_contactsKey);

    if (savedContacts == null) {
      return;
    }

    final loadedContacts = <EmergencyContact>[];

    for (final contactJson in savedContacts) {
      try {
        final decoded =
            jsonDecode(contactJson) as Map<String, dynamic>;

        loadedContacts.add(
          EmergencyContact.fromJson(decoded),
        );
      } catch (_) {
        // Ignore invalid saved contact data.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts
        ..clear()
        ..addAll(loadedContacts);
    });
  }

  // Save all contacts to the phone.
  Future<void> _saveContacts() async {
    final preferences = await SharedPreferences.getInstance();

    final contactsToSave = _contacts
        .map(
          (contact) => jsonEncode(
            contact.toJson(),
          ),
        )
        .toList();

    await preferences.setStringList(
      _contactsKey,
      contactsToSave,
    );
  }

  void _showContactDialog({int? index}) {
    final nameController = TextEditingController(
      text: index != null ? _contacts[index].name : '',
    );

    final phoneController = TextEditingController(
      text: index != null ? _contacts[index].phone : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            index == null
                ? 'Add Emergency Contact'
                : 'Edit Emergency Contact',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name',
                    hintText: 'Example: Mother',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Example: 9876543210',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter both name and mobile number.',
                      ),
                    ),
                  );
                  return;
                }

                if (phone.length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid mobile number.',
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  if (index == null) {
                    _contacts.add(
                      EmergencyContact(
                        name: name,
                        phone: phone,
                      ),
                    );
                  } else {
                    _contacts[index] = EmergencyContact(
                      name: name,
                      phone: phone,
                    );
                  }
                });

                await _saveContacts();

                if (!mounted) {
                  return;
                }

                Navigator.pop(dialogContext);
              },
              child: Text(
                index == null
                    ? 'Add Contact'
                    : 'Save Changes',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContact(int index) async {
    final contactName = _contacts[index].name;

    setState(() {
      _contacts.removeAt(index);
    });

    await _saveContacts();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$contactName removed from emergency contacts.',
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    final contact = _contacts[index];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Contact?'),
          content: Text(
            'Are you sure you want to remove ${contact.name} '
            'from your emergency contacts?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteContact(index);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red.shade100,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.red.shade100,
                      child: Icon(
                        Icons.emergency,
                        color: Colors.red.shade700,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Contacts',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your contacts will receive an SOS '
                            'message after 3 ignored warnings.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'An emergency call will be triggered '
                            'after 6 ignored warnings.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Contacts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_contacts.length}/3',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: _contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contact_phone_outlined,
                              size: 75,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'No emergency contacts added',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add up to 3 trusted contacts.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            elevation: 2,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor:
                                    Colors.red.shade50,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              title: Text(
                                contact.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding:
                                    const EdgeInsets.only(
                                  top: 4,
                                ),
                                child: Text(
                                  contact.phone,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              trailing:
                                  PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showContactDialog(
                                      index: index,
                                    );
                                  } else if (value ==
                                      'delete') {
                                    _showDeleteConfirmation(
                                      index,
                                    );
                                  }
                                },
                                itemBuilder: (context) =>
                                    const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 10),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 10),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _contacts.length >= 3
                      ? null
                      : () => _showContactDialog(),
                  icon: const Icon(Icons.person_add),
                  label: Text(
                    _contacts.length >= 3
                        ? 'Maximum 3 Contacts Added'
                        : 'Add Emergency Contact',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
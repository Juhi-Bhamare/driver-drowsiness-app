import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyCallService {
  static const MethodChannel _channel =
      MethodChannel('driver_drowsiness/sos');

  static const String _contactsKey =
      'emergency_contacts';

  static Future<bool> callFirstEmergencyContact() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      final savedContacts =
          preferences.getStringList(_contactsKey);

      if (savedContacts == null ||
          savedContacts.isEmpty) {
        debugPrint(
          'No emergency contacts saved.',
        );
        return false;
      }

      for (final contactJson in savedContacts) {
        try {
          final decoded =
              jsonDecode(contactJson)
                  as Map<String, dynamic>;

          final phone =
              decoded['phone'] as String?;

          if (phone != null &&
              phone.trim().isNotEmpty) {
            final result =
                await _channel.invokeMethod<bool>(
              'makeEmergencyCall',
              {
                'phoneNumber': phone.trim(),
              },
            );

            return result == true;
          }
        } catch (e) {
          debugPrint(
            'Could not process emergency contact: $e',
          );
        }
      }

      debugPrint(
        'No valid emergency phone number found.',
      );

      return false;
    } catch (e) {
      debugPrint(
        'Emergency call failed: $e',
      );

      return false;
    }
  }
}
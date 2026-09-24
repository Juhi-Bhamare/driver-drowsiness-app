import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';

class EmergencySmsService {
  static const MethodChannel _channel =
      MethodChannel('driver_drowsiness/sos');

  static const String _contactsKey =
      'emergency_contacts';

  static const String _baseSosMessage =
      'EMERGENCY SOS: The driver has ignored 3 consecutive safety warnings. Please contact the driver and check their condition.';

  static Future<bool> sendSosSms() async {
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

      final phoneNumbers = <String>[];

      for (final contactJson in savedContacts) {
        try {
          final decoded =
              jsonDecode(contactJson)
                  as Map<String, dynamic>;

          final phone =
              decoded['phone'] as String?;

          if (phone != null &&
              phone.trim().isNotEmpty) {
            phoneNumbers.add(
              phone.trim(),
            );
          }
        } catch (e) {
          debugPrint(
            'Could not read emergency contact: $e',
          );
        }
      }

      if (phoneNumbers.isEmpty) {
        debugPrint(
          'No valid emergency phone numbers found.',
        );
        return false;
      }

      String message = _baseSosMessage;

      final location =
          await LocationService.getCurrentLocation();

      if (location != null) {
        final latitude =
            location.latitude.toStringAsFixed(6);

        final longitude =
            location.longitude.toStringAsFixed(6);

        final mapsUrl =
            'https://www.google.com/maps/search/?api=1'
            '&query=$latitude,$longitude';

        message +=
            '\n\nDriver location:\n$mapsUrl';

        debugPrint(
          'Emergency location: $latitude, $longitude',
        );
      } else {
        message +=
            '\n\nDriver location: '
            'Location unavailable.';
        
        debugPrint(
          'Emergency location unavailable.',
        );
      }

      final result =
          await _channel.invokeMethod<bool>(
        'sendEmergencySms',
        {
          'phoneNumbers': phoneNumbers,
          'message': message,
        },
      );

      return result == true;
    } catch (e) {
      debugPrint(
        'Emergency SMS failed: $e',
      );

      return false;
    }
  }
}
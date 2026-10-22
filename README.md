# Driver Drowsiness Detection App

A Flutter-based mobile application designed to monitor driver alertness using facial analysis, provide spoken safety warnings, and support emergency-contact notifications.

The application uses Google ML Kit Face Detection to analyze facial features and detect selected signs of drowsiness or distraction. It also includes emergency contact management, location retrieval, and a TensorFlow Lite model asset.

## Features

- **Live camera monitoring:** Uses the device camera to monitor the driver's face.
- **Eye-closure detection:** Uses facial eye-open probabilities and consecutive readings to identify sustained eye closure.
- **Yawning detection:** Uses mouth-opening measurements to identify prolonged mouth opening.
- **Head-turn detection:** Uses horizontal head rotation to identify sustained head turns.
- **Voice warnings:** Uses text-to-speech to provide audible alerts.
- **Emergency contacts:** Add, edit, and delete up to three saved emergency contacts.
- **SOS messaging:** Prepares an emergency message with the driver's location link when location information is available.
- **Emergency calling:** Requests a call to the first usable saved emergency contact through native platform code.
- **Location support:** Uses the device's location services to obtain coordinates for emergency messages.

Emergency SMS and calling depend on the corresponding native Android implementations, platform permissions, device support, and successful execution. These features should be tested on a real device before being described as production-ready.

## Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Mobile application framework |
| Dart | Application programming language |
| `camera` | Camera preview and image capture |
| `google_mlkit_face_detection` | Facial analysis and face measurements |
| `tflite_flutter` | TensorFlow Lite interpreter support |
| `geolocator` | Device location retrieval |
| `flutter_tts` | Spoken warnings |
| `shared_preferences` | Local storage for emergency contacts |
| `MethodChannel` | Communication between Flutter and native platform code |

## How It Works

1. The application initializes the camera and begins monitoring the driver's face.
2. Google ML Kit facial measurements are used by the detection logic to identify sustained eye closure, prolonged mouth opening, and horizontal head turns.
3. When configured detection conditions are met, the application provides spoken warnings.
4. The emergency workflow can request an SOS message after three ignored warnings and an emergency call after six, according to the application's warning logic.
5. The SOS service retrieves saved emergency contact numbers and attempts to include the current location in the message.
6. Native platform code handles the requested SMS or calling operation.

**Model integration note:** The project contains `assets/models/subject_independent_drowsiness_model.tflite`, and the supplied code includes a test that loads the model and prints its tensor information. The reviewed detection code uses ML Kit facial measurements; actual inference using the custom TensorFlow Lite model has not yet been verified.

## Project Structure

```text
driver-drowsiness-app/
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── location_service.dart
│   ├── emergency_sms_service.dart
│   ├── emergency_call_service.dart
│   └── # Other application screens and services
├── assets/
│   └── models/
│       └── subject_independent_drowsiness_model.tflite
├── test/
├── pubspec.yaml
└── README.md
```

*This is an illustrative structure. Update it to reflect the actual repository files.*

## Requirements

- Flutter SDK
- Dart SDK compatible with the installed Flutter version
- Android Studio or Visual Studio Code
- An Android device or emulator with camera support
- Appropriate camera and location permissions
- Native Android configuration for SMS and emergency calling

Some functionality may require a physical device and cannot be fully tested in an emulator.

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/Juhi-Bhamare/driver-drowsiness-app.git
cd driver-drowsiness-app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Check the Flutter environment

```bash
flutter doctor
```

Resolve any relevant SDK or device configuration issues reported by this command.

### 4. Connect a device

Enable USB debugging on a compatible Android phone, or start an Android emulator.

Verify that Flutter can detect the device:

```bash
flutter devices
```

### 5. Run the application

```bash
flutter run
```

Ensure that the model asset is declared correctly in `pubspec.yaml` if the application or model-loading test requires it.

## Permissions and Configuration

The application may require:

- Camera access for live facial monitoring
- Location access for emergency location sharing
- Native platform configuration for emergency SMS and calling

Review the Android manifest, native method-channel handlers, and any relevant iOS configuration before building or distributing the application.

Do not assume an SMS or call succeeded solely because a Flutter method returned a success value. Verify the native implementation and test the result on a suitable device.

## Testing Checklist

- [ ] Camera initialization and camera switching
- [ ] Eye-closure detection under different lighting conditions
- [ ] Yawning and head-turn detection
- [ ] Spoken warning playback
- [ ] Adding, editing, deleting, and retaining emergency contacts
- [ ] Location retrieval when permission is granted
- [ ] Graceful handling of denied location permissions
- [ ] SOS behavior when location is unavailable
- [ ] Native SMS and calling behavior
- [ ] Repeated warnings and emergency escalation
- [ ] TensorFlow Lite model loading and inference, if integrated

## Future Improvements

- Complete and verify custom TensorFlow Lite inference integration, if the trained model is intended to power the mobile detection pipeline.
- Improve detection robustness across lighting conditions, face positions, and camera devices.
- Add automated tests for detection and emergency workflows.
- Improve error reporting and permission handling.
- Add safeguards against duplicate emergency alerts.
- Evaluate detection performance using representative test data.
- Improve accessibility and user feedback.

## Related Project

The Python model-development repository is available here:

[Driver Drowsiness Detection — Model Development](https://github.com/Juhi-Bhamare/driver-drowsiness-detection)

## Disclaimer

This application is an experimental safety-support project. It is not a certified driver-monitoring or emergency-response system. Do not rely on it as the sole means of preventing accidents or obtaining emergency assistance. Test all functionality carefully before any real-world use.

## Author

**Juhi Bhamare**

GitHub: [@Juhi-Bhamare](https://github.com/Juhi-Bhamare)

import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'emergency_contacts_screen.dart';
import 'emergency_sms_service.dart';
import 'emergency_call_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  runApp(
    DriverDrowsinessApp(cameras: cameras),
  );
}

class DriverDrowsinessApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const DriverDrowsinessApp({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Driver Drowsiness Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        cameras: cameras,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver Drowsiness Detection',
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_car,
                size: 100,
                color: Colors.blue,
              ),

              const SizedBox(height: 30),

              const Text(
                'Driver Safety System',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 15),

              const Text(
                'The camera will monitor the driver face, eyes and mouth.',
                style: TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: cameras.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CameraScreen(
                              cameras: cameras,
                            ),
                          ),
                        );
                      },
                icon: const Icon(
                  Icons.camera_alt,
                ),
                label: const Text(
                  'Start Detection',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EmergencyContactsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.contact_phone,
                ),
                label: const Text(
                  'Emergency Contacts',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 16,
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

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraScreen> createState() =>
      _CameraScreenState();
}

class _CameraScreenState
    extends State<CameraScreen> {
  CameraController? _cameraController;

  late final FaceDetector _faceDetector;

  final FlutterTts _flutterTts =
      FlutterTts();

  Interpreter? _interpreter;

  List<Face> _faces = [];

  int _currentCameraIndex = 0;

  bool _isInitializing = true;

  bool _isProcessingFrame = false;

  // ==========================================================
  // DROWSINESS SETTINGS
  // ==========================================================

  // Below 40% = closed-eye condition.
  static const double eyeClosedThreshold =
      0.40;

  // First warning  = 3 seconds
  // Second warning = 6 seconds
  // Third warning  = 9 seconds
  static const Duration warningInterval =
      Duration(seconds: 3);

  // Maximum number of consecutive drowsiness warnings.
  static const int maximumWarningCount = 6;

  // Number of recent eye measurements
  // used by the median filter.
  static const int smoothingWindowSize =
      9;

  // Require several consecutive closed
  // readings before starting the timer.
  static const int requiredClosedFrames =
      5;

  final List<double>
      _eyeProbabilityHistory = [];

  int _consecutiveClosedFrames = 0;

  DateTime? _eyesClosedStartTime;

  Timer? _statusTimer;

  Duration _closedDuration =
      Duration.zero;

  bool _drowsinessDetected = false;

  int _warningCount = 0;

  // Prevent the Warning 3 SOS from being sent more than once
  // during the same continuous drowsiness episode.
  bool _sosSmsSent = false;

  // Prevent the Warning 6 emergency call from being triggered
  // more than once during the same continuous drowsiness episode.
  bool _emergencyCallTriggered = false;

  double? _smoothedEyeProbability;

  // ==========================================================
  // YAWNING SETTINGS
  // ==========================================================

  // Calibrated using your Vivo V40 measurements.
  static const double
      yawnMouthOpeningThreshold =
      0.160;

  // Mouth must remain open for 1.5 seconds.
  static const Duration yawnDuration =
      Duration(milliseconds: 1500);

  // Prevent repeated detection from
  // the same continuous opening.
  static const Duration yawnCooldown =
      Duration(seconds: 4);

  DateTime? _mouthOpenStartTime;

  bool _yawnAlreadyDetected = false;

  DateTime? _lastYawnTime;

  double? _mouthOpeningRatio;

  Duration _mouthOpenDuration =
      Duration.zero;

  // ==========================================================
  // DISTRACTION SETTINGS
  // ==========================================================

  // Horizontal head rotation threshold.
  //
  // We start with 25 degrees.
  // We can calibrate this using your phone
  // after testing.
  static const double
      distractionAngleThreshold =
      25.0;

  // First distraction warning after 2 seconds.
  static const Duration
      distractionDuration =
      Duration(seconds: 2);

  // After the first warning, repeat every 3 seconds
  // while the driver's head remains turned away.
  static const Duration
      distractionWarningInterval =
      Duration(seconds: 3);

  DateTime? _distractionStartTime;

  Duration _distractionElapsed =
      Duration.zero;

  bool _distractionDetected = false;

  // Number of distraction warnings already triggered
  // during the current continuous head turn.
  int _distractionWarningCount = 0;

  double? _headYawAngle;

  // ==========================================================
  // SPEECH
  // ==========================================================

  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,

        // Required for mouth/yawning detection.
        enableContours: true,

        performanceMode:
            FaceDetectorMode.fast,
      ),
    );

    _setupTextToSpeech();

    _loadModel();

    _initializeCamera();
  }

  // ==========================================================
  // LOAD TFLITE MODEL
  // ==========================================================

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/subject_independent_drowsiness_model.tflite',
      );

      debugPrint('DROWSINESS MODEL LOADED SUCCESSFULLY');
      debugPrint(
        'Model input shape: ${_interpreter!.getInputTensor(0).shape}',
      );
      debugPrint(
        'Model output shape: ${_interpreter!.getOutputTensor(0).shape}',
      );
    } catch (e) {
      debugPrint('DROWSINESS MODEL LOAD FAILED: $e');
    }
  }

  // ==========================================================
  // TEXT TO SPEECH SETUP
  // ==========================================================

  Future<void>
      _setupTextToSpeech() async {
    await _flutterTts.setLanguage(
      'en-US',
    );

    await _flutterTts.setSpeechRate(
      0.45,
    );

    await _flutterTts.setVolume(
      1.0,
    );

    await _flutterTts.setPitch(
      1.0,
    );
  }

  // ==========================================================
  // DROWSINESS WARNING
  // ==========================================================

  Future<void>
      _speakDrowsinessWarning() async {
    if (_isSpeaking) {
      return;
    }

    _isSpeaking = true;

    try {
      await _flutterTts.stop();

      await _flutterTts.speak(
        'Drowsiness detected. Please take a break.',
      );
    } catch (e) {
      debugPrint(
        'Drowsiness TTS error: $e',
      );
    }

    _isSpeaking = false;
  }

  // ==========================================================
  // YAWNING WARNING
  // ==========================================================

  Future<void>
      _speakYawnWarning() async {
    if (_isSpeaking) {
      return;
    }

    _isSpeaking = true;

    try {
      await _flutterTts.stop();

      await _flutterTts.speak(
        'Yawning detected. Please stay alert.',
      );
    } catch (e) {
      debugPrint(
        'Yawn TTS error: $e',
      );
    }

    _isSpeaking = false;
  }

  // ==========================================================
  // DISTRACTION WARNING
  // ==========================================================

  Future<void>
      _speakDistractionWarning() async {
    if (_isSpeaking) {
      return;
    }

    _isSpeaking = true;

    try {
      await _flutterTts.stop();

      await _flutterTts.speak(
        'Stay focused. Keep your eyes on the road.',
      );
    } catch (e) {
      debugPrint(
        'Distraction TTS error: $e',
      );
    }

    _isSpeaking = false;
  }

  // ==========================================================
  // CAMERA INITIALIZATION
  // ==========================================================

  Future<void>
      _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    final controller =
        CameraController(
      widget.cameras[
          _currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();

      _cameraController =
          controller;

      await controller.startImageStream(
        _processCameraImage,
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Camera initialization error: $e',
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  // ==========================================================
  // SWITCH CAMERA
  // ==========================================================

  Future<void>
      _switchCamera() async {
    if (widget.cameras.length < 2) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _faces = [];
    });

    _resetDrowsiness();
    _resetYawnDetection();
    _resetDistraction();

    try {
      await _cameraController
          ?.stopImageStream();

      await _cameraController
          ?.dispose();

      _currentCameraIndex =
          (_currentCameraIndex + 1) %
              widget.cameras.length;

      final newController =
          CameraController(
        widget.cameras[
            _currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.nv21,
      );

      await newController.initialize();

      _cameraController =
          newController;

      await newController
          .startImageStream(
        _processCameraImage,
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Camera switch error: $e',
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  // ==========================================================
  // PROCESS CAMERA IMAGE
  // ==========================================================

  Future<void>
      _processCameraImage(
    CameraImage image,
  ) async {
    if (_isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final inputImage =
          _convertCameraImage(
        image,
      );

      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces =
          await _faceDetector
              .processImage(
        inputImage,
      );

      if (mounted) {
        setState(() {
          _faces = faces;
        });
      }

      // Drowsiness detection.
      _updateDrowsinessState(
        faces,
      );

      // Yawning detection.
      _updateYawnState(
        faces,
      );

      // NEW: distraction detection.
      _updateDistractionState(
        faces,
      );
    } catch (e) {
      debugPrint(
        'Face detection error: $e',
      );
    }

    _isProcessingFrame = false;
  }

  // ==========================================================
  // CONVERT CAMERA IMAGE
  // ==========================================================

  InputImage?
      _convertCameraImage(
    CameraImage image,
  ) {
    if (image.planes.length != 1) {
      return null;
    }

    final plane =
        image.planes.first;

    final bytes = plane.bytes;

    final camera =
        widget.cameras[
            _currentCameraIndex];

    final rotation =
        InputImageRotationValue
            .fromRawValue(
      camera.sensorOrientation,
    );

    if (rotation == null) {
      return null;
    }

    final format =
        InputImageFormatValue
            .fromRawValue(
      image.format.raw,
    );

    if (format == null) {
      return null;
    }

    final metadata =
        InputImageMetadata(
      size: Size(
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      rotation: rotation,
      format: format,
      bytesPerRow:
          plane.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  // ==========================================================
  // DROWSINESS LOGIC
  // ==========================================================

  void _updateDrowsinessState(
    List<Face> faces,
  ) {
    if (faces.isEmpty) {
      _resetDrowsiness();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    final face = faces.first;

    final leftProbability =
        face.leftEyeOpenProbability;

    final rightProbability =
        face.rightEyeOpenProbability;

    if (leftProbability == null ||
        rightProbability == null) {
      _resetDrowsiness();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    // Use the lower eye probability.
    final currentEyeProbability =
        min(
      leftProbability,
      rightProbability,
    );

    _eyeProbabilityHistory.add(
      currentEyeProbability,
    );

    while (_eyeProbabilityHistory
            .length >
        smoothingWindowSize) {
      _eyeProbabilityHistory
          .removeAt(0);
    }

    _smoothedEyeProbability =
        _calculateMedian(
      _eyeProbabilityHistory,
    );

    final eyesClosed =
        _smoothedEyeProbability! <
            eyeClosedThreshold;

    if (eyesClosed) {
      _consecutiveClosedFrames++;

      if (_consecutiveClosedFrames >=
          requiredClosedFrames) {
        _handleStableEyesClosed();
      }
    } else {
      _handleEyesOpen();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================================
  // MEDIAN
  // ==========================================================

  double _calculateMedian(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return 1.0;
    }

    final sortedValues =
        List<double>.from(values)
          ..sort();

    final middle =
        sortedValues.length ~/ 2;

    if (sortedValues.length.isOdd) {
      return sortedValues[middle];
    }

    return (
          sortedValues[middle - 1] +
              sortedValues[middle]
        ) /
        2;
  }

  // ==========================================================
  // EYES CLOSED
  // ==========================================================

  void _handleStableEyesClosed() {
    if (_eyesClosedStartTime ==
        null) {
      _eyesClosedStartTime =
          DateTime.now();

      _closedDuration =
          Duration.zero;

      _drowsinessDetected = false;

      _warningCount = 0;

      _startStatusTimer();

      return;
    }

    final elapsed =
        DateTime.now().difference(
      _eyesClosedStartTime!,
    );

    _closedDuration = elapsed;

    final expectedWarningCount =
        elapsed.inMilliseconds ~/
            warningInterval
                .inMilliseconds;

    if (expectedWarningCount >
        _warningCount &&
        _warningCount < maximumWarningCount) {
      _warningCount = min(
        expectedWarningCount,
        maximumWarningCount,
      );

      _drowsinessDetected = true;

      _speakDrowsinessWarning();

      // Warning 3 sends one SOS SMS to every saved contact.
      if (_warningCount == 3 &&
          !_sosSmsSent) {
        _sendEmergencySosSms();
      }

      // Warning 6 triggers one emergency phone call
      // to the first saved emergency contact.
      if (_warningCount == 6 &&
          !_emergencyCallTriggered) {
        _triggerEmergencyCall();
      }
    }
  }

  // ==========================================================
  // EYES OPEN
  // ==========================================================

  void _handleEyesOpen() {
    _resetDrowsiness();
  }

  // ==========================================================
  // DROWSINESS TIMER
  // ==========================================================

  void _startStatusTimer() {
    _statusTimer?.cancel();

    _statusTimer =
        Timer.periodic(
      const Duration(
        milliseconds: 100,
      ),
      (_) {
        if (_eyesClosedStartTime ==
            null) {
          return;
        }

        final elapsed =
            DateTime.now()
                .difference(
          _eyesClosedStartTime!,
        );

        if (mounted) {
          setState(() {
            _closedDuration =
                elapsed;
          });
        }

        _checkForNextWarning();
      },
    );
  }

  void _checkForNextWarning() {
    if (_eyesClosedStartTime ==
        null) {
      return;
    }

    final elapsed =
        DateTime.now().difference(
      _eyesClosedStartTime!,
    );

    final expectedWarningCount =
        elapsed.inMilliseconds ~/
            warningInterval
                .inMilliseconds;

    if (expectedWarningCount >
        _warningCount &&
        _warningCount < maximumWarningCount) {
      _warningCount = min(
        expectedWarningCount,
        maximumWarningCount,
      );

      _drowsinessDetected = true;

      _speakDrowsinessWarning();

      // Warning 3 sends one SOS SMS to every saved contact.
      if (_warningCount == 3 &&
          !_sosSmsSent) {
        _sendEmergencySosSms();
      }

      // Warning 6 triggers one emergency phone call
      // to the first saved emergency contact.
      if (_warningCount == 6 &&
          !_emergencyCallTriggered) {
        _triggerEmergencyCall();
      }
    }
  }

  // ==========================================================
  // EMERGENCY SOS SMS
  // ==========================================================

  Future<void> _sendEmergencySosSms() async {
    if (_sosSmsSent) {
      return;
    }

    // Mark it immediately so multiple camera/timer callbacks
    // cannot send the same SOS more than once.
    _sosSmsSent = true;

    final success =
        await EmergencySmsService.sendSosSms();

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency SOS message sent to all saved contacts.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send emergency SOS message.',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // EMERGENCY PHONE CALL
  // ==========================================================

  Future<void> _triggerEmergencyCall() async {
    if (_emergencyCallTriggered) {
      return;
    }

    _emergencyCallTriggered = true;

    final success =
        await EmergencyCallService.callFirstEmergencyContact();

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency call initiated to the first saved contact.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not initiate emergency call.',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // RESET DROWSINESS
  // ==========================================================

  void _resetDrowsiness() {
    _eyesClosedStartTime = null;

    _closedDuration =
        Duration.zero;

    _drowsinessDetected = false;

    _consecutiveClosedFrames = 0;

    _warningCount = 0;

    _sosSmsSent = false;

    _emergencyCallTriggered = false;

    _eyeProbabilityHistory.clear();

    _smoothedEyeProbability =
        null;

    _statusTimer?.cancel();

    _statusTimer = null;
  }

  // ==========================================================
  // YAWN DETECTION
  // ==========================================================

  void _updateYawnState(
    List<Face> faces,
  ) {
    if (faces.isEmpty) {
      _resetYawnDetection();
      return;
    }

    final face = faces.first;

    final upperLip =
        face.contours[
          FaceContourType.upperLipTop
        ];

    final lowerLip =
        face.contours[
          FaceContourType.lowerLipBottom
        ];

    if (upperLip == null ||
        lowerLip == null ||
        upperLip.points.isEmpty ||
        lowerLip.points.isEmpty) {
      _resetYawnDetection();
      return;
    }

    final upperLipY =
        _averageY(
      upperLip.points,
    );

    final lowerLipY =
        _averageY(
      lowerLip.points,
    );

    final mouthOpening =
        (lowerLipY - upperLipY)
            .abs();

    final faceHeight =
        face.boundingBox.height;

    if (faceHeight <= 0) {
      _resetYawnDetection();
      return;
    }

    final ratio =
        mouthOpening / faceHeight;

    _mouthOpeningRatio =
        ratio;

    if (ratio >=
        yawnMouthOpeningThreshold) {
      _handleMouthOpen();
    } else {
      _handleMouthClosed();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================================
  // AVERAGE Y
  // ==========================================================

  double _averageY(
    List<Point<int>> points,
  ) {
    if (points.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final point in points) {
      total += point.y;
    }

    return total / points.length;
  }

  // ==========================================================
  // MOUTH OPEN
  // ==========================================================

  void _handleMouthOpen() {
    if (_mouthOpenStartTime ==
        null) {
      _mouthOpenStartTime =
          DateTime.now();

      _mouthOpenDuration =
          Duration.zero;

      return;
    }

    final elapsed =
        DateTime.now().difference(
      _mouthOpenStartTime!,
    );

    _mouthOpenDuration =
        elapsed;

    if (elapsed >=
            yawnDuration &&
        !_yawnAlreadyDetected) {
      final now =
          DateTime.now();

      final canTrigger =
          _lastYawnTime == null ||
              now
                      .difference(
                        _lastYawnTime!,
                      ) >=
                  yawnCooldown;

      if (canTrigger) {
        _yawnAlreadyDetected =
            true;

        _lastYawnTime = now;

        _speakYawnWarning();
      }
    }
  }

  // ==========================================================
  // MOUTH CLOSED
  // ==========================================================

  void _handleMouthClosed() {
    _mouthOpenStartTime = null;

    _mouthOpenDuration =
        Duration.zero;

    _yawnAlreadyDetected =
        false;
  }

  // ==========================================================
  // RESET YAWN
  // ==========================================================

  void _resetYawnDetection() {
    _mouthOpenStartTime = null;

    _mouthOpenDuration =
        Duration.zero;

    _mouthOpeningRatio =
        null;

    _yawnAlreadyDetected =
        false;
  }

  // ==========================================================
  // DISTRACTION DETECTION
  // ==========================================================

  void _updateDistractionState(
    List<Face> faces,
  ) {
    if (faces.isEmpty) {
      _resetDistraction();
      return;
    }

    final face = faces.first;

    final yaw = face.headEulerAngleY;

    if (yaw == null) {
      _resetDistraction();
      return;
    }

    _headYawAngle = yaw;

    // Absolute value detects both left and right head turns.
    final lookingAway =
        yaw.abs() >=
            distractionAngleThreshold;

    if (lookingAway) {
      _handleLookingAway();
    } else {
      _handleLookingForward();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================================
  // DRIVER LOOKING AWAY
  // ==========================================================

  void _handleLookingAway() {
    if (_distractionStartTime == null) {
      _distractionStartTime =
          DateTime.now();

      _distractionElapsed =
          Duration.zero;

      _distractionDetected =
          false;

      _distractionWarningCount = 0;

      return;
    }

    final elapsed =
        DateTime.now().difference(
      _distractionStartTime!,
    );

    _distractionElapsed =
        elapsed;

    // --------------------------------------------------------
    // WARNING SCHEDULE
    // --------------------------------------------------------
    //
    // 2 seconds  -> warning 1
    // 5 seconds  -> warning 2
    // 8 seconds  -> warning 3
    // 11 seconds -> warning 4
    // etc.
    //
    // The timer starts when the driver first looks away.

    int expectedWarningCount = 0;

    if (elapsed >= distractionDuration) {
      expectedWarningCount = 1;

      final additionalElapsed =
          elapsed - distractionDuration;

      expectedWarningCount +=
          additionalElapsed.inMilliseconds ~/
              distractionWarningInterval
                  .inMilliseconds;
    }

    if (expectedWarningCount >
        _distractionWarningCount) {
      _distractionWarningCount =
          expectedWarningCount;

      _distractionDetected =
          true;

      _speakDistractionWarning();
    }
  }

  // ==========================================================
  // DRIVER LOOKING FORWARD
  // ==========================================================

  void _handleLookingForward() {
    _distractionStartTime =
        null;

    _distractionElapsed =
        Duration.zero;

    _distractionDetected =
        false;

    // Start a completely new distraction
    // warning cycle next time the driver looks away.
    _distractionWarningCount = 0;
  }

  // ==========================================================
  // RESET DISTRACTION
  // ==========================================================

  void _resetDistraction() {
    _distractionStartTime =
        null;

    _distractionElapsed =
        Duration.zero;

    _distractionDetected =
        false;

    _distractionWarningCount = 0;

    _headYawAngle = null;
  }

  // ==========================================================
  // EYE STATUS
  // ==========================================================

  String _eyeStatus() {
    if (_faces.isEmpty) {
      return 'FACE NOT DETECTED';
    }

    final face = _faces.first;

    final leftProbability =
        face.leftEyeOpenProbability;

    final rightProbability =
        face.rightEyeOpenProbability;

    if (leftProbability == null ||
        rightProbability == null) {
      return 'EYE PROBABILITY NOT AVAILABLE';
    }

    final left =
        (leftProbability * 100)
            .toStringAsFixed(0);

    final right =
        (rightProbability * 100)
            .toStringAsFixed(0);

    if (_smoothedEyeProbability ==
        null) {
      return 'LEFT: $left%  RIGHT: $right%';
    }

    final smooth =
        (_smoothedEyeProbability! *
                100)
            .toStringAsFixed(0);

    return 'LEFT: $left%  RIGHT: $right%\n'
        'STABLE: $smooth%';
  }

  // ==========================================================
  // YAWN STATUS
  // ==========================================================

  String _yawnStatus() {
    if (_mouthOpeningRatio ==
        null) {
      return 'MOUTH: NOT DETECTED';
    }

    final ratio =
        _mouthOpeningRatio!
            .toStringAsFixed(3);

    final seconds =
        _mouthOpenDuration
                .inMilliseconds /
            1000;

    if (_yawnAlreadyDetected) {
      return '🥱 YAWN DETECTED\n'
          'MOUTH RATIO: $ratio';
    }

    if (_mouthOpenStartTime !=
        null) {
      return 'MOUTH OPEN\n'
          'RATIO: $ratio\n'
          '${seconds.toStringAsFixed(1)}s';
    }

    return 'MOUTH RATIO: $ratio';
  }

  // ==========================================================
  // DISTRACTION STATUS
  // ==========================================================

  String _distractionStatus() {
    if (_headYawAngle == null) {
      return 'HEAD ANGLE: --';
    }

    final angle =
        _headYawAngle!
            .toStringAsFixed(1);

    final elapsedSeconds =
        _distractionElapsed
                .inMilliseconds /
            1000.0;

    if (_distractionDetected) {
      final nextWarningAt =
          distractionDuration.inMilliseconds /
                  1000.0 +
              (_distractionWarningCount *
                  distractionWarningInterval
                      .inMilliseconds /
                  1000.0);

      final remaining =
          max(
        0.0,
        nextWarningAt - elapsedSeconds,
      );

      return '⚠ DISTRACTION DETECTED\n'
          'WARNING $_distractionWarningCount\n'
          'HEAD ANGLE: $angle°\n'
          'NEXT WARNING IN '
          '${remaining.toStringAsFixed(1)}s';
    }

    if (_distractionStartTime !=
        null) {
      final remaining =
          max(
        0.0,
        distractionDuration
                .inMilliseconds /
            1000.0 -
                elapsedSeconds,
      );

      return 'LOOKING AWAY\n'
          'ANGLE: $angle°\n'
          'WARNING IN '
          '${remaining.toStringAsFixed(1)}s';
    }

    return 'HEAD ANGLE: $angle°\n'
        'LOOKING FORWARD';
  }

  // ==========================================================
  // DROWSINESS STATUS
  // ==========================================================

  String _drowsinessStatus() {
    if (_eyesClosedStartTime !=
        null) {
      final seconds =
          _closedDuration
                  .inMilliseconds /
              1000;

      final nextWarningIn =
          warningInterval
                      .inMilliseconds /
                  1000 -
              (seconds %
                  (warningInterval
                          .inMilliseconds /
                      1000));

      if (_drowsinessDetected) {
        if (_warningCount >= maximumWarningCount) {
          return '⚠ DROWSINESS DETECTED\n'
              'WARNING $_warningCount\n'
              'EMERGENCY ESCALATION';
        }

        return '⚠ DROWSINESS DETECTED\n'
            'WARNING $_warningCount\n'
            'NEXT WARNING IN '
            '${nextWarningIn.toStringAsFixed(1)}s';
      }

      final remaining =
          max(
        0.0,
        3.0 - seconds,
      );

      return 'EYES CLOSED\n'
          '${remaining.toStringAsFixed(1)}s remaining';
    }

    return 'DRIVER AWAKE';
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor() {
    if (_drowsinessDetected) {
      return Colors.red;
    }

    if (_distractionDetected) {
      return Colors.deepOrange;
    }

    if (_yawnAlreadyDetected) {
      return Colors.orange;
    }

    if (_eyesClosedStartTime !=
        null) {
      return Colors.amber;
    }

    return Colors.green;
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _statusTimer?.cancel();

    _cameraController?.dispose();

    _faceDetector.close();

    _flutterTts.stop();

    _interpreter?.close();

    super.dispose();
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller =
        _cameraController;

    return Scaffold(
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        title: const Text(
          'Driver Safety Detection',
        ),
        centerTitle: true,
      ),

      body: _isInitializing ||
              controller == null ||
              !controller
                  .value
                  .isInitialized
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera.
                CameraPreview(
                  controller,
                ),

                // Face and eye drawing.
                CustomPaint(
                  painter:
                      FaceAndEyePainter(
                    faces: _faces,
                    imageSize: Size(
                      controller
                          .value
                          .previewSize!
                          .height,
                      controller
                          .value
                          .previewSize!
                          .width,
                    ),
                    isFrontCamera:
                        widget
                                .cameras[
                                    _currentCameraIndex]
                                .lensDirection ==
                            CameraLensDirection
                                .front,
                  ),
                ),

                // ==================================================
                // STATUS INFORMATION
                // ==================================================

                Positioned(
                  top: 15,
                  left: 15,
                  right: 15,
                  child: Column(
                    children: [
                      // Eye status.
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.black
                              .withOpacity(
                            0.75,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child: Text(
                          _eyeStatus(),
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // Yawn status.
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.black
                              .withOpacity(
                            0.75,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child: Text(
                          _yawnStatus(),
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // Distraction status.
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.black
                              .withOpacity(
                            0.75,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child: Text(
                          _distractionStatus(),
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                _distractionDetected
                                    ? Colors
                                        .redAccent
                                    : Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // Main status.
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              _statusColor()
                                  .withOpacity(
                            0.9,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child: Text(
                          _drowsinessStatus(),
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // CAMERA SWITCH BUTTON
                // ==================================================

                Positioned(
                  bottom: 25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _switchCamera,
                      icon: const Icon(
                        Icons
                            .cameraswitch,
                      ),
                      label:
                          const Text(
                        'Switch Camera',
                      ),
                      style:
                          ElevatedButton
                              .styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// FACE AND EYE PAINTER
// ============================================================

class FaceAndEyePainter
    extends CustomPainter {
  final List<Face> faces;

  final Size imageSize;

  final bool isFrontCamera;

  FaceAndEyePainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (imageSize.width == 0 ||
        imageSize.height == 0) {
      return;
    }

    final facePaint =
        Paint()
          ..color =
              Colors.green
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 3;

    final eyePaint =
        Paint()
          ..color =
              Colors.yellow
          ..style =
              PaintingStyle.fill;

    for (final face in faces) {
      final boundingBox =
          face.boundingBox;

      final left =
          boundingBox.left *
              size.width /
              imageSize.width;

      final top =
          boundingBox.top *
              size.height /
              imageSize.height;

      final right =
          boundingBox.right *
              size.width /
              imageSize.width;

      final bottom =
          boundingBox.bottom *
              size.height /
              imageSize.height;

      Rect faceRect =
          Rect.fromLTRB(
        left,
        top,
        right,
        bottom,
      );

      if (isFrontCamera) {
        faceRect =
            Rect.fromLTRB(
          size.width - right,
          top,
          size.width - left,
          bottom,
        );
      }

      canvas.drawRect(
        faceRect,
        facePaint,
      );

      // Left eye.
      final leftEye =
          face.landmarks[
            FaceLandmarkType.leftEye
          ];

      // Right eye.
      final rightEye =
          face.landmarks[
            FaceLandmarkType.rightEye
          ];

      if (leftEye != null) {
        final point =
            _translatePoint(
          leftEye.position,
          size,
        );

        canvas.drawCircle(
          point,
          8,
          eyePaint,
        );
      }

      if (rightEye != null) {
        final point =
            _translatePoint(
          rightEye.position,
          size,
        );

        canvas.drawCircle(
          point,
          8,
          eyePaint,
        );
      }
    }
  }

  Offset _translatePoint(
    Point<int> point,
    Size canvasSize,
  ) {
    double x =
        point.x *
            canvasSize.width /
            imageSize.width;

    final y =
        point.y *
            canvasSize.height /
            imageSize.height;

    if (isFrontCamera) {
      x =
          canvasSize.width - x;
    }

    return Offset(
      x,
      y,
    );
  }

  @override
  bool shouldRepaint(
    covariant FaceAndEyePainter
        oldDelegate,
  ) {
    return oldDelegate.faces !=
            faces ||
        oldDelegate.isFrontCamera !=
            isFrontCamera;
  }
}
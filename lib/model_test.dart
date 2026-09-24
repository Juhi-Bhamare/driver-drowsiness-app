import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final interpreter = await Interpreter.fromAsset(
      'assets/models/subject_independent_drowsiness_model.tflite',
    );

    print('MODEL LOADED SUCCESSFULLY');
    print('Input shape: ${interpreter.getInputTensor(0).shape}');
    print('Input type: ${interpreter.getInputTensor(0).type}');
    print('Output shape: ${interpreter.getOutputTensor(0).shape}');
    print('Output type: ${interpreter.getOutputTensor(0).type}');

    interpreter.close();
  } catch (e) {
    print('MODEL LOAD FAILED');
    print(e);
  }
}
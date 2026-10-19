import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';

void main() async {
  final dependencies = await bootstrap();
  runApp(FatouraApp(dependencies: dependencies));
}

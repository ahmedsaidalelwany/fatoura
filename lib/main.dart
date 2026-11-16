import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'bootstrap.dart';

void main() async {
  runZonedGuarded(
    () async {
      // 1. Guaranteed first line of execution for binary messenger & channel bindings
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Global framework error handler
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint(
          'Flutter Framework Error: ${details.exceptionAsString()}\n${details.stack}',
        );
      };

      // 3. Global platform dispatcher asynchronous error handler
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('PlatformDispatcher Asynchronous Error: $error\n$stack');
        return true; // Prevents the Flutter Engine from silently terminating
      };

      // 4. Safe bootstrap execution with graceful visual error fallback UI
      try {
        final dependencies = await bootstrap();
        runApp(FatouraApp(dependencies: dependencies));
      } catch (error, stackTrace) {
        debugPrint('CRITICAL: Startup initialization failed: $error\n$stackTrace');
        runApp(StartupErrorApp(error: error, stackTrace: stackTrace));
      }
    },
    (Object error, StackTrace stackTrace) {
      debugPrint('Uncaught Zone Error: $error\n$stackTrace');
      try {
        runApp(StartupErrorApp(error: error, stackTrace: stackTrace));
      } catch (_) {}
    },
  );
}

/// A bulletproof, standalone Error Fallback App that requires zero external dependencies,
/// plugins, or custom fonts, ensuring a frame is rendered so the native window shows
/// and the exact startup error is displayed rather than silently crashing.
class StartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const StartupErrorApp({
    super.key,
    required this.error,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    final errorString = error.toString();
    final stackString = stackTrace?.toString() ?? 'No stack trace available';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Startup Error - Fatoura',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDC2626),
          brightness: Brightness.light,
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application Startup Failure / فشل بدء تشغيل التطبيق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          elevation: 2,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card with error summary
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFFFECACA),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 30,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'An unhandled exception occurred during initialization:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  child: SelectableText(
                                    errorString,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons: Copy & Retry
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy Error Details'),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          'Error:\n$errorString\n\nStack Trace:\n$stackString',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Error details copied to clipboard',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Retry Startup'),
                                onPressed: () {
                                  main();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Stack Trace Header & Container
                        const Text(
                          'Detailed Stack Trace:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            stackString,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Color(0xFFE2E8F0),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

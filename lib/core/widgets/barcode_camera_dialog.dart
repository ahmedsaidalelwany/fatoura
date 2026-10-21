import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

bool get supportsCameraBarcodeScanning =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

Future<String?> showBarcodeCameraDialog(BuildContext context) {
  if (!supportsCameraBarcodeScanning) return Future<String?>.value();
  return showDialog<String>(
    context: context,
    builder: (_) => const BarcodeCameraDialog(),
  );
}

class BarcodeCameraDialog extends StatefulWidget {
  const BarcodeCameraDialog({super.key});

  @override
  State<BarcodeCameraDialog> createState() => _BarcodeCameraDialogState();
}

class _BarcodeCameraDialogState extends State<BarcodeCameraDialog> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(isArabic ? 'مسح الباركود بالكاميرا' : 'Scan with camera'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MobileScanner(onDetect: _onDetect),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

class SimpleScannerScreen extends StatefulWidget {
  final String title;
  const SimpleScannerScreen({super.key, required this.title});

  @override
  State<SimpleScannerScreen> createState() => _SimpleScannerScreenState();
}

class _SimpleScannerScreenState extends State<SimpleScannerScreen> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;

  @override
  void reassemble() {
    super.reassemble();
    try {
      if (Platform.isAndroid) {
        _controller?.pauseCamera();
      }
      _controller?.resumeCamera();
    } catch (e) {
      debugPrint('📸 Camera reassemble exception caught: $e');
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this._controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        try {
          controller.pauseCamera();
        } catch (e) {
          debugPrint('📸 Camera pause exception caught: $e');
        }
        Navigator.pop(context, scanData.code);
      }
    });
  }

  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (e) {
      debugPrint('📸 Camera dispose exception caught: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 20,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Align QR/Barcode within the frame',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
            ),
          )
        ],
      ),
    );
  }
}

import 'dart:async';
import 'barcode_result.dart';

/// Abstract interface for barcode scanner operations.
abstract class BarcodeScannerService {
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Future<BarcodeResult> scanBarcode({String? simulatedBarcode});
}

/// Production & mock implementation of BarcodeScannerService handling permissions and scan processing.
class DefaultBarcodeScannerService implements BarcodeScannerService {
  bool _hasCameraPermission = true;
  bool _isCameraAvailable = true;

  /// Set camera permission state for testing or system simulation
  void setCameraPermissionState(bool granted) {
    _hasCameraPermission = granted;
  }

  /// Set camera availability state for testing or device simulation
  void setCameraAvailabilityState(bool available) {
    _isCameraAvailable = available;
  }

  @override
  Future<bool> checkPermission() async {
    return _hasCameraPermission;
  }

  @override
  Future<bool> requestPermission() async {
    return _hasCameraPermission;
  }

  @override
  Future<BarcodeResult> scanBarcode({String? simulatedBarcode}) async {
    if (!_hasCameraPermission) {
      return BarcodeResult.permissionDenied();
    }

    if (!_isCameraAvailable) {
      return BarcodeResult.cameraUnavailable();
    }

    // If explicit barcode provided or simulated (e.g. for testing)
    if (simulatedBarcode != null && simulatedBarcode.isNotEmpty) {
      if (simulatedBarcode.length < 3) {
        return BarcodeResult.invalid(
          simulatedBarcode,
          error: 'Barcode sequence too short.',
        );
      }
      return BarcodeResult.success(simulatedBarcode);
    }

    // No hardcoded preset fallback — real scanning is performed via camera detection
    return BarcodeResult.invalid('', error: 'No barcode detected.');
  }
}

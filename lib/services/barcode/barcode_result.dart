/// Result structure representing a scanned barcode item.
class BarcodeResult {
  final String barcode;
  final String format;
  final DateTime timestamp;
  final bool isValid;
  final String? errorMessage;
  final bool permissionDenied;
  final bool cameraUnavailable;

  const BarcodeResult({
    required this.barcode,
    this.format = 'EAN_13',
    DateTime? timestamp,
    this.isValid = true,
    this.errorMessage,
    this.permissionDenied = false,
    this.cameraUnavailable = false,
  }) : timestamp = timestamp ?? const _DefaultDateTime();

  factory BarcodeResult.success(String barcode, {String format = 'EAN_13'}) {
    return BarcodeResult(
      barcode: barcode.trim(),
      format: format,
      timestamp: DateTime.now(),
      isValid: barcode.trim().isNotEmpty,
    );
  }

  factory BarcodeResult.invalid(String barcode, {String? error}) {
    return BarcodeResult(
      barcode: barcode,
      format: 'UNKNOWN',
      timestamp: DateTime.now(),
      isValid: false,
      errorMessage: error ?? 'Invalid barcode format or unreadable scan.',
    );
  }

  factory BarcodeResult.permissionDenied() {
    return BarcodeResult(
      barcode: '',
      format: 'NONE',
      timestamp: DateTime.now(),
      isValid: false,
      permissionDenied: true,
      errorMessage:
          'Camera permission denied. Please grant camera access in settings.',
    );
  }

  factory BarcodeResult.cameraUnavailable() {
    return BarcodeResult(
      barcode: '',
      format: 'NONE',
      timestamp: DateTime.now(),
      isValid: false,
      cameraUnavailable: true,
      errorMessage: 'Camera is unavailable or not present on this device.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'format': format,
      'timestamp': timestamp.toIso8601String(),
      'isValid': isValid,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'permissionDenied': permissionDenied,
      'cameraUnavailable': cameraUnavailable,
    };
  }

  factory BarcodeResult.fromJson(Map<String, dynamic> json) {
    return BarcodeResult(
      barcode: json['barcode'] as String? ?? '',
      format: json['format'] as String? ?? 'EAN_13',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isValid: json['isValid'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      permissionDenied: json['permissionDenied'] as bool? ?? false,
      cameraUnavailable: json['cameraUnavailable'] as bool? ?? false,
    );
  }
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}

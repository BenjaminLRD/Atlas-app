import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_theme.dart';
import '../models/food_item.dart';
import '../models/food_scan_result.dart';
import '../models/food_analysis_result.dart';
import '../providers/fitness_provider.dart';
import '../services/ai/vision/ai_vision_service.dart';
import '../services/food/food_ai_vision_service.dart';
import '../services/food/off_search_client.dart';
import '../services/food/product_lookup_service.dart';
import '../services/food/product_matcher.dart';
import '../services/nutrition/nutrition_calculator.dart';
import '../services/food/openfoodfacts_service.dart'
    show OpenFoodFactsException;
import '../services/barcode/barcode_scanner_service.dart';
import '../services/nutrition/barcode_food_service.dart';
import '../widgets/nutrition/custom_food_modal.dart';
import '../widgets/nutrition/food_result_parts.dart';
import '../widgets/nutrition/product_match_picker.dart';
import '../widgets/nutrition/food_search_sheet.dart';
import '../widgets/nutrition/scanned_food_result_card.dart';

/// Active mode for unified food scanner
enum UnifiedScanMode { foodAi, barcode }

/// Unified Food Scanner Screen supporting AI Photo Food Recognition and Barcode/QR Product Lookup.
class UnifiedFoodScannerScreen extends StatefulWidget {
  final UnifiedScanMode initialMode;
  final String currentMealId;
  final String currentMealTitle;
  final BarcodeFoodService? barcodeFoodService;
  final BarcodeScannerService? barcodeScannerService;
  final AIVisionService? visionService;
  final MobileScannerController? mobileScannerController;

  const UnifiedFoodScannerScreen({
    super.key,
    this.initialMode = UnifiedScanMode.foodAi,
    this.currentMealId = 'Breakfast',
    this.currentMealTitle = 'Breakfast',
    this.barcodeFoodService,
    this.barcodeScannerService,
    this.visionService,
    this.mobileScannerController,
  });

  static Future<void> show(
    BuildContext context, {
    UnifiedScanMode initialMode = UnifiedScanMode.foodAi,
    String currentMealId = 'Breakfast',
    String currentMealTitle = 'Breakfast',
    BarcodeFoodService? barcodeFoodService,
    BarcodeScannerService? barcodeScannerService,
    AIVisionService? visionService,
    MobileScannerController? mobileScannerController,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => UnifiedFoodScannerScreen(
          initialMode: initialMode,
          currentMealId: currentMealId,
          currentMealTitle: currentMealTitle,
          barcodeFoodService: barcodeFoodService,
          barcodeScannerService: barcodeScannerService,
          visionService: visionService,
          mobileScannerController: mobileScannerController,
        ),
      ),
    );
  }

  @override
  State<UnifiedFoodScannerScreen> createState() =>
      _UnifiedFoodScannerScreenState();
}

class _UnifiedFoodScannerScreenState extends State<UnifiedFoodScannerScreen>
    with WidgetsBindingObserver {
  late UnifiedScanMode _currentMode;
  late final BarcodeFoodService _barcodeFoodService;
  late final BarcodeScannerService _scannerService;
  late final AIVisionService _visionService;
  MobileScannerController? _mobileScannerController;

  final TextEditingController _barcodeInputController = TextEditingController();

  // Barcode State
  bool _isBarcodeLoading = false;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;
  String? _detectedBarcode;
  String? _barcodeErrorMessage;
  String? _scannedBarcodeNotFound;
  String? _unsupportedQrMessage;
  bool _cameraPermissionDenied = false;

  // AI Vision State
  bool _isVisionLoading = false;
  String? _visionErrorMessage;
  FoodScanResult? _aiScanResult;

  // Product lookup after a photo of a packaged product
  bool _isLookingUp = false;
  List<OffProduct>? _lookupCandidates;
  // True while the user must choose; false when the list is only an extra
  // under a result that is already shown.
  bool _candidatesReplaceCard = false;

  // Target Meal Selection
  late String _selectedMealTitle;
  late String _selectedMealId;

  final List<String> _mealOptions = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMode = widget.initialMode;
    _barcodeFoodService =
        widget.barcodeFoodService ?? DefaultBarcodeFoodService();
    _scannerService =
        widget.barcodeScannerService ?? DefaultBarcodeScannerService();
    _visionService = widget.visionService ?? AIVisionService();

    _selectedMealTitle = widget.currentMealTitle.isNotEmpty
        ? widget.currentMealTitle
        : 'Breakfast';
    _selectedMealId = widget.currentMealId.isNotEmpty
        ? widget.currentMealId
        : 'Breakfast';

    _checkBarcodePermissions();
    if (_currentMode == UnifiedScanMode.barcode) {
      _initScannerController();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mobileScannerController == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _mobileScannerController?.stop();
    } else if (state == AppLifecycleState.resumed &&
        _currentMode == UnifiedScanMode.barcode &&
        !_isProcessingScan) {
      _mobileScannerController?.start();
    }
  }

  void _initScannerController() {
    if (_mobileScannerController != null) return;
    _mobileScannerController =
        widget.mobileScannerController ??
        MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
  }

  void _disposeScannerController() {
    if (widget.mobileScannerController == null) {
      _mobileScannerController?.dispose();
    }
    _mobileScannerController = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeScannerController();
    _barcodeInputController.dispose();
    super.dispose();
  }

  Future<void> _checkBarcodePermissions() async {
    final granted = await _scannerService.checkPermission();
    if (!mounted) return;
    setState(() {
      _cameraPermissionDenied = !granted;
    });
  }

  void _switchMode(UnifiedScanMode mode) {
    if (_currentMode == mode) return;
    setState(() {
      _currentMode = mode;
      _barcodeErrorMessage = null;
      _scannedBarcodeNotFound = null;
      _unsupportedQrMessage = null;
      _detectedBarcode = null;
      _isProcessingScan = false;
      _isBarcodeLoading = false;
    });

    if (mode == UnifiedScanMode.barcode) {
      _initScannerController();
    } else {
      _disposeScannerController();
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _mobileScannerController?.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _mobileScannerController?.switchCamera();
    } catch (_) {}
  }

  // ===========================================================================
  // BARCODE & QR SCANNING LOGIC
  // ===========================================================================

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessingScan || _isBarcodeLoading) return;
    // While a lookup error is shown, the camera does not retry by itself; the
    // retry button (or a manual lookup) does.
    if (_barcodeErrorMessage != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _handleDetectedCode(raw, format: barcode.format.name);
        break;
      }
    }
  }

  Future<void> _handleDetectedCode(String rawCode, {String? format}) async {
    if (_isProcessingScan || _isBarcodeLoading) return;

    setState(() {
      _isProcessingScan = true;
      _isBarcodeLoading = true;
      _detectedBarcode = rawCode;
      _barcodeErrorMessage = null;
      _scannedBarcodeNotFound = null;
      _unsupportedQrMessage = null;
    });

    // Check if QR code / URL containing a product code
    String barcodeToLookup = rawCode;
    if (rawCode.startsWith('http://') || rawCode.startsWith('https://')) {
      final uri = Uri.tryParse(rawCode);
      if (uri != null) {
        final segments = uri.pathSegments;
        final productIndex = segments.indexOf('product');
        if (productIndex != -1 && productIndex + 1 < segments.length) {
          barcodeToLookup = segments[productIndex + 1].replaceAll('.json', '');
        } else {
          setState(() {
            _isBarcodeLoading = false;
            _unsupportedQrMessage =
                "QR code detected, but it doesn't contain a supported food/product identifier.";
          });
          return;
        }
      }
    }

    FoodItem? food;
    String? failure;
    try {
      food = await _barcodeFoodService.lookupBarcode(barcodeToLookup);
    } on OpenFoodFactsException catch (e) {
      failure = e.isNetworkError
          ? 'No internet connection. Check your connection and try again.'
          : 'The product database could not be reached. Try again in a moment.';
    } on TimeoutException {
      failure =
          'The product lookup timed out. Check your connection and try again.';
    } catch (_) {
      failure = 'The product lookup failed. Try again.';
    } finally {
      // Always leave the loading state, whatever happened, so scanning and
      // manual lookup can be used again.
      if (mounted) {
        setState(() {
          _isBarcodeLoading = false;
          if (failure != null) _isProcessingScan = false;
        });
      }
    }

    if (!mounted) return;

    if (failure != null) {
      setState(() => _barcodeErrorMessage = failure);
    } else if (food != null) {
      _showBarcodeResultCard(food);
    } else {
      setState(() {
        _scannedBarcodeNotFound = barcodeToLookup;
        _barcodeErrorMessage =
            'Product not found for barcode "$barcodeToLookup".';
      });
    }
  }

  Future<void> _processBarcodeLookup(String rawBarcode) async {
    final clean = rawBarcode.trim();
    if (clean.isEmpty) return;
    await _handleDetectedCode(clean);
  }

  void _resumeScanning() {
    setState(() {
      _isProcessingScan = false;
      _isBarcodeLoading = false;
      _detectedBarcode = null;
      _scannedBarcodeNotFound = null;
      _barcodeErrorMessage = null;
      _unsupportedQrMessage = null;
    });
    try {
      _mobileScannerController?.start();
    } catch (_) {}
  }

  void _showBarcodeResultCard(FoodItem food) {
    ScannedFoodResultCard.show(
      context,
      food: food,
      currentMealId: _selectedMealId,
      currentMealTitle: _selectedMealTitle,
    ).then((_) {
      if (mounted) {
        _resumeScanning();
      }
    });
  }

  // ===========================================================================
  // AI PHOTO FOOD RECOGNITION LOGIC
  // ===========================================================================

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final picked = await _visionService.pickWithOutcome(source: source);
      if (!mounted) return;
      if (picked.outcome != ImagePickOutcome.picked) {
        // Never silent: a cancelled or failed pick says so.
        if (picked.outcome == ImagePickOutcome.failed) {
          setState(() => _visionErrorMessage = picked.message);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(picked.message ?? 'No photo was selected.')),
          );
        }
        return;
      }
      final attachment = picked.attachment!;

      setState(() {
        _isVisionLoading = true;
        _visionErrorMessage = null;
        _aiScanResult = null;
        _lookupCandidates = null;
        _candidatesReplaceCard = false;
      });

      final FoodAnalysisResult analysis = await FoodAIVisionService.instance
          .analyzeMealImage(attachment: attachment);

      if (!mounted) return;

      final aiScan = _scanFromAnalysis(analysis);

      if (!analysis.isPackagedProduct) {
        setState(() {
          _isVisionLoading = false;
          _aiScanResult = aiScan;
        });
        return;
      }

      // A packaged product: look it up in the product database instead of
      // trusting the picture for its size and nutrition.
      setState(() {
        _isVisionLoading = false;
        _isLookingUp = true;
      });
      ProductLookupResult lookup;
      try {
        lookup = await ProductLookupService.instance.lookup(
          _candidateFrom(analysis),
        );
      } catch (_) {
        lookup = const ProductLookupResult.failed(
          LookupFailureKind.unavailable,
          'The product database could not be checked.',
        );
      }
      if (!mounted) return;
      setState(() {
        _isLookingUp = false;
        _applyLookup(lookup, aiScan);
      });
    } on FoodVisionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVisionLoading = false;
        _isLookingUp = false;
        _visionErrorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVisionLoading = false;
        _isLookingUp = false;
        _visionErrorMessage = 'AI unavailable. Try again.';
      });
    }
  }

  /// The AI's reading of the photo as an unverified estimate. For a packaged
  /// product the amount is only a guess until the user confirms it.
  FoodScanResult _scanFromAnalysis(FoodAnalysisResult analysis) {
    final foodItem = analysis.toFoodItem(
      customId: 'ai_scan_${DateTime.now().millisecondsSinceEpoch}',
    );
    return FoodScanResult(
      scanType: FoodScanType.aiVision,
      food: foodItem,
      estimatedQuantity: analysis.servingSize,
      estimatedUnit: analysis.servingUnit,
      // An AI photo estimate is never "High": see photoEstimateLevel.
      confidence: analysis.photoEstimateLevel,
      modelConfidence: analysis.confidence,
      rawResponse: analysis.notes,
      notes: analysis.detectedIngredients.isNotEmpty
          ? 'Ingredients: ${analysis.detectedIngredients.join(", ")}'
          : analysis.notes,
      isAiEstimate: true,
      portionConfirmed: !analysis.isPackagedProduct,
    );
  }

  /// What the photo says about the product, for the database search.
  ProductCandidate _candidateFrom(FoodAnalysisResult analysis) =>
      ProductCandidate(
        name: analysis.foodName,
        brand: analysis.brand,
        variant: analysis.variant,
        sizeValue: analysis.labelPackageSize,
        sizeUnit: analysis.labelPackageUnit,
        barcode: analysis.readBarcode,
      );

  /// A database product as the result. Only an exact match with a stated pack
  /// size has a confirmed amount; for a product the user chose, the size in
  /// its record is a starting point they must confirm.
  FoodScanResult _scanFromProduct(
    OffProduct product,
    ProductMatchKind kind, {
    bool viaBarcode = false,
  }) {
    final basis = product.food.nutritionBasis;
    final exact = kind == ProductMatchKind.exactProduct;
    // How the record was matched and when it was retrieved stay with the food.
    final food = product.food.copyWith(
      sourceMatch: viaBarcode
          ? SourceMatch.barcode
          : (exact ? SourceMatch.exactProduct : SourceMatch.userSelected),
      sourceRetrievedAt: product.food.sourceRetrievedAt ?? DateTime.now(),
    );
    // The starting amount: one serving, the whole package, or the size the
    // record states. Only a stated size of an exact record counts as known.
    final (double quantity, String unit, bool confirmed) = switch (basis) {
      NutritionBasis.perServing => (1.0, 'serving', false),
      NutritionBasis.perPackage => (1.0, 'package', exact),
      _ => (
        product.sizeValue ?? 0.0,
        product.sizeUnit ?? (basis == NutritionBasis.per100ml ? 'ml' : 'g'),
        exact && product.sizeValue != null,
      ),
    };
    return FoodScanResult(
      scanType: FoodScanType.aiVision,
      food: food,
      estimatedQuantity: quantity,
      estimatedUnit: unit,
      confidence: 'Database',
      isAiEstimate: false,
      portionConfirmed: confirmed,
      matchKind: kind,
      lookupNote: viaBarcode
          ? 'Matched by the barcode the AI read from your photo. Check that '
                'this is your product.'
          : (kind == ProductMatchKind.userSelected
                ? 'You chose this match from the database. Check that the '
                      'pack size and values fit what you have.'
                : null),
    );
  }

  void _applyLookup(ProductLookupResult result, FoodScanResult aiScan) {
    const keep = 'Showing the AI estimate; check the size and values.';
    switch (result.status) {
      case LookupStatus.exact:
        final product = result.exact!;
        _aiScanResult = _scanFromProduct(
          product,
          ProductMatchKind.exactProduct,
          viaBarcode: result.viaBarcode,
        );
        // The record is the product but has no nutrition facts: other sizes
        // that do are offered below, never merged into it.
        _lookupCandidates =
            !product.hasNutrition && result.candidates.isNotEmpty
            ? result.candidates
            : null;
        _candidatesReplaceCard = false;
      case LookupStatus.choose:
        _aiScanResult = aiScan.copyWith(
          lookupNote: 'No product was chosen. $keep',
        );
        _lookupCandidates = result.candidates;
        _candidatesReplaceCard = true;
      case LookupStatus.none:
        _aiScanResult = aiScan.copyWith(
          lookupNote: 'No matching product was found online. $keep',
        );
      case LookupStatus.failed:
        _aiScanResult = aiScan.copyWith(
          lookupNote:
              "Couldn't check the product database. ${result.message} $keep",
        );
    }
  }

  void _selectProduct(OffProduct product) {
    setState(() {
      _aiScanResult = _scanFromProduct(product, ProductMatchKind.userSelected);
      _lookupCandidates = null;
      _candidatesReplaceCard = false;
    });
  }

  void _dismissCandidates() {
    setState(() {
      _lookupCandidates = null;
      _candidatesReplaceCard = false;
    });
  }

  /// [confirmSize] opens it as the question "what size is your pack?".
  void _showEditAiFoodEstimateDialog({bool confirmSize = false}) {
    if (_aiScanResult == null) return;

    final scan = _aiScanResult!;
    final currentFood = scan.food;
    final unit = scan.estimatedUnit;
    final portionKnown = scan.portionKnown;
    // With no amount set, the fields start from the food's per-100 values and
    // scale from 100.
    final basePortion = portionKnown ? scan.estimatedQuantity : 100.0;
    final baseCals = portionKnown
        ? scan.estimatedCalories
        : currentFood.calories;
    final baseProtein = portionKnown
        ? scan.estimatedProtein
        : currentFood.protein;
    final baseCarbs = portionKnown
        ? scan.estimatedCarbs
        : currentFood.carbohydrates;
    final baseFat = portionKnown ? scan.estimatedFats : currentFood.fats;

    // An unknown value is a blank field, never a 0.
    String shown(String nutrient, double value, int digits) =>
        scan.isKnown(nutrient) ? value.toStringAsFixed(digits) : '';

    final nameCtrl = TextEditingController(text: currentFood.name);
    final portionCtrl = TextEditingController(
      text: portionKnown ? scan.estimatedQuantity.toStringAsFixed(0) : '',
    );
    final calsCtrl = TextEditingController(
      text: shown(FoodItem.calorieKey, baseCals, 0),
    );
    final proteinCtrl = TextEditingController(
      text: shown(FoodItem.proteinKey, baseProtein, 1),
    );
    final carbsCtrl = TextEditingController(
      text: shown(FoodItem.carbohydrateKey, baseCarbs, 1),
    );
    final fatCtrl = TextEditingController(
      text: shown(FoodItem.fatKey, baseFat, 1),
    );

    portionCtrl.addListener(() {
      final p = double.tryParse(portionCtrl.text);
      if (p != null && p > 0 && basePortion > 0) {
        final factor = p / basePortion;
        calsCtrl.text = shown(FoodItem.calorieKey, baseCals * factor, 0);
        proteinCtrl.text = shown(FoodItem.proteinKey, baseProtein * factor, 1);
        carbsCtrl.text = shown(FoodItem.carbohydrateKey, baseCarbs * factor, 1);
        fatCtrl.text = shown(FoodItem.fatKey, baseFat * factor, 1);
      }
    });

    InputDecoration decoration(String label, String nutrient) =>
        InputDecoration(
          labelText: label,
          hintText: scan.isKnown(nutrient) ? null : 'unknown',
        );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.isDarkMode
              ? const Color(0xFF1B1D24)
              : Colors.white,
          title: Text(
            confirmSize
                ? 'Confirm package size'
                : (scan.matchKind != null
                      ? 'Edit Product Details'
                      : 'Edit AI Food Estimate'),
            style: AppTheme.headlineMd.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (confirmSize) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Enter the amount you have or will have: the size '
                      'printed on your pack, or just the part you drink or '
                      'eat.',
                      style: AppTheme.bodySm.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Food / Meal Name',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: portionCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Portion Size ($unit)',
                    suffixText: unit,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: calsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: decoration(
                          'Calories (kcal)',
                          FoodItem.calorieKey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: proteinCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: decoration(
                          'Protein (g)',
                          FoodItem.proteinKey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: carbsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: decoration(
                          'Carbs (g)',
                          FoodItem.carbohydrateKey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fatCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: decoration('Fat (g)', FoodItem.fatKey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final typedPortion = double.tryParse(portionCtrl.text);
                final hasTyped = typedPortion != null && typedPortion > 0;
                // No amount typed and none set before: nothing to save yet.
                if (!portionKnown && !hasTyped) {
                  Navigator.of(ctx).pop();
                  return;
                }
                final newPortion = hasTyped ? typedPortion : basePortion;
                final factor = newPortion / basePortion;

                // Back to the stored basis: per 100 g for g/ml, else per unit.
                final lower = unit.toLowerCase();
                final perGram =
                    lower == 'g' || lower == 'grams' || lower == 'ml';
                final divisor = perGram ? newPortion / 100.0 : newPortion;

                // A blank field is unknown. A field the user did not touch
                // keeps the exact stored value (the screen shows it rounded,
                // and rounding must not leak into what is logged). A field
                // they changed is their number.
                ({double value, bool unknown, bool changed}) field(
                  String nutrient,
                  TextEditingController c,
                  double base,
                  double stored,
                  int digits,
                ) {
                  final text = c.text.trim();
                  if (text.isEmpty) {
                    return (
                      value: 0,
                      unknown: true,
                      changed: scan.isKnown(nutrient),
                    );
                  }
                  final changed =
                      text != shown(nutrient, base * factor, digits);
                  if (!changed && scan.isKnown(nutrient)) {
                    return (value: stored, unknown: false, changed: false);
                  }
                  final typed = double.tryParse(text);
                  if (typed == null) {
                    return scan.isKnown(nutrient)
                        ? (value: stored, unknown: false, changed: false)
                        : (value: 0, unknown: true, changed: false);
                  }
                  return (
                    value: typed / divisor,
                    unknown: false,
                    changed: true,
                  );
                }

                final cals = field(
                  FoodItem.calorieKey,
                  calsCtrl,
                  baseCals,
                  currentFood.calories,
                  0,
                );
                final protein = field(
                  FoodItem.proteinKey,
                  proteinCtrl,
                  baseProtein,
                  currentFood.protein,
                  1,
                );
                final carbs = field(
                  FoodItem.carbohydrateKey,
                  carbsCtrl,
                  baseCarbs,
                  currentFood.carbohydrates,
                  1,
                );
                final fat = field(
                  FoodItem.fatKey,
                  fatCtrl,
                  baseFat,
                  currentFood.fats,
                  1,
                );

                // The values count as the user's own only if a field no
                // longer shows what the portion alone would give.
                final valuesChanged =
                    cals.changed ||
                    protein.changed ||
                    carbs.changed ||
                    fat.changed;

                final updatedFood = currentFood.copyWith(
                  name: newName.isNotEmpty ? newName : currentFood.name,
                  calories: cals.value,
                  protein: protein.value,
                  carbohydrates: carbs.value,
                  fats: fat.value,
                  servingSize: '${newPortion.toStringAsFixed(0)}$unit',
                  unknownNutrients: {
                    if (cals.unknown) FoodItem.calorieKey,
                    if (protein.unknown) FoodItem.proteinKey,
                    if (carbs.unknown) FoodItem.carbohydrateKey,
                    if (fat.unknown) FoodItem.fatKey,
                  },
                  nutritionSource: valuesChanged
                      ? NutritionSource.userEntry
                      : null,
                );

                final portionChanged =
                    !portionKnown || newPortion != basePortion;
                setState(() {
                  _aiScanResult = _aiScanResult!.copyWith(
                    food: updatedFood,
                    estimatedQuantity: newPortion,
                    portionConfirmed:
                        scan.portionConfirmed || confirmSize || portionChanged,
                  );
                });

                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  /// Logging needs an amount the user has seen: a guess or a record's size
  /// is confirmed first.
  void _onAddPressed() {
    final scan = _aiScanResult;
    if (scan == null) return;
    if (!scan.portionConfirmed || !scan.portionKnown) {
      _showEditAiFoodEstimateDialog(confirmSize: true);
      return;
    }
    _logAiFoodToMeal();
  }

  Future<void> _logAiFoodToMeal() async {
    if (_aiScanResult == null) return;

    final provider = FitnessProvider.instance;
    final food = _aiScanResult!.food;
    final quantity = _aiScanResult!.estimatedQuantity;
    final unit = _aiScanResult!.estimatedUnit;

    // Unknown calories are never logged as a quiet 0 kcal.
    if (food.caloriesUnknown) {
      final ok = await confirmLogUnknownCalories(context, food.name);
      if (!ok || !mounted) return;
    }

    // The food is logged as it is (per-100 values, unknown nutrients, source
    // and basis), not rebuilt from the displayed totals.
    await provider.addFoodToMeal(_selectedMealId, food, quantity, unit);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${food.name} (${quantity.toStringAsFixed(0)}$unit) to $_selectedMealTitle!',
        ),
        backgroundColor: AppColors.primaryContainer,
      ),
    );

    Navigator.of(context).pop();
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1015) : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SCAN FOOD & PRODUCTS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Segmented Control: [ 📷 AI Photo ] [ 🔳 Barcode ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B1D24)
                      : Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        title: '📷 AI Photo',
                        mode: UnifiedScanMode.foodAi,
                      ),
                    ),
                    Expanded(
                      child: _buildModeTab(
                        title: '🔳 Barcode',
                        mode: UnifiedScanMode.barcode,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Target Meal Selector Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Meal:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _mealOptions.map((meal) {
                          final isSel =
                              _selectedMealTitle.toLowerCase() ==
                              meal.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(meal),
                              selected: isSel,
                              onSelected: (_) {
                                setState(() {
                                  _selectedMealTitle = meal;
                                  _selectedMealId = meal;
                                });
                              },
                              selectedColor: AppColors.primaryContainer,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSel ? Colors.black : Colors.white,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Mode Content (AI Photo vs Barcode)
            Expanded(
              child: _currentMode == UnifiedScanMode.foodAi
                  ? _buildAiVisionContent()
                  : _buildBarcodeContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({required String title, required UnifiedScanMode mode}) {
    final isActive = _currentMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // AI VISION CONTENT WIDGETS
  // ===========================================================================

  Widget _buildAiVisionContent() {
    if (_isVisionLoading || _isLookingUp) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryContainer),
            const SizedBox(height: 20),
            Text(
              _isLookingUp ? 'Looking up the product...' : 'Analyzing food...',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isLookingUp
                  ? 'Checking the product database for its real nutrition...'
                  : 'Estimating calories & calculating macros...',
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    final candidates = _lookupCandidates;
    if (candidates != null && _candidatesReplaceCard) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ProductMatchPicker(
          title: 'Which product is this?',
          candidates: candidates,
          onSelected: _selectProduct,
          onDismiss: _dismissCandidates,
        ),
      );
    }

    if (_aiScanResult != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAiFoodEstimateCard(),
            if (candidates != null) ...[
              const SizedBox(height: 16),
              ProductMatchPicker(
                title: 'Same product, other sizes',
                candidates: candidates,
                onSelected: _selectProduct,
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.camera_enhance_rounded,
              color: AppColors.primaryContainer,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan your meal or barcode',
            style: AppTheme.headlineLg.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo of your meal or choose from your gallery to estimate calories, protein, and macros with AI Vision.',
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons: Camera & Gallery
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('From Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.primaryContainer.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_visionErrorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _visionErrorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiFoodEstimateCard() {
    final scan = _aiScanResult!;
    final food = scan.food;
    final fromDatabase = scan.matchKind != null;
    final edited = food.nutritionSource == NutritionSource.userEntry;
    final lowConfidence = scan.confidence == FoodAnalysisResult.photoLevelLow;
    final noNutrition = food.nutritionUnavailable;
    final showValues = scan.portionKnown;
    // AI numbers are estimates and say so; database numbers do not.
    final tilde = scan.isAiEstimate ? '~' : '';

    // Where the numbers come from, in words that do not overstate it.
    final FoodSourceKind badgeKind;
    String? badgeLabel;
    if (edited) {
      badgeKind = FoodSourceKind.userEntry;
      badgeLabel = 'Edited by you';
    } else if (fromDatabase) {
      badgeKind = FoodSourceKind.database;
      final partial = food.hasUnknownNutrition && !noNutrition;
      if (noNutrition) {
        badgeLabel = 'Product database • no nutrition';
      } else if (scan.matchKind == ProductMatchKind.userSelected) {
        badgeLabel = 'Database match you chose${partial ? ' • partial' : ''}';
      } else {
        badgeLabel = 'Product database${partial ? ' • partial' : ''}';
      }
    } else {
      badgeKind = lowConfidence
          ? FoodSourceKind.aiLow
          : FoodSourceKind.aiEstimate;
    }

    String? total(String nutrient, double value, int digits) =>
        showValues && scan.isKnown(nutrient)
        ? value.toStringAsFixed(digits)
        : null;
    final calories = total(FoodItem.calorieKey, scan.estimatedCalories, 0);
    double? grams(String nutrient, double value) =>
        showValues && scan.isKnown(nutrient) ? value : null;

    String size(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    // What one serving or the whole package is, when the source says.
    final reference = switch (food.nutritionBasis) {
      NutritionBasis.perServing when food.servingQuantity != null =>
        ' (1 serving = ${size(food.servingQuantity!)} '
            '${food.servingQuantityUnit})',
      NutritionBasis.perPackage when food.packageQuantity != null =>
        ' (package = ${size(food.packageQuantity!)} '
            '${food.packageQuantityUnit})',
      _ => '',
    };
    final portion = !scan.portionKnown
        ? 'not set'
        : '$tilde${scan.estimatedQuantity.toStringAsFixed(0)} '
              '${scan.estimatedUnit}$reference'
              '${scan.portionConfirmed ? '' : ' • not confirmed'}';

    final notices = <Widget>[
      if (scan.isAiEstimate)
        const NoticeLine(
          icon: Icons.info_outline_rounded,
          text:
              'Estimated by AI from your photo, not package or database '
              'data. Check the portion and values before logging.',
          textKey: Key('ai_estimate_disclaimer'),
        ),
      if (fromDatabase && !edited && food.sourceUrl != null)
        SourceNote(food: food, textKey: const Key('product_source_note')),
      if (fromDatabase && noNutrition)
        const NoticeLine(
          icon: Icons.help_outline_rounded,
          text:
              'This product is in the database but has no nutrition facts. '
              'Enter the values from the pack, or choose another size below.',
          textKey: Key('product_no_nutrition_note'),
        ),
      if (!scan.caloriesMatchMacros)
        const NoticeLine(
          icon: Icons.rule_rounded,
          text:
              'The calories and macros do not add up closely. '
              'Please check the values.',
          textKey: Key('ai_estimate_mismatch'),
        ),
      if (scan.lookupNote != null)
        NoticeLine(
          icon: Icons.travel_explore_rounded,
          text: scan.lookupNote!,
          textKey: const Key('lookup_note'),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FoodResultStyle.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FoodResultStyle.hairline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What it is, and how far to trust it.
          Row(
            children: [
              Text(
                fromDatabase ? 'PRODUCT MATCH' : 'AI FOOD ESTIMATE',
                style: FoodResultStyle.body(
                  size: 10,
                  weight: FontWeight.w800,
                ).copyWith(letterSpacing: 1.0),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SourceBadge(
                    kind: badgeKind,
                    label: badgeLabel,
                    textKey: const Key('ai_estimate_label'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            food.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FoodResultStyle.title(),
          ),
          if (food.brand != null && food.brand!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              food.brand!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FoodResultStyle.body(size: 13, weight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          ServingRow(
            value: portion,
            editLabel: scan.portionConfirmed ? 'Edit' : 'Confirm',
            onEdit: () => _showEditAiFoodEstimateDialog(
              confirmSize: !scan.portionConfirmed,
            ),
          ),
          const SizedBox(height: 14),

          // Calories first, then where they come from.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FoodResultStyle.raised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalorieHero(value: calories == null ? '—' : '$tilde$calories'),
                const SizedBox(height: 14),
                MacroStrip(
                  prefix: tilde,
                  entries: [
                    MacroEntry(
                      'Protein',
                      grams(FoodItem.proteinKey, scan.estimatedProtein),
                      FoodResultStyle.protein,
                      energyPerGram: 4,
                    ),
                    MacroEntry(
                      'Carbs',
                      grams(FoodItem.carbohydrateKey, scan.estimatedCarbs),
                      FoodResultStyle.carbs,
                      energyPerGram: 4,
                    ),
                    MacroEntry(
                      'Fat',
                      grams(FoodItem.fatKey, scan.estimatedFats),
                      FoodResultStyle.fat,
                      energyPerGram: 9,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (fromDatabase && !noNutrition && showValues) ...[
            const SizedBox(height: 10),
            MoreNutrients(
              food: food,
              scaled: NutritionCalculator.calculate(
                food,
                scan.estimatedQuantity,
                scan.estimatedUnit,
              ),
            ),
          ],
          if (notices.isNotEmpty) ...[
            const SizedBox(height: 12),
            NoticeBox(
              children: [
                for (var i = 0; i < notices.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  notices[i],
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),

          // One clear primary action; the rest are quiet.
          FilledButton(
            onPressed: _onAddPressed,
            style: ResultButtons.primary(),
            child: Text(
              'Add To ${_selectedMealTitle.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showEditAiFoodEstimateDialog(),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Edit Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: FoodResultStyle.text,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _aiScanResult = null;
                      _lookupCandidates = null;
                      _candidatesReplaceCard = false;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Scan Another Meal'),
                  style: TextButton.styleFrom(
                    foregroundColor: FoodResultStyle.muted,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BARCODE & QR CONTENT WIDGETS
  // ===========================================================================

  Widget _buildBarcodeContent() {
    final isDark = context.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viewfinder Camera Box
          AspectRatio(
            aspectRatio: 1.15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _scannedBarcodeNotFound != null
                        ? Colors.redAccent
                        : AppColors.primaryContainer.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Live Camera Preview with MobileScanner
                    if (!_cameraPermissionDenied)
                      MobileScanner(
                        controller: _mobileScannerController,
                        onDetect: _onBarcodeDetected,
                        errorBuilder: (context, error) {
                          final isPermission =
                              error.errorCode ==
                              MobileScannerErrorCode.permissionDenied;
                          return Container(
                            color: const Color(0xFF14151B),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isPermission
                                      ? Icons.videocam_off_rounded
                                      : Icons.no_photography_rounded,
                                  size: 40,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isPermission
                                      ? 'Camera Permission Denied'
                                      : 'Camera Unavailable',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isPermission
                                      ? 'Please allow camera permission or use manual barcode entry below.'
                                      : 'Camera could not be started. Please use manual barcode entry below.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (isPermission)
                                  ElevatedButton(
                                    onPressed: () {
                                      _checkBarcodePermissions();
                                      _mobileScannerController?.start();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primaryContainer,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Request Permission'),
                                  ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: const Color(0xFF14151B),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam_off_rounded,
                              size: 40,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Camera Permission Denied',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Please allow camera permission or use manual barcode entry below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _checkBarcodePermissions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryContainer,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Request Permission'),
                            ),
                          ],
                        ),
                      ),

                    // 2. Viewfinder Target Frame Overlay
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 220,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.8,
                              ),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Top-Left Corner
                              Positioned(
                                top: -2,
                                left: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                      left: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              // Top-Right Corner
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                      right: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              // Bottom-Left Corner
                              Positioned(
                                bottom: -2,
                                left: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                      left: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              // Bottom-Right Corner
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                      right: BorderSide(
                                        color: AppColors.primaryContainer,
                                        width: 4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. Top-Right Control Buttons (Torch & Camera Switch)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isTorchOn
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                color: _isTorchOn
                                    ? AppColors.primaryContainer
                                    : Colors.white70,
                                size: 20,
                              ),
                              onPressed: _toggleTorch,
                              tooltip: 'Toggle Flashlight',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.flip_camera_ios_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              onPressed: _switchCamera,
                              tooltip: 'Switch Camera',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4. Bottom Scan Indicator Bar
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isBarcodeLoading) ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryContainer,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _detectedBarcode != null
                                      ? 'Looking up barcode (${_detectedBarcode!})...'
                                      : 'Looking up product...',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 14,
                                color: AppColors.primaryContainer,
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'Point camera at Barcode / QR',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Product Not Found Alert Box
          if (_scannedBarcodeNotFound != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.search_off_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Product Not Found',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Barcode: $_scannedBarcodeNotFound',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            CustomFoodModal.show(
                              context,
                              initialFood: FoodItem(
                                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                name: '',
                                barcode: _scannedBarcodeNotFound,
                                calories: 0,
                                isCustom: true,
                                isPackaged: true,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Enter Manually'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            FoodSearchSheet.show(
                              context,
                              mealId: _selectedMealId,
                              mealTitle: _selectedMealTitle,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Search Food'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _resumeScanning,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                        ),
                        tooltip: 'Scan Again',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Unsupported QR Code Alert Box
          if (_unsupportedQrMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'QR Code Unsupported',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _unsupportedQrMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _resumeScanning,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Scan Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          FoodSearchSheet.show(
                            context,
                            mealId: _selectedMealId,
                            mealTitle: _selectedMealTitle,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Search Food'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Barcode Error Message Alert Box
          if (_barcodeErrorMessage != null &&
              _scannedBarcodeNotFound == null &&
              _unsupportedQrMessage == null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _barcodeErrorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: _resumeScanning,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Manual Barcode / QR Entry Input
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161820) : Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OR ENTER BARCODE / QR MANUALLY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeInputController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. 8901234567890',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (val) => _processBarcodeLookup(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _processBarcodeLookup(_barcodeInputController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Lookup',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

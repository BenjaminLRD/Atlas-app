import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/equipment.dart';
import '../models/exercise.dart';
import '../models/machine_scan_result.dart';
import '../services/ai/multimodal/chat_attachment.dart';
import '../services/ai/vision/ai_vision_service.dart';
import '../services/machine/machine_scan_service.dart';

/// Gets a photo: from the camera when `fromCamera` is true, else the gallery.
typedef MachineImageSource = Future<ChatAttachment?> Function(bool fromCamera);

enum _Phase { idle, analyzing, result, error }

/// Photograph a gym machine and get a careful, confirmable explanation of it.
///
/// The identification is the AI's best guess. Guidance (setup, steps, safety)
/// is only shown after the user confirms it, or corrects the machine.
class MachineScannerScreen extends StatefulWidget {
  /// Replace the service or the photo source (tests).
  const MachineScannerScreen({super.key, this.service, this.imageSource});

  final MachineScanService? service;
  final MachineImageSource? imageSource;

  @override
  State<MachineScannerScreen> createState() => _MachineScannerScreenState();
}

class _MachineScannerScreenState extends State<MachineScannerScreen> {
  late final MachineScanService _service;
  late final MachineImageSource _imageSource;

  _Phase _phase = _Phase.idle;
  ChatAttachment? _photo;
  MachineScanResult? _result;
  String? _error;
  String _busyLabel = 'Looking at the photo…';
  bool _confirmed = false;
  bool _chosenByUser = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MachineScanService();
    _imageSource = widget.imageSource ?? _pickWithPlugin;
  }

  static Future<ChatAttachment?> _pickWithPlugin(bool fromCamera) {
    final picker = AIVisionService();
    return fromCamera ? picker.pickFromCamera() : picker.pickFromGallery();
  }

  Future<void> _capture(bool fromCamera) async {
    final photo = await _imageSource(fromCamera);
    if (!mounted) return;
    if (photo == null) {
      setState(() {
        _phase = _Phase.error;
        _error =
            'No photo was taken. Allow camera access in Settings, or choose '
            'a photo from your gallery.';
      });
      return;
    }
    _photo = photo;
    await _identify();
  }

  Future<void> _identify() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _phase = _Phase.analyzing;
      _busyLabel = 'Looking at the photo…';
      _confirmed = false;
      _chosenByUser = false;
    });
    await _run(() => _service.identify(photo));
  }

  Future<void> _explain(String name, String? catalogId) async {
    setState(() {
      _phase = _Phase.analyzing;
      _busyLabel = 'Looking up $name…';
      _confirmed = false;
      _chosenByUser = true;
    });
    await _run(() => _service.explain(name, catalogId: catalogId));
  }

  Future<void> _run(Future<MachineScanResult> Function() job) async {
    try {
      final result = await job();
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.result;
        // A machine the user named themselves needs no second confirmation.
        _confirmed = _chosenByUser && result.hasDetails;
      });
    } on MachineScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _Phase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _phase = _Phase.error;
      });
    }
  }

  void _startOver() {
    setState(() {
      _phase = _Phase.idle;
      _photo = null;
      _result = null;
      _error = null;
      _confirmed = false;
      _chosenByUser = false;
    });
  }

  Future<void> _correct() async {
    final choice = await showModalBottomSheet<({String name, String? id})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appBackground,
      builder: (_) => _CorrectionSheet(catalog: _service.catalog),
    );
    if (choice == null || !mounted) return;
    await _explain(choice.name, choice.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scan a Machine',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_photo != null) _preview(),
            ..._body(),
            const SizedBox(height: 16),
            _disclaimer(),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    switch (_phase) {
      case _Phase.idle:
        return _idle();
      case _Phase.analyzing:
        return [
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Center(child: Text(_busyLabel, style: _secondary())),
        ];
      case _Phase.error:
        return _errorView();
      case _Phase.result:
        return _resultView(_result!);
    }
  }

  // ---------------------------------------------------------------------------
  // Idle and error
  // ---------------------------------------------------------------------------

  List<Widget> _idle() => [
    const SizedBox(height: 24),
    Icon(Icons.qr_code_scanner_rounded, size: 56, color: context.appPrimary),
    const SizedBox(height: 16),
    Text(
      'Not sure what a machine is for?',
      textAlign: TextAlign.center,
      style: AppTheme.headlineMd.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.appTextPrimary,
      ),
    ),
    const SizedBox(height: 8),
    Text(
      'Take a photo of the whole machine. Atlas makes its best guess at what '
      'it is, which muscles it works and how to use it safely. You confirm or '
      'correct the guess before seeing any guidance.',
      textAlign: TextAlign.center,
      style: _secondary(),
    ),
    const SizedBox(height: 24),
    FilledButton.icon(
      key: const Key('machine_take_photo'),
      onPressed: () => _capture(true),
      icon: const Icon(Icons.photo_camera_rounded),
      label: const Text('Take a photo'),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      key: const Key('machine_choose_photo'),
      onPressed: () => _capture(false),
      icon: const Icon(Icons.photo_library_rounded),
      label: const Text('Choose from gallery'),
    ),
    const SizedBox(height: 8),
    TextButton(
      key: const Key('machine_pick_manually'),
      onPressed: _correct,
      child: const Text('I know the machine, pick it myself'),
    ),
  ];

  List<Widget> _errorView() => [
    const SizedBox(height: 24),
    _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong. Please try again.',
              key: const Key('machine_error_text'),
              style: _primary(),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    if (_photo != null)
      FilledButton(
        key: const Key('machine_retry'),
        onPressed: _identify,
        child: const Text('Try again'),
      ),
    TextButton(
      key: const Key('machine_start_over'),
      onPressed: _startOver,
      child: const Text('Start over'),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Result
  // ---------------------------------------------------------------------------

  List<Widget> _resultView(MachineScanResult r) {
    switch (r.status) {
      case MachineScanStatus.notEquipment:
        return [
          const SizedBox(height: 16),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This doesn't look like gym equipment",
                  key: const Key('machine_not_equipment'),
                  style: _title(),
                ),
                const SizedBox(height: 6),
                Text(
                  r.message ?? 'Try a photo of the whole machine.',
                  style: _secondary(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('machine_try_another'),
            onPressed: _startOver,
            child: const Text('Try another photo'),
          ),
        ];
      case MachineScanStatus.unidentified:
        return [
          const SizedBox(height: 16),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Atlas couldn't identify this",
                  key: const Key('machine_unidentified'),
                  style: _title(),
                ),
                const SizedBox(height: 6),
                Text(r.message ?? '', style: _secondary()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('machine_try_another'),
            onPressed: _startOver,
            child: const Text('Try another photo'),
          ),
          TextButton(
            key: const Key('machine_correct'),
            onPressed: _correct,
            child: const Text('Pick the machine myself'),
          ),
        ];
      case MachineScanStatus.identified:
      case MachineScanStatus.uncertain:
        return _identifiedView(r);
    }
  }

  List<Widget> _identifiedView(MachineScanResult r) {
    final exercises = r.catalogId == null
        ? const <Exercise>[]
        : MachineScanService.exercisesFor(r.catalogId!);
    return [
      const SizedBox(height: 16),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chosenByUser
                  ? 'You chose'
                  : (r.status == MachineScanStatus.uncertain
                        ? 'Atlas is not sure, but this might be'
                        : 'Atlas thinks this is'),
              style: _secondary(),
            ),
            const SizedBox(height: 4),
            Text(
              r.machineName ?? '',
              key: const Key('machine_name'),
              style: _title(),
            ),
            const SizedBox(height: 8),
            Text(
              _chosenByUser
                  ? 'Guidance below is general; check it against the machine.'
                  : 'Confidence: ${r.confidencePercent}%'
                        '${r.isLowConfidence ? ' (low)' : ''}',
              key: const Key('machine_confidence'),
              style: _secondary(),
            ),
            const SizedBox(height: 4),
            Text(
              r.hasCatalogMatch
                  ? 'Matches Atlas equipment: ${r.catalogName}'
                  : "Not in Atlas's equipment list",
              key: const Key('machine_catalog_match'),
              style: _secondary(),
            ),
            if (r.uncertaintyNote != null) ...[
              const SizedBox(height: 8),
              Text(
                r.uncertaintyNote!,
                key: const Key('machine_uncertainty'),
                style: _primary().copyWith(color: Colors.orange.shade700),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!_confirmed) ..._confirmPrompt(r) else ..._details(r, exercises),
    ];
  }

  List<Widget> _confirmPrompt(MachineScanResult r) => [
    Text(
      r.status == MachineScanStatus.uncertain
          ? 'Check the label on the machine. Is this what you are looking at?'
          : 'Is this the machine you are looking at?',
      key: const Key('machine_confirm_question'),
      style: _title(size: 15),
    ),
    const SizedBox(height: 8),
    FilledButton(
      key: const Key('machine_confirm_yes'),
      onPressed: () => setState(() => _confirmed = true),
      child: const Text("Yes, that's it"),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      key: const Key('machine_correct'),
      onPressed: _correct,
      child: const Text('No, let me correct it'),
    ),
    TextButton(
      key: const Key('machine_retake'),
      onPressed: _startOver,
      child: const Text('Retake photo'),
    ),
  ];

  List<Widget> _details(MachineScanResult r, List<Exercise> exercises) => [
    Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
        const SizedBox(width: 6),
        Text(
          _chosenByUser ? 'Machine chosen by you' : 'Confirmed by you',
          key: const Key('machine_confirmed'),
          style: _secondary(),
        ),
      ],
    ),
    const SizedBox(height: 8),
    _section('Muscles worked', [
      if (r.primaryMuscles.isNotEmpty)
        'Primary: ${r.primaryMuscles.join(', ')}',
      if (r.secondaryMuscles.isNotEmpty)
        'Secondary: ${r.secondaryMuscles.join(', ')}',
    ], bullets: false),
    _section('Setup', r.setupSteps, numbered: true),
    _section('How to use it', r.usageSteps, numbered: true),
    _section('Safety', r.safetyCues),
    _section('Common mistakes', r.commonMistakes),
    if (exercises.isNotEmpty)
      _section(
        'Exercises in Atlas for this machine',
        exercises.take(8).map((e) => e.name).toList(),
      ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          key: const Key('machine_correct'),
          onPressed: _correct,
          child: const Text('Wrong machine?'),
        ),
        TextButton(
          key: const Key('machine_scan_another'),
          onPressed: _startOver,
          child: const Text('Scan another'),
        ),
      ],
    ),
  ];

  // ---------------------------------------------------------------------------
  // Pieces
  // ---------------------------------------------------------------------------

  Widget _preview() {
    final data = _photo?.base64Data;
    if (data == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 180,
          child: Image.memory(
            base64Decode(data),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: context.appCardBorder,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    String title,
    List<String> items, {
    bool numbered = false,
    bool bullets = true,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _title(size: 15)),
            const SizedBox(height: 6),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  numbered
                      ? '${i + 1}. ${items[i]}'
                      : (bullets ? '• ${items[i]}' : items[i]),
                  style: _primary(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _disclaimer() => Text(
    'AI identification can be wrong. Check the machine’s own label and '
    'instructions, start light, and ask gym staff or a trainer if you are not '
    'sure. This is general guidance, not medical advice. Stop if you feel pain.',
    key: const Key('machine_disclaimer'),
    style: _secondary().copyWith(fontSize: 11),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.appCardBorder),
    ),
    child: child,
  );

  TextStyle _title({double size = 18}) => AppTheme.headlineMd.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: context.appTextPrimary,
  );

  TextStyle _primary() =>
      AppTheme.bodySm.copyWith(fontSize: 13, color: context.appTextPrimary);

  TextStyle _secondary() =>
      AppTheme.bodySm.copyWith(fontSize: 12, color: context.appTextSecondary);
}

/// Lets the user pick the right machine from Atlas's catalog or type a name.
class _CorrectionSheet extends StatefulWidget {
  const _CorrectionSheet({required this.catalog});

  final List<Equipment> catalog;

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitTyped() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, id: null));
  }

  @override
  Widget build(BuildContext context) {
    final machines = widget.catalog
        .where((e) => e.category == EquipmentCategory.machine)
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Which machine is it?',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in machines)
                    ListTile(
                      key: Key('machine_option_${e.id}'),
                      dense: true,
                      title: Text(e.name),
                      onTap: () =>
                          Navigator.of(context).pop((name: e.name, id: e.id)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('machine_name_field'),
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitTyped(),
              decoration: const InputDecoration(
                labelText: 'Or type the machine name',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('machine_name_submit'),
              onPressed: _submitTyped,
              child: const Text('Use this name'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

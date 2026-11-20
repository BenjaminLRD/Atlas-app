import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../app_theme.dart';
import '../data/profile_provider.dart';
import '../models/activity_record.dart';
import '../models/cardio_activity_data.dart';
import '../models/cardio_route.dart';
import '../models/waypoint_plan.dart';
import '../providers/fitness_provider.dart';
import '../data/local_storage.dart';
import '../services/cardio/cardio_journal.dart';
import '../services/cardio/cardio_tracker.dart';
import '../services/cardio/route_privacy.dart';
import '../widgets/cardio/geo_map_view.dart';
import '../widgets/cardio/map_glass.dart';
import '../widgets/cardio/stops_panel.dart';
import '../widgets/cardio/route_privacy_picker.dart';
import '../services/cardio/geolocator_location_source.dart';
import '../services/community/cardio_post_publisher.dart';
import '../widgets/cardio/cardio_stats.dart';

/// Records an outdoor run or ride with the device GPS: live distance, time,
/// pace or speed, the route drawn as it is recorded, and a summary to save and
/// share when finished.
class GpsCardioScreen extends StatefulWidget {
  const GpsCardioScreen({
    super.key,
    this.initialKind = CardioKind.running,
    this.source,
    this.weightKg,
    this.clock,
    this.persist,
    this.journal,
    this.explainBackground = true,
  });

  final CardioKind initialKind;

  /// Position source. Tests pass a fake; the app uses the device GPS.
  final LocationSource? source;

  /// Body weight for the calorie estimate. Defaults to the profile weight.
  final double? weightKg;
  final DateTime Function()? clock;

  /// Saves the finished session. Tests pass a recorder; the app saves through
  /// [FitnessProvider.recordCardioCompletion].
  final Future<void> Function(CardioSession session, ActivityRecord activity)?
  persist;

  /// Keeps a recovery copy while recording. Defaults to the device storage.
  final CardioJournal? journal;

  /// Shows the one-time note about recording with the screen locked.
  final bool explainBackground;

  @override
  State<GpsCardioScreen> createState() => _GpsCardioScreenState();
}

class _GpsCardioScreenState extends State<GpsCardioScreen> {
  late CardioKind _kind = widget.initialKind;
  late CardioTracker _tracker = _newTracker(_kind);
  Timer? _ticker;

  bool _starting = false;
  bool _saving = false;
  bool _saved = false;
  CardioResult? _result;
  CardioActivityData? _savedData;

  final TextEditingController _caption = TextEditingController();
  RoutePrivacyMode _privacy = RoutePrivacyMode.fromName(
    LocalStorage.getCardioPrivacyMode(),
  );
  bool _sharing = false;
  bool _shared = false;

  /// Stops the athlete planned on the map. Not part of the recorded route.
  static const String _stopsKey = 'cardio_planned_stops_v1';
  WaypointPlan _plan = WaypointPlan.decode(LocalStorage.getString(_stopsKey));
  bool _editingStops = false;

  LocationSource get _source =>
      widget.source ?? const GeolocatorLocationSource();

  CardioJournal get _journal => widget.journal ?? CardioJournal();

  CardioTracker _newTracker(CardioKind kind) => CardioTracker(
    kind: kind,
    journal: _journal,
    source: _source,
    weightKg: widget.weightKg ?? parseProfileWeightKg(ProfileProvider().weight),
    clock: widget.clock,
  );

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTracker);
  }

  void _onTracker() {
    if (mounted) setState(() {});
  }

  void _saveStops() =>
      LocalStorage.setString(_stopsKey, _plan.isEmpty ? '' : _plan.encode());

  void _clearStops() {
    _plan = WaypointPlan();
    _editingStops = false;
    _saveStops();
  }

  void _toast(String message) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Whether the map can be edited now: there has to be a map to tap, which
  /// needs a GPS position or stops already placed.
  bool get _canEditStops => _tracker.currentPosition != null || !_plan.isEmpty;

  void _toggleStops() {
    if (_editingStops) {
      setState(() => _editingStops = false);
      return;
    }
    if (!_canEditStops) {
      _toast(
        _tracker.hasStarted
            ? 'Waiting for your GPS position. Stops can be placed as soon as '
                  'the map has found you.'
            : 'Start tracking first. Stops are placed on the live map.',
      );
      return;
    }
    setState(() => _editingStops = true);
  }

  void _addStop(double lat, double lng) {
    final result = _plan.add(lat, lng);
    if (!result.ok) {
      _toast(result.problem!.message);
      return;
    }
    setState(() {});
    _saveStops();
  }

  void _addStopHere() {
    final c = _tracker.currentPosition;
    if (c == null) {
      _toast('No GPS position yet.');
      return;
    }
    _addStop(c.lat, c.lng);
  }

  String? get _addHereHint {
    if (_tracker.currentPosition == null) {
      return 'Waiting for GPS. You can still tap the map to place a stop.';
    }
    if (_tracker.gps == GpsStatus.weak) {
      return 'GPS signal is weak, so your position may be off. Tapping the '
          'map is more reliable.';
    }
    return null;
  }

  Widget _stopsSummary(BuildContext context) {
    final c = _tracker.currentPosition;
    final toFirst = c == null ? null : _plan.distanceToFirstFrom(c.lat, c.lng);
    return Container(
      key: const Key('stops_summary'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appOutlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_circle_rounded, color: context.appPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                '${_plan.length} planned stop${_plan.length == 1 ? '' : 's'}',
                if (_plan.length >= 2)
                  '${WaypointPlan.formatDistance(_plan.totalM)} between stops',
                if (toFirst != null)
                  'next: ${WaypointPlan.formatDistance(toFirst)} away',
              ].join(' · '),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
          TextButton(
            key: const Key('stops_edit'),
            onPressed: _toggleStops,
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tracker.removeListener(_onTracker);
    _tracker.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _selectKind(CardioKind kind) {
    if (_tracker.hasStarted || _result != null || kind == _kind) return;
    _tracker.removeListener(_onTracker);
    _tracker.dispose();
    setState(() {
      _kind = kind;
      _tracker = _newTracker(kind)..addListener(_onTracker);
    });
  }

  /// A short, honest note before the first recording: what is used, that it
  /// keeps going with the screen locked, and the notification that shows.
  Future<bool> _explainBackground() async {
    if (!widget.explainBackground ||
        LocalStorage.getCardioBackgroundExplained()) {
      return true;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recording with the screen locked'),
        content: const Text(
          'Atlas uses your location while you record, and keeps recording if '
          'you lock the screen or open another app. While it does, Android '
          'shows a notification, and iPhone shows a blue location indicator. '
          'Location is used only for this activity and stops when you finish '
          'or discard it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            key: const Key('background_continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok == true) await LocalStorage.setCardioBackgroundExplained();
    return ok == true;
  }

  Future<void> _start() async {
    if (_starting) return;
    if (!await _explainBackground() || !mounted) return;
    setState(() => _starting = true);
    final ok = await _tracker.start();
    if (!mounted) return;
    setState(() => _starting = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tracker.tick(),
      );
    }
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    _tracker.isRunning ? _tracker.pause() : _tracker.resume();
  }

  Future<bool> _confirm(
    String title,
    String body,
    String yes, {
    String no = 'Keep going',
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(no),
          ),
          TextButton(
            key: const Key('confirm_yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _discard() async {
    final yes = await _confirm(
      'Discard this ${_kind.noun.toLowerCase()}?',
      'Nothing will be saved and it will not count as an activity.',
      'Discard',
    );
    if (!yes || !mounted) return;
    _ticker?.cancel();
    _tracker.discard();
    _clearStops();
    Navigator.of(context).pop(false);
  }

  Future<void> _finish() async {
    if (_tracker.distanceM < 10 || _tracker.elapsed.inSeconds < 10) {
      final discard = await _confirm(
        'Not enough to save',
        'Almost no distance was recorded, so this would not be a real '
            '${_kind.noun.toLowerCase()}. Discard it, or keep recording?',
        'Discard',
      );
      if (discard && mounted) {
        _ticker?.cancel();
        _tracker.discard();
        _clearStops();
        Navigator.of(context).pop(false);
      }
      return;
    }
    final result = _tracker.finish();
    _ticker?.cancel();
    if (result == null) return;
    setState(() => _result = result);
    await _save(result);
  }

  Future<void> _save(CardioResult r) async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    final (session, activity) = CardioSessionBuilder.build(r.toDraft());
    try {
      final persist =
          widget.persist ?? FitnessProvider.instance.recordCardioCompletion;
      await persist(session, activity);
      // Saved: the recovery copy is no longer needed.
      await _journal.clear();
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
        _savedData = CardioActivityData.fromSession(session);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your activity. Tap Save to try again.'),
        ),
      );
    }
  }

  Future<void> _share() async {
    final data = _savedData;
    if (data == null || _sharing || _shared) return;
    setState(() => _sharing = true);
    try {
      await CardioPostPublisher.publish(
        data,
        caption: _caption.text,
        privacy: _privacy,
      );
      if (!mounted) return;
      setState(() {
        _shared = true;
        _sharing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your activity could not be shared. Try again.'),
        ),
      );
    }
  }

  Future<void> _onBack() async {
    if (_tracker.hasStarted && _result == null) {
      final yes = await _confirm(
        'Leave this ${_kind.noun.toLowerCase()}?',
        'Leaving now discards what has been recorded. Use Finish to save it.',
        'Discard and leave',
        no: 'Stay',
      );
      if (!yes || !mounted) return;
      _ticker?.cancel();
      _tracker.discard();
      _clearStops();
    }
    if (mounted) Navigator.of(context).pop(_saved);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: SafeArea(
          child: _result != null ? _buildSummary(context) : _buildLive(context),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- live

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('cardio_back'),
            onPressed: _onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: context.appTextPrimary,
          ),
          const SizedBox(width: 4),
          Expanded(child: _kindSelector(context)),
        ],
      ),
    );
  }

  Widget _kindSelector(BuildContext context) {
    final locked = _tracker.hasStarted || _result != null;
    Widget chip(CardioKind k) {
      final selected = k == _kind;
      return Expanded(
        child: GestureDetector(
          key: Key('kind_${k.key}'),
          onTap: locked ? null : () => _selectKind(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cardioIcon(k),
                  size: 18,
                  color: selected
                      ? AppColors.primary
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    k.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.primary
                          : context.appTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appOutlineVariant),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [chip(CardioKind.running), chip(CardioKind.cycling)],
      ),
    );
  }

  ({String text, bool warn, bool settings, bool locationSettings})?
  _gpsMessage() {
    switch (_tracker.gps) {
      case GpsStatus.permissionDenied:
        return (
          text:
              'Atlas needs location permission to record your route. '
              'Allow it and tap Start again.',
          warn: true,
          settings: false,
          locationSettings: false,
        );
      case GpsStatus.permissionDeniedForever:
        return (
          text:
              'Location permission is turned off for Atlas. Enable it in '
              'Settings to record a run or ride.',
          warn: true,
          settings: true,
          locationSettings: false,
        );
      case GpsStatus.serviceDisabled:
        return (
          text:
              'Location is switched off on this phone. Turn it on to record '
              'your route.',
          warn: true,
          settings: false,
          locationSettings: true,
        );
      case GpsStatus.busy:
        return (
          text: 'Another run or ride is already being recorded.',
          warn: true,
          settings: false,
          locationSettings: false,
        );
      case GpsStatus.searching:
        return (
          text: 'Searching for GPS… distance starts once a position arrives.',
          warn: false,
          settings: false,
          locationSettings: false,
        );
      case GpsStatus.weak:
        return (
          text: 'GPS signal is weak. Distance is not counted until it returns.',
          warn: true,
          settings: false,
          locationSettings: false,
        );
      case GpsStatus.good:
      case GpsStatus.idle:
        return null;
    }
  }

  Widget _statusBanner(BuildContext context) {
    final m = _gpsMessage();
    if (m == null) return const SizedBox.shrink();
    final color = m.warn ? const Color(0xFFF59E0B) : context.appTextSecondary;
    return Container(
      key: const Key('gps_status'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            m.warn ? Icons.gps_off_rounded : Icons.gps_not_fixed_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.text,
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: context.appTextPrimary,
              ),
            ),
          ),
          if (m.settings)
            TextButton(
              key: const Key('open_app_settings'),
              onPressed: GeolocatorLocationSource.openAppSettings,
              child: const Text('Settings'),
            ),
          if (m.locationSettings)
            TextButton(
              key: const Key('open_location_settings'),
              onPressed: GeolocatorLocationSource.openLocationSettings,
              child: const Text('Turn on'),
            ),
        ],
      ),
    );
  }

  Widget _buildLive(BuildContext context) {
    final t = _tracker;
    final started = t.hasStarted;
    final isRun = _kind.isRunning;
    final currentRate = isRun
        ? CardioFormat.pace(t.currentPaceSecPerKm)
        : CardioFormat.speed(t.currentSpeedKmh);
    final avgRate = isRun
        ? CardioFormat.pace(t.avgPaceSecPerKm)
        : CardioFormat.speed(t.avgSpeedKmh);
    final unit = isRun ? '/km' : 'km/h';
    final cal = t.caloriesEstimate;

    return Column(
      children: [
        _topBar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _statusBanner(context),
                GeoMapView(
                  key: const Key('live_map'),
                  route: t.route,
                  current: started ? t.currentPosition : null,
                  follow: true,
                  height: 240,
                  interactive: started || !_plan.isEmpty,
                  waypoints: _plan.stops,
                  onTap: _editingStops
                      ? (LatLng p) => _addStop(p.latitude, p.longitude)
                      : null,
                  editingHint: 'Tap the map to add a stop',
                  topLeft: MapGlassButton(
                    key: const Key('stops_button'),
                    icon: _editingStops
                        ? Icons.check_rounded
                        : Icons.add_location_alt_rounded,
                    label: _editingStops
                        ? 'Done'
                        : (_plan.isEmpty
                              ? 'Add stops'
                              : 'Stops (${_plan.length})'),
                    active: _editingStops,
                    tooltip: _editingStops
                        ? 'Finish editing stops'
                        : 'Plan stops on the map',
                    onPressed: _toggleStops,
                  ),
                  emptyMessage: started
                      ? 'Waiting for your first GPS position'
                      : 'Your route will appear here once you start',
                ),
                if (_editingStops)
                  StopsPanel(
                    plan: _plan,
                    fromLat: t.currentPosition?.lat,
                    fromLng: t.currentPosition?.lng,
                    onAddHere: t.currentPosition == null ? null : _addStopHere,
                    addHereHint: _addHereHint,
                    onRemove: (id) {
                      setState(() => _plan.remove(id));
                      _saveStops();
                    },
                    onReorder: (a, b) {
                      setState(() => _plan.reorder(a, b));
                      _saveStops();
                    },
                    onClear: () {
                      setState(() => _plan.clear());
                      _saveStops();
                    },
                    onDone: () => setState(() => _editingStops = false),
                  )
                else if (!_plan.isEmpty)
                  _stopsSummary(context),
                const SizedBox(height: 18),
                CardioDistanceHero(distanceKm: t.distanceKm),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.appOutlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CardioMetricTile(
                              key: const Key('live_duration'),
                              icon: Icons.timer_outlined,
                              value: CardioFormat.duration(t.elapsed.inSeconds),
                              label: 'Duration',
                            ),
                          ),
                          Expanded(
                            child: CardioMetricTile(
                              key: const Key('live_current'),
                              icon: isRun
                                  ? Icons.speed_rounded
                                  : Icons.bolt_rounded,
                              value: currentRate,
                              unit: unit,
                              label: isRun ? 'Current pace' : 'Current speed',
                              unavailable: currentRate == '–',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CardioMetricTile(
                              key: const Key('live_avg'),
                              icon: Icons.av_timer_rounded,
                              value: avgRate,
                              unit: unit,
                              label: isRun ? 'Avg pace' : 'Avg speed',
                              unavailable: avgRate == '–',
                            ),
                          ),
                          Expanded(
                            child: CardioMetricTile(
                              key: const Key('live_calories'),
                              icon: Icons.local_fire_department_rounded,
                              accent: const Color(0xFFF59E0B),
                              value: CardioFormat.calories(cal),
                              unit: 'kcal',
                              label: cal == null
                                  ? 'Calories (needs weight)'
                                  : 'Calories (est.)',
                              unavailable: cal == null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (t.weightKg == null && started)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Add your weight in your profile to see a calorie estimate.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Pinned, so Start, Pause and Finish are always reachable.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _controls(context),
        ),
      ],
    );
  }

  Widget _circleButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    double size = 56,
    Color? fill,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: fill ?? context.appSurfaceElevated,
          shape: CircleBorder(
            side: BorderSide(color: context.appOutlineVariant),
          ),
          child: InkWell(
            key: key,
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.46,
                color: iconColor ?? context.appTextPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTheme.bodySm.copyWith(
            fontSize: 11,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final t = _tracker;
    if (!t.hasStarted) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          key: const Key('cardio_start'),
          onPressed: _starting ? null : _start,
          icon: Icon(cardioIcon(_kind)),
          label: Text(
            _starting ? 'Starting…' : 'Start ${_kind.noun.toLowerCase()}',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _circleButton(
          key: const Key('cardio_discard'),
          icon: Icons.delete_outline_rounded,
          label: 'Discard',
          onTap: _discard,
        ),
        _circleButton(
          key: const Key('cardio_pause_resume'),
          icon: t.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: t.isRunning ? 'Pause' : 'Resume',
          onTap: _togglePause,
          size: 76,
          fill: const Color(0xFF111418),
          iconColor: Colors.white,
        ),
        _circleButton(
          key: const Key('cardio_finish'),
          icon: Icons.stop_rounded,
          label: 'Finish',
          onTap: _finish,
          fill: AppColors.primary,
          iconColor: Colors.black,
        ),
      ],
    );
  }

  // ------------------------------------------------------------- summary

  Widget _buildSummary(BuildContext context) {
    final r = _result!;
    final data =
        _savedData ??
        CardioActivityData(
          kind: r.kind,
          title: r.kind.isRunning ? 'Outdoor Run' : 'Outdoor Ride',
          date: r.startedAt,
          distanceKm: r.distanceKm,
          durationSeconds: r.activeSeconds,
          avgSpeedKmh: r.avgSpeedKmh,
          avgPaceSecPerKm: r.avgPaceSecPerKm,
          calories: r.caloriesEstimate,
          route: r.route,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(cardioIcon(r.kind), color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _saved
                      ? '${r.kind.noun} saved'
                      : (_saving ? 'Saving…' : '${r.kind.noun} finished'),
                  key: const Key('summary_title'),
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GeoMapView(
            key: const Key('summary_map'),
            route: r.route,
            height: 260,
            interactive: true,
            emptyMessage: 'No GPS route was recorded',
          ),
          const SizedBox(height: 16),
          CardioDistanceHero(distanceKm: r.distanceKm),
          const SizedBox(height: 14),
          CardioStatsPanel(data: data),
          if (r.pausedSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Paused for ${CardioFormat.duration(r.pausedSeconds)} '
                '(not counted in the duration).',
                textAlign: TextAlign.center,
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  color: context.appTextSecondary,
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (!_saved)
            ElevatedButton(
              key: const Key('summary_save'),
              onPressed: _saving ? null : () => _save(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_saving ? 'Saving…' : 'Save activity'),
            )
          else ...[
            if (CardioPostPublisher.canShare) ...[
              TextField(
                key: const Key('share_caption'),
                controller: _caption,
                enabled: !_shared,
                maxLength: 280,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  hintText: 'How did it feel?',
                ),
              ),
              const SizedBox(height: 8),
              RoutePrivacyPicker(
                data: data,
                mode: _privacy,
                enabled: !_shared,
                onChanged: (m) {
                  setState(() => _privacy = m);
                  LocalStorage.saveCardioPrivacyMode(m.name);
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                key: const Key('summary_share'),
                onPressed: _shared || _sharing ? null : _share,
                icon: Icon(
                  _shared ? Icons.check_rounded : Icons.public_rounded,
                ),
                label: Text(
                  _shared
                      ? 'Shared to Community'
                      : (_sharing ? 'Sharing…' : 'Share to Community'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ] else
              Text(
                'Sharing is turned off in Showcase Mode. This activity stays '
                'in the demo and is not saved to a real account.',
                key: const Key('share_showcase_note'),
                textAlign: TextAlign.center,
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('summary_done'),
              onPressed: () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}

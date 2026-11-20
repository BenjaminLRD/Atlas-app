import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/atlas_challenge.dart';
import '../../services/challenges/challenge_progress.dart';
import '../../services/community/sample_world.dart';

/// Number with thousands separators.
String challengeNumber(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String challengeDate(DateTime d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${m[d.month - 1]}';
}

/// "16 Nov to 22 Nov" for a started challenge (the end date is exclusive).
String challengeRange(AtlasChallenge c) {
  final s = c.startDate;
  final e = c.endDate;
  if (s == null || e == null) {
    return '${c.durationDays} days, starts when you accept';
  }
  return '${challengeDate(s)} to ${challengeDate(e.subtract(const Duration(days: 1)))}';
}

String challengeStatusLabel(AtlasChallengeStatus s) => switch (s) {
  AtlasChallengeStatus.invited => 'INVITED',
  AtlasChallengeStatus.active => 'ACTIVE',
  AtlasChallengeStatus.completed => 'COMPLETED',
  AtlasChallengeStatus.declined => 'DECLINED',
  AtlasChallengeStatus.expired => 'EXPIRED',
};

Color challengeStatusColor(BuildContext context, AtlasChallengeStatus s) =>
    switch (s) {
      AtlasChallengeStatus.active ||
      AtlasChallengeStatus.completed => AppColors.primary,
      AtlasChallengeStatus.invited => const Color(0xFFF59E0B),
      _ => context.appTextSecondary,
    };

class ChallengeStatusChip extends StatelessWidget {
  final AtlasChallengeStatus status;
  const ChallengeStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = challengeStatusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        challengeStatusLabel(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class SamplePill extends StatelessWidget {
  const SamplePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: context.appTextSecondary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'SAMPLE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: context.appTextSecondary,
        ),
      ),
    );
  }
}

/// One progress line: label, bar and a value (or "Unavailable").
class ChallengeProgressRow extends StatelessWidget {
  final String label;
  final Widget? tag;
  final double? value;
  final double target;
  final String unit;
  final Color? barColor;
  final Key? valueKey;

  const ChallengeProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    this.tag,
    this.barColor,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final fraction = v == null || target <= 0
        ? 0.0
        : (v / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            if (tag != null) ...[const SizedBox(width: 6), tag!],
            const Spacer(),
            Text(
              v == null
                  ? 'Unavailable'
                  : '${challengeNumber(v)} / ${challengeNumber(target)} $unit',
              key: valueKey,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: v == null
                    ? context.appTextSecondary
                    : context.appTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: context.appSurfaceVariant,
            valueColor: AlwaysStoppedAnimation(barColor ?? AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// A challenge in a list: title, status, dates and progress.
class AtlasChallengeCard extends StatelessWidget {
  final AtlasChallenge challenge;
  final ChallengeInputs inputs;
  final VoidCallback? onTap;
  final Widget? actions;

  const AtlasChallengeCard({
    super.key,
    required this.challenge,
    required this.inputs,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final sample = c.opponentKey == null
        ? null
        : SampleWorld.byKey(c.opponentKey!);
    final started = c.startDate != null;
    final you = ChallengeProgressCalculator.forYou(c, inputs);
    final opp = sample == null || !started
        ? null
        : ChallengeProgressCalculator.scriptedOpponent(c, sample, inputs.now);
    final shownYou = c.status == AtlasChallengeStatus.completed
        ? c.target
        : you.value;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChallengeStatusChip(c.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.objective}  ·  ${challengeRange(c)}',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
              if (sample != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.incoming
                            ? 'From ${sample.name}'
                            : 'Against ${sample.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const SamplePill(),
                  ],
                ),
              ],
              if (started) ...[
                const SizedBox(height: 10),
                ChallengeProgressRow(
                  label: 'You',
                  value: shownYou,
                  target: c.target,
                  unit: c.metric.unit,
                  valueKey: Key('progress_you_${c.id}'),
                ),
                if (!you.available &&
                    c.status == AtlasChallengeStatus.active) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Steps unavailable: no step readings yet.',
                    key: Key('progress_unavailable_${c.id}'),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
                if (opp != null) ...[
                  const SizedBox(height: 8),
                  ChallengeProgressRow(
                    label: sample!.name.split(' ').first,
                    tag: const SamplePill(),
                    value: opp,
                    target: c.target,
                    unit: c.metric.unit,
                    barColor: context.appTextSecondary,
                    valueKey: Key('progress_opp_${c.id}'),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Starts when you accept.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
              if (c.endNote != null && !c.isOpen) ...[
                const SizedBox(height: 8),
                Text(
                  c.endNote!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
              if (actions != null) ...[const SizedBox(height: 10), actions!],
            ],
          ),
        ),
      ),
    );
  }
}

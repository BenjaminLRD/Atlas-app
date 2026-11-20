import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/ai/ml/engagement_prediction_engine.dart';
import '../services/ai/ml/feature_engineering_service.dart';
import '../services/ai/ml/workout_recommendation_model.dart';
import '../services/analytics/user_behavior_tracker.dart';
import '../widgets/common/app_card.dart';

/// Interactive Personalization & Machine Learning Insights Dashboard.
class PersonalizationInsightsScreen extends StatefulWidget {
  const PersonalizationInsightsScreen({super.key});

  @override
  State<PersonalizationInsightsScreen> createState() =>
      _PersonalizationInsightsScreenState();
}

class _PersonalizationInsightsScreenState
    extends State<PersonalizationInsightsScreen> {
  late UserFeatureVector _featureVector;
  late List<DiscoveredBehaviorInsight> _insights;
  late PersonalizedWorkoutRecommendation _recommendation;
  late RetentionPredictionResult _retentionResult;

  @override
  void initState() {
    super.initState();
    _featureVector = FeatureEngineeringService.instance.extractFeatureVector(
      userId: 'usr_local',
    );
    _insights = UserBehaviorTracker.instance.computeBehavioralDiscoveries(
      'usr_local',
    );
    _recommendation = WorkoutRecommendationModel.instance
        .generateRecommendation(
          featureVector: _featureVector,
          goal: 'Hypertrophy',
          fitnessLevel: 'Intermediate',
          recoveryScore: 85.0,
        );
    _retentionResult = EngagementPredictionEngine.instance.predictRetentionRisk(
      daysSinceLastWorkout: 1,
      missedGoalsLast14Days: 0,
      recentEngagementScore: _featureVector.engagementScore,
      nutritionLoggingAdherence: _featureVector.nutritionAdherence,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'AI Predictive Insights',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Score Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Intelligence Engine',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Engagement Score: ${_featureVector.engagementScore.toStringAsFixed(0)}/100 • ${_retentionResult.churnRisk.indicator} ${_retentionResult.churnRisk.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _featureVector.trainingConsistency,
                            minHeight: 6,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_featureVector.trainingConsistency * 100).toStringAsFixed(0)}% Training Consistency',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // AI Behavioral Discoveries
            const Text(
              'BEHAVIORAL DISCOVERIES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _insights.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _insights[index];
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(item.confidenceScore * 100).round()}% CONFIDENCE',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ML Workout Recommendation Snapshot
            const Text(
              'NEXT PREDICTIVE SESSION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _recommendation.split,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RPE ${_recommendation.recommendedIntensityRpe}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recommendation.rationale,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _recommendation.exercises
                        .map(
                          (ex) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.appSurfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ex,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Retention & Continuity Strategy
            const Text(
              'HABIT CONTINUITY STRATEGY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _retentionResult.retentionInterventions
                    .map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

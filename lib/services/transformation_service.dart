import '../models/transformation_post.dart';

/// Manages physical transformations, before/after milestone logs, and privacy filtering.
class TransformationService {
  static TransformationService? _instance;
  static TransformationService get instance =>
      _instance ??= TransformationService();

  final List<TransformationPost> _posts = [];

  TransformationService() {
    _initDefaults();
  }

  void _initDefaults() {
    if (_posts.isEmpty) {
      _posts.addAll([
        TransformationPost(
          id: 'tf_1',
          userId: 'usr_benjamin',
          userName: 'Benjamin',
          beforeWeight: 65.0,
          afterWeight: 72.0,
          timeSpanLabel: 'January → March (12 weeks)',
          strengthGains: {'Bench Press': 20.0, 'Squat': 35.0},
          bodyMeasurements: {'Chest': 4.5, 'Arm': 2.0},
          caption:
              'Consistent progressive overload and 160g protein daily. Sticking to the process!',
          privacy: TransformationPrivacy.public,
          likesCount: 24,
          commentsCount: 5,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        TransformationPost(
          id: 'tf_2',
          userId: 'usr_rahul',
          userName: 'Rahul',
          beforeWeight: 88.0,
          afterWeight: 79.0,
          timeSpanLabel: '16-Week Cut',
          strengthGains: {'Deadlift': 15.0},
          bodyMeasurements: {'Waist': -6.0},
          caption: 'Down 9kg while maintaining all my compound lift strength!',
          privacy: TransformationPrivacy.followersOnly,
          likesCount: 38,
          commentsCount: 8,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ]);
    }
  }

  /// Retrieves transformations adhering to privacy controls.
  List<TransformationPost> getTransformations({
    String? viewerUserId,
    bool isFollowing = false,
    String? targetUserId,
  }) {
    return _posts.where((post) {
      // Filter by target user if specified
      if (targetUserId != null && post.userId != targetUserId) {
        return false;
      }

      // Check author visibility
      if (viewerUserId != null && post.userId == viewerUserId) {
        return true;
      }

      // Privacy checks
      switch (post.privacy) {
        case TransformationPrivacy.public:
          return true;
        case TransformationPrivacy.followersOnly:
          return isFollowing;
        case TransformationPrivacy.private:
          return viewerUserId == post.userId;
      }
    }).toList();
  }

  /// Adds a new transformation milestone
  Future<void> addTransformation(TransformationPost post) async {
    _posts.insert(0, post);
  }

  /// Deletes a transformation
  Future<void> deleteTransformation(String id) async {
    _posts.removeWhere((p) => p.id == id);
  }
}

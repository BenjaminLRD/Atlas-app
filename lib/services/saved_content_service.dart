import '../data/local_storage.dart';
import '../models/activity_post.dart';

/// Service managing saved routines, meal prep recipes, and bookmarked community posts.
class SavedContentService {
  static SavedContentService? _instance;

  SavedContentService();

  static SavedContentService get instance {
    _instance ??= SavedContentService();
    return _instance!;
  }

  static void resetInstance() {
    _instance = null;
  }

  /// Get all saved posts.
  List<ActivityPost> getSavedPosts() {
    return LocalStorage.getSavedPosts();
  }

  /// Check whether post with [postId] is saved.
  bool isSaved(String postId) {
    final list = LocalStorage.getSavedPosts();
    return list.any((p) => p.id == postId);
  }

  /// Save a post / program / meal recipe.
  Future<void> savePost(ActivityPost post) async {
    final list = LocalStorage.getSavedPosts();
    if (!list.any((p) => p.id == post.id)) {
      list.insert(0, post.copyWith(isSaved: true));
      await LocalStorage.saveSavedPosts(list);
    }
  }

  /// Remove post from saved collection.
  Future<void> unsavePost(String postId) async {
    final list = LocalStorage.getSavedPosts();
    list.removeWhere((p) => p.id == postId);
    await LocalStorage.saveSavedPosts(list);
  }

  /// Toggle saved status for [post] and return the new saved state.
  Future<bool> toggleSave(ActivityPost post) async {
    if (isSaved(post.id)) {
      await unsavePost(post.id);
      return false;
    } else {
      await savePost(post);
      return true;
    }
  }

  /// Filter saved collection for workout splits & routines.
  List<ActivityPost> getSavedRoutines() {
    return getSavedPosts()
        .where((p) => p.type == ActivityPostType.routine)
        .toList();
  }

  /// Filter saved collection for meal preps & recipes.
  List<ActivityPost> getSavedMeals() {
    return getSavedPosts()
        .where((p) => p.type == ActivityPostType.meal)
        .toList();
  }
}

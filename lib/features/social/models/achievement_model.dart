/// Decommissioned - Achievements have been permanently removed from Ripple.
class AchievementModel {
  final String id;
  final String title;
  final String description;
  const AchievementModel({required this.id, required this.title, required this.description});
}

class AchievementDefinitions {
  static dynamic findById(String id) => null;
}

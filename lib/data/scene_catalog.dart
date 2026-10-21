import 'package:flutter/foundation.dart';

/// A picture parents can choose for a page.
@immutable
class Scene {
  const Scene(this.name, this.asset);

  final String name;
  final String asset;
}

/// The scene illustrations bundled with the app
/// (from `social_story_reference_assets.zip/scene_illustrations`).
/// To add one, drop the PNG in `assets/images/stories/` and list it here.
abstract final class SceneCatalog {
  static const String _dir = 'assets/images/stories';

  static const List<Scene> all = [
    Scene('Going to School', '$_dir/going_to_school.png'),
    Scene('Bathroom', '$_dir/going_to_the_toilet.png'),
    Scene('Doctor', '$_dir/going_to_the_doctor.png'),
    Scene('Brushing Teeth', '$_dir/brushing_teeth.png'),
    Scene('Restaurant', '$_dir/restaurant.png'),
    Scene('Airport', '$_dir/airport.png'),
    Scene('Playground', '$_dir/playground.png'),
    Scene('Sharing', '$_dir/sharing.png'),
    Scene('Asking for Help', '$_dir/asking_for_help.png'),
    Scene('Personal Space', '$_dir/personal_space.png'),
    Scene('Saying No', '$_dir/saying_no.png'),
    Scene('Staying Safe', '$_dir/staying_safe.png'),
  ];

  static Scene get fallback => all.first;
}

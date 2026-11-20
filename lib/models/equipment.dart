import 'package:flutter/material.dart';

/// Categories of physical training equipment available in gyms and home setups.
enum EquipmentCategory {
  freeWeight('Free Weights'),
  machine('Machines'),
  bodyweight('Bodyweight & Calisthenics'),
  cardio('Cardio'),
  accessory('Accessories');

  final String label;
  const EquipmentCategory(this.label);
}

/// Domain model representing a distinct piece of gym or home training gear.
class Equipment {
  final String id;
  final String name;
  final EquipmentCategory category;
  final IconData icon;
  final String description;

  const Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    this.description = '',
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'freeWeight';
    final category = EquipmentCategory.values.firstWhere(
      (c) => c.name == catName || c.label == catName,
      orElse: () => EquipmentCategory.freeWeight,
    );

    final id = json['id'] as String? ?? '';
    final defaultItem = masterCatalog().firstWhere(
      (e) => e.id == id,
      orElse: () => Equipment(
        id: id,
        name: json['name'] as String? ?? 'Equipment',
        category: category,
        icon: Icons.fitness_center_rounded,
        description: json['description'] as String? ?? '',
      ),
    );

    return Equipment(
      id: id.isNotEmpty ? id : defaultItem.id,
      name: json['name'] as String? ?? defaultItem.name,
      category: category,
      icon: defaultItem.icon,
      description: json['description'] as String? ?? defaultItem.description,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'description': description,
  };

  /// Master built-in catalog of standard gym and home equipment.
  static List<Equipment> masterCatalog() {
    return const [
      // Free Weights & Benches
      Equipment(
        id: 'dumbbells',
        name: 'Dumbbells',
        category: EquipmentCategory.freeWeight,
        icon: Icons.fitness_center_rounded,
        description:
            'Adjustable or fixed dumbbells for unilateral & compound work.',
      ),
      Equipment(
        id: 'barbell',
        name: 'Barbell & Weight Plates',
        category: EquipmentCategory.freeWeight,
        icon: Icons.fitness_center_rounded,
        description:
            'Standard Olympic bar and bumper plates for heavy compound lifts.',
      ),
      Equipment(
        id: 'bench',
        name: 'Adjustable Bench',
        category: EquipmentCategory.freeWeight,
        icon: Icons.airline_seat_recline_normal_rounded,
        description:
            'Flat, incline, and decline bench for pressing and support.',
      ),
      Equipment(
        id: 'squat_rack',
        name: 'Squat Rack / Power Cage',
        category: EquipmentCategory.freeWeight,
        icon: Icons.grid_view_rounded,
        description: 'Heavy rack for squats, overhead presses, and rack pulls.',
      ),
      Equipment(
        id: 'kettlebells',
        name: 'Kettlebells',
        category: EquipmentCategory.freeWeight,
        icon: Icons.radio_button_checked_rounded,
        description: 'Kettlebells for swings, snatches, and functional power.',
      ),
      Equipment(
        id: 'ez_curl_bar',
        name: 'EZ Curl Bar',
        category: EquipmentCategory.freeWeight,
        icon: Icons.linear_scale_rounded,
        description:
            'Ergonomic undulating bar for arm curls and skull crushers.',
      ),

      // Machines
      Equipment(
        id: 'cable_machine',
        name: 'Cable Machine / Crossover',
        category: EquipmentCategory.machine,
        icon: Icons.cable_rounded,
        description: 'Dual adjustable pulleys with various attachments.',
      ),
      Equipment(
        id: 'smith_machine',
        name: 'Smith Machine',
        category: EquipmentCategory.machine,
        icon: Icons.table_rows_rounded,
        description: 'Guided barbell track for controlled compound movements.',
      ),
      Equipment(
        id: 'leg_press',
        name: 'Leg Press Machine',
        category: EquipmentCategory.machine,
        icon: Icons.airline_seat_flat_rounded,
        description: '45-degree or horizontal plate-loaded leg press sled.',
      ),
      Equipment(
        id: 'lat_pulldown',
        name: 'Lat Pulldown & Low Row',
        category: EquipmentCategory.machine,
        icon: Icons.vertical_align_bottom_rounded,
        description: 'Overhead pulley and seated cable row apparatus.',
      ),
      Equipment(
        id: 'leg_extension_curl',
        name: 'Leg Extension & Leg Curl',
        category: EquipmentCategory.machine,
        icon: Icons.airline_seat_legroom_extra_rounded,
        description: 'Isolated quadriceps and hamstring isolation stations.',
      ),
      Equipment(
        id: 'chest_press_machine',
        name: 'Chest Press Machine',
        category: EquipmentCategory.machine,
        icon: Icons.view_sidebar_rounded,
        description:
            'Seated plate-loaded or pin-select chest pressing machine.',
      ),

      // Bodyweight & Calisthenics
      Equipment(
        id: 'pull_up_bar',
        name: 'Pull-up Bar',
        category: EquipmentCategory.bodyweight,
        icon: Icons.pan_tool_rounded,
        description: 'Overhead bar for wide, neutral, and supinated pull-ups.',
      ),
      Equipment(
        id: 'dip_station',
        name: 'Dip Station / Parallel Bars',
        category: EquipmentCategory.bodyweight,
        icon: Icons.view_column_rounded,
        description: 'Parallel bars for bodyweight chest and tricep dips.',
      ),
      Equipment(
        id: 'ab_wheel',
        name: 'Ab Roller / Wheel',
        category: EquipmentCategory.bodyweight,
        icon: Icons.album_rounded,
        description: 'Rolling wheel for intense anterior core rollouts.',
      ),

      // Cardio
      Equipment(
        id: 'treadmill',
        name: 'Treadmill',
        category: EquipmentCategory.cardio,
        icon: Icons.directions_run_rounded,
        description: 'Motorized incline running and walking track.',
      ),
      Equipment(
        id: 'stationary_bike',
        name: 'Stationary / Spin Bike',
        category: EquipmentCategory.cardio,
        icon: Icons.directions_bike_rounded,
        description: 'Upright or magnetic resistance cardio cycling bike.',
      ),
      Equipment(
        id: 'rowing_machine',
        name: 'Rowing Machine (Ergometer)',
        category: EquipmentCategory.cardio,
        icon: Icons.kayaking_rounded,
        description: 'Air or water resistance full-body cardio rower.',
      ),

      // Accessories
      Equipment(
        id: 'resistance_bands',
        name: 'Resistance Bands',
        category: EquipmentCategory.accessory,
        icon: Icons.all_inclusive_rounded,
        description: 'Elastic loop and tube bands for warmup and banded reps.',
      ),
      Equipment(
        id: 'foam_roller',
        name: 'Foam Roller',
        category: EquipmentCategory.accessory,
        icon: Icons.blur_linear_rounded,
        description:
            'Myofascial release roller for muscle recovery and warmup.',
      ),
      Equipment(
        id: 'exercise_mat',
        name: 'Yoga / Exercise Mat',
        category: EquipmentCategory.accessory,
        icon: Icons.layers_rounded,
        description:
            'Padded floor mat for core work, stretching, and mobility.',
      ),
    ];
  }
}

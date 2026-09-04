class PlantGrowthRecord {
  final int id;
  final String species;
  final String location;
  final DateTime plantedDate;
  final int currentMonth;
  final bool isMonthVerified;
  final int pointsEarned;
  final bool isForfeited;

  PlantGrowthRecord({
    required this.id,
    required this.species,
    required this.location,
    required this.plantedDate,
    required this.currentMonth,
    required this.isMonthVerified,
    required this.pointsEarned,
    this.isForfeited = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'species': species,
    'location': location,
    'plantedDate': plantedDate.toIso8601String(),
    'currentMonth': currentMonth,
    'isMonthVerified': isMonthVerified,
    'pointsEarned': pointsEarned,
    'isForfeited': isForfeited,
  };

  factory PlantGrowthRecord.fromJson(Map<String, dynamic> json) => PlantGrowthRecord(
    id: json['id'] as int? ?? 1,
    species: json['species'] as String? ?? 'Sapling',
    location: json['location'] as String? ?? 'Local',
    plantedDate: DateTime.tryParse(json['plantedDate']?.toString() ?? '') ?? DateTime.now(),
    currentMonth: json['currentMonth'] as int? ?? 1,
    isMonthVerified: json['isMonthVerified'] as bool? ?? false,
    pointsEarned: json['pointsEarned'] as int? ?? 100,
    isForfeited: json['isForfeited'] as bool? ?? false,
  );
}

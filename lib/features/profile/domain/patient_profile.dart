class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.displayName,
    required this.updatedAt,
    this.age,
    this.notes = '',
  });

  final String id;
  final String displayName;
  final int? age;
  final String notes;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'display_name': displayName,
    'age': age,
    'notes': notes,
    'updated_at_ms': updatedAt.millisecondsSinceEpoch,
  };

  factory PatientProfile.fromMap(Map<String, Object?> map) => PatientProfile(
    id: map['id']! as String,
    displayName: map['display_name']! as String,
    age: map['age'] as int?,
    notes: (map['notes'] as String?) ?? '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at_ms']! as int,
    ),
  );
}

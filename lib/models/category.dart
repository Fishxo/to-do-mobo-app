/// A user-created or default task category.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    required this.isDefault,
    required this.createdAt,
  });

  final int id;
  final String name;

  /// ARGB color stored as an integer so it survives SQLite round-trips.
  final int colorValue;

  /// Material icon code point stored as an integer.
  final int iconCodePoint;
  final bool isDefault;
  final DateTime createdAt;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      colorValue: (map['color_value'] as num?)?.toInt() ?? 0xFF3F51B5,
      iconCodePoint:
          (map['icon_code_point'] as num?)?.toInt() ?? 0xe2c7, // folder
      isDefault: ((map['is_default'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'name': name,
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? colorValue,
    int? iconCodePoint,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

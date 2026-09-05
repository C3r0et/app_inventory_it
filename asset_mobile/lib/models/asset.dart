class Asset {
  final String id;
  final String type;
  final String status;
  final String location;
  final String? specs;
  final String? legacyInvCode;
  final String? stickerStatus;
  final String? imagePath;
  final DateTime? updatedAt;
  final String? note;
  bool isSynced; // For offline mode

  Asset({
    required this.id,
    required this.type,
    required this.status,
    required this.location,
    this.specs,
    this.legacyInvCode,
    this.stickerStatus,
    this.imagePath,
    this.updatedAt,
    this.note,
    this.isSynced = true,
  });

  // From JSON (API response)
  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      type: json['type'],
      status: json['status'],
      location: json['location'],
      specs: json['specs'],
      legacyInvCode: json['legacy_inv_code'],
      stickerStatus: json['sticker_status'],
      imagePath: json['image_path'],
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      note: json['note'],
      isSynced: true,
    );
  }

  // To JSON (API request)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'location': location,
      'specs': specs,
      'legacy_inv_code': legacyInvCode,
      'sticker_status': stickerStatus,
      'image_path': imagePath,
      'note': note,
    };
  }

  // From SQLite
  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      type: map['type'],
      status: map['status'],
      location: map['location'],
      specs: map['specs'],
      imagePath: map['image_path'],
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
      note: map['note'],
      isSynced: map['is_synced'] == 1,
    );
  }

  // To SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'location': location,
      'specs': specs,
      'image_path': imagePath,
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'note': note,
    };
  }

  /// Returns the detected year from legacyInvCode, id, note, specs, or updatedAt
  String? get year {
    // 1. Check legacyInvCode (e.g., "HD/1126/2025", "MN/0181/2024")
    if (legacyInvCode != null && legacyInvCode!.isNotEmpty) {
      final match = RegExp(r'\b(20\d{2})\b').firstMatch(legacyInvCode!);
      if (match != null) return match.group(1);
    }
    // 2. Check id (e.g., "PC/001/2025" or "LAP-2024-001")
    final idMatch = RegExp(r'\b(20\d{2})\b').firstMatch(id);
    if (idMatch != null) return idMatch.group(1);

    // 3. Check note (e.g., "26/02/2026", "Tahun 2024")
    if (note != null && note!.isNotEmpty) {
      final noteMatch = RegExp(r'\b(20\d{2})\b').firstMatch(note!);
      if (noteMatch != null) return noteMatch.group(1);
    }

    // 4. Check specs (e.g., "Th 2023", "2024")
    if (specs != null && specs!.isNotEmpty) {
      final specMatch = RegExp(r'\b(20\d{2})\b').firstMatch(specs!);
      if (specMatch != null) return specMatch.group(1);
    }

    // 5. Fallback to updatedAt if available
    if (updatedAt != null) {
      return updatedAt!.year.toString();
    }

    return null;
  }

  Asset copyWith({
    String? id,
    String? type,
    String? status,
    String? location,
    String? specs,
    String? legacyInvCode,
    String? stickerStatus,
    String? imagePath,
    DateTime? updatedAt,
    String? note,
    bool? isSynced,
  }) {
    return Asset(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      location: location ?? this.location,
      specs: specs ?? this.specs,
      legacyInvCode: legacyInvCode ?? this.legacyInvCode,
      stickerStatus: stickerStatus ?? this.stickerStatus,
      imagePath: imagePath ?? this.imagePath,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

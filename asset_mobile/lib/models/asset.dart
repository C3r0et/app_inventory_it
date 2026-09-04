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

  Asset copyWith({
    String? id,
    String? type,
    String? status,
    String? location,
    String? specs,
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
      imagePath: imagePath ?? this.imagePath,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

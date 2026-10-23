import 'package:equatable/equatable.dart';

/// Metadata model for a user profile in the app registry.
class AppUserProfileMeta extends Equatable {
  final String id;
  final String displayName;
  final String? avatarPath;
  final DateTime createdAt;

  const AppUserProfileMeta({
    required this.id,
    required this.displayName,
    this.avatarPath,
    required this.createdAt,
  });

  AppUserProfileMeta copyWith({
    String? id,
    String? displayName,
    String? avatarPath,
    bool clearAvatar = false,
    DateTime? createdAt,
  }) {
    return AppUserProfileMeta(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarPath': avatarPath,
      'createdAtIso': createdAt.toIso8601String(),
    };
  }

  factory AppUserProfileMeta.fromJson(Map<String, dynamic> json) {
    return AppUserProfileMeta(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarPath: json['avatarPath'] as String?,
      createdAt: DateTime.parse(json['createdAtIso'] as String),
    );
  }

  @override
  List<Object?> get props => [id, displayName, avatarPath, createdAt];
}


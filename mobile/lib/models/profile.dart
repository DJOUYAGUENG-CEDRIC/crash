import 'enums.dart';

class Profile {
  final String id;
  final String email;
  final String displayName;
  final AccountStatus status;
  final String? invitationId;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.invitationId,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String,
    status: AccountStatus.fromJson(json['status'] as String),
    invitationId: json['invitation_id'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class UserEntity {
  final String id;
  final String username;
  final String email;
  final bool emailVerified;
  final String? firstName;
  final String? lastName;

  UserEntity({
    required this.id,
    required this.username,
    required this.email,
    required this.emailVerified,
    this.firstName,
    this.lastName,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['sub'] ?? '',
      username: json['preferred_username'] ?? '',
      email: json['email'] ?? '',
      emailVerified: json['email_verified'] ?? false,
      firstName: json['given_name'],
      lastName: json['family_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'emailVerified': emailVerified,
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  @override
  String toString() {
    return 'UserEntity{id: $id, username: $username, email: $email, emailVerified: $emailVerified, firstName: $firstName, lastName: $lastName}';
  }
}

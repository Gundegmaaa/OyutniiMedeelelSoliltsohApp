class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.emailVerified,
    this.firstName = '',
    this.lastName = '',
    this.studentCode,
    this.course,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool emailVerified;
  final String firstName;
  final String lastName;
  final String? studentCode;
  final int? course;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String,
    role: json['role'] as String,
    emailVerified: json['email_verified'] as bool,
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    studentCode: json['student_code'] as String?,
    course: json['course'] as int?,
  );
}

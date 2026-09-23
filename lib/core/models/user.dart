class User {
  final String phoneNumber;
  final String role;
  final String? level;
  final String? fullName;
  final String referralCode;
  final String? invitedBy;

  const User({
    required this.phoneNumber,
    required this.role,
    this.level,
    this.fullName,
    required this.referralCode,
    this.invitedBy,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        phoneNumber: json['phone_number'] as String? ?? '',
        role: json['role'] as String? ?? '',
        level: json['level'] as String?,
        fullName: json['full_name'] as String?,
        referralCode: json['referral_code'] as String? ?? '',
        invitedBy: json['invited_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'phone_number': phoneNumber,
        'role': role,
        'level': level,
        'full_name': fullName,
        'referral_code': referralCode,
        'invited_by': invitedBy,
      };

  String get displayName {
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return 'کارواش‌دار';
    return name;
  }
}

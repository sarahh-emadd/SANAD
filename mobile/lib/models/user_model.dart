class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? photoUrl;
  final String? fcmToken;
  final bool emailVerified;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.photoUrl,
    this.fcmToken,
    this.emailVerified = false,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:            json['id']?.toString() ?? '',
      firebaseUid:   json['firebase_uid'] ?? '',
      email:         json['email'] ?? '',
      firstName:     json['first_name'] ?? '',
      lastName:      json['last_name'] ?? '',
      phone:         json['phone'],
      photoUrl:      json['photo_url'],
      fcmToken:      json['fcm_token'],
      emailVerified: json['email_verified'] ?? false,
      createdAt:     json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'firebase_uid':   firebaseUid,
    'email':          email,
    'first_name':     firstName,
    'last_name':      lastName,
    'phone':          phone,
    'photo_url':      photoUrl,
    'fcm_token':      fcmToken,
    'email_verified': emailVerified,
    'created_at':     createdAt.toIso8601String(),
  };
}

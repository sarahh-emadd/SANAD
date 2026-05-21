class ElderlyModel {
  final String id;
  final String caregiverId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodType;
  final String? phone;
  final String? photoUrl;

  // Emergency Contact
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? emergencyContactRelationship;
  final String? emergencyContactEmail;

  // Address
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  // Medical
  final String? medicalConditions;
  final String? allergies;
  final String? currentMedications;
  final String? doctorName;
  final String? doctorPhone;
  final String? hospitalPreference;

  // Routine
  final String? mobilityLevel;
  final String? typicalSleepTime;
  final String? typicalWakeTime;

  // Status
  final bool isConnected;
  final String status;
  final DateTime? lastSeen;
  final DateTime createdAt;

  ElderlyModel({
    required this.id,
    required this.caregiverId,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.phone,
    this.photoUrl,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.emergencyContactEmail,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.medicalConditions,
    this.allergies,
    this.currentMedications,
    this.doctorName,
    this.doctorPhone,
    this.hospitalPreference,
    this.mobilityLevel,
    this.typicalSleepTime,
    this.typicalWakeTime,
    this.isConnected = false,
    this.status = 'active',
    this.lastSeen,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  /// Build from all 4 form steps to send to backend
  static Map<String, dynamic> toRequestBody(Map<String, dynamic> formData) {
    return {
      'first_name':                      formData['firstName'],
      'last_name':                       formData['lastName'],
      'date_of_birth':                   formData['dateOfBirth'] != null
          ? (formData['dateOfBirth'] as DateTime).toIso8601String().split('T')[0]
          : null,
      'gender':                          (formData['gender'] as String?)?.toLowerCase(),
      'blood_type':                      formData['bloodType'],
      'phone':                           formData['phone'],
      'photo_url':                       formData['photoUrl'],
      'emergency_contact_name':          formData['emergencyName'],
      'emergency_contact_phone':         formData['emergencyPhone'],
      'emergency_contact_relationship':  formData['emergencyRelationship'],
      'emergency_contact_email':         formData['emergencyEmail'],
      'address':                         formData['address'],
      'city':                            formData['city'],
      'state':                           formData['state'],
      'postal_code':                     formData['postalCode'],
      'country':                         formData['country'],
      'medical_conditions':              formData['medicalConditions'],
      'allergies':                       formData['allergies'],
      'current_medications':             formData['currentMedications'],
      'doctor_name':                     formData['doctorName'],
      'doctor_phone':                    formData['doctorPhone'],
      'hospital_preference':             formData['hospitalPreference'],
      'mobility_level':                  formData['mobilityLevel'],
      'typical_sleep_time':              formData['sleepTime'],
      'typical_wake_time':               formData['wakeTime'],
    };
  }

  factory ElderlyModel.fromJson(Map<String, dynamic> json) {
    return ElderlyModel(
      id:                            json['id']?.toString() ?? '',
      caregiverId:                   json['caregiver_id']?.toString() ?? '',
      firstName:                     json['first_name'] ?? '',
      lastName:                      json['last_name'] ?? '',
      dateOfBirth:                   json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'])
          : null,
      gender:                        json['gender'],
      bloodType:                     json['blood_type'],
      phone:                         json['phone'],
      photoUrl:                      json['photo_url'],
      emergencyContactName:          json['emergency_contact_name'] ?? '',
      emergencyContactPhone:         json['emergency_contact_phone'] ?? '',
      emergencyContactRelationship:  json['emergency_contact_relationship'],
      emergencyContactEmail:         json['emergency_contact_email'],
      address:                       json['address'],
      city:                          json['city'],
      state:                         json['state'],
      postalCode:                    json['postal_code'],
      country:                       json['country'],
      medicalConditions:             json['medical_conditions'],
      allergies:                     json['allergies'],
      currentMedications:            json['current_medications'],
      doctorName:                    json['doctor_name'],
      doctorPhone:                   json['doctor_phone'],
      hospitalPreference:            json['hospital_preference'],
      mobilityLevel:                 json['mobility_level'],
      typicalSleepTime:              json['typical_sleep_time'],
      typicalWakeTime:               json['typical_wake_time'],
      isConnected:                   json['is_connected'] ?? false,
      status:                        json['status'] ?? 'active',
      lastSeen:                      json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'])
          : null,
      createdAt:                     json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

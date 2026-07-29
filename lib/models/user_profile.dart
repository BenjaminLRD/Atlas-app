class UserProfile {
  String name;
  String email;
  String phone;
  String dob;
  String gender;
  String height;
  String weight;
  String fitnessGoal;
  String workoutExperience;
  List<String> preferredDays;
  String dietPreference;
  String massUnit;
  String lengthUnit;
  String subscription;
  String password;
  String privacy;
  bool notificationsEnabled;
  String profilePic;

  /// Dynamic storage for extra fields set by onboarding or future UI additions
  final Map<String, dynamic> extraFields;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.dob,
    required this.gender,
    required this.height,
    required this.weight,
    required this.fitnessGoal,
    required this.workoutExperience,
    required this.preferredDays,
    required this.dietPreference,
    required this.massUnit,
    required this.lengthUnit,
    required this.subscription,
    required this.password,
    required this.privacy,
    required this.notificationsEnabled,
    required this.profilePic,
    Map<String, dynamic>? extraFields,
  }) : extraFields = extraFields ?? {};

  /// Creates a default UserProfile instance
  factory UserProfile.defaultProfile() {
    return UserProfile(
      name: 'Zothanmawia',
      email: 'zothana@aizawlgym.com',
      phone: '9876543210',
      dob: '1995-10-15',
      gender: 'Male',
      height: '175',
      weight: '68.2',
      fitnessGoal: 'Build Muscle',
      workoutExperience: 'Intermediate',
      preferredDays: ['Monday', 'Wednesday', 'Friday'],
      dietPreference: 'High Protein',
      massUnit: 'kg',
      lengthUnit: 'cm',
      subscription: 'Free',
      password: 'password123',
      privacy: 'Friends Only',
      notificationsEnabled: true,
      profilePic: '',
    );
  }

  /// Construct UserProfile from JSON map
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final knownKeys = {
      'name',
      'email',
      'phone',
      'dob',
      'gender',
      'height',
      'weight',
      'fitnessGoal',
      'workoutExperience',
      'preferredDays',
      'dietPreference',
      'massUnit',
      'lengthUnit',
      'subscription',
      'password',
      'privacy',
      'notificationsEnabled',
      'profilePic',
    };

    final extra = <String, dynamic>{};
    json.forEach((key, value) {
      if (!knownKeys.contains(key)) {
        extra[key] = value;
      }
    });

    return UserProfile(
      name: json['name'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      dob: json['dob'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Male',
      height: json['height']?.toString() ?? '175',
      weight: json['weight']?.toString() ?? '68.2',
      fitnessGoal: json['fitnessGoal'] as String? ?? json['goal'] as String? ?? 'Build Muscle',
      workoutExperience:
          json['workoutExperience'] as String? ?? json['level'] as String? ?? 'Intermediate',
      preferredDays: (json['preferredDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dietPreference:
          json['dietPreference'] as String? ?? json['diet'] as String? ?? 'High Protein',
      massUnit: json['massUnit'] as String? ?? 'kg',
      lengthUnit: json['lengthUnit'] as String? ?? 'cm',
      subscription: json['subscription'] as String? ?? 'Free',
      password: json['password'] as String? ?? '',
      privacy: json['privacy'] as String? ?? 'Friends Only',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      profilePic: json['profilePic'] as String? ?? '',
      extraFields: extra,
    );
  }

  /// Convert UserProfile to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'height': height,
      'weight': weight,
      'fitnessGoal': fitnessGoal,
      'workoutExperience': workoutExperience,
      'preferredDays': preferredDays,
      'dietPreference': dietPreference,
      'massUnit': massUnit,
      'lengthUnit': lengthUnit,
      'subscription': subscription,
      'password': password,
      'privacy': privacy,
      'notificationsEnabled': notificationsEnabled,
      'profilePic': profilePic,
      'goal': fitnessGoal,
      'level': workoutExperience,
      'diet': dietPreference,
      ...extraFields,
    };
  }

  /// Map indexing operator for backwards compatibility with dynamic maps
  dynamic operator [](String key) {
    switch (key) {
      case 'name':
        return name;
      case 'email':
        return email;
      case 'phone':
        return phone;
      case 'dob':
        return dob;
      case 'gender':
        return gender;
      case 'height':
        return height;
      case 'weight':
        return weight;
      case 'fitnessGoal':
      case 'goal':
        return fitnessGoal;
      case 'workoutExperience':
      case 'level':
        return workoutExperience;
      case 'preferredDays':
        return preferredDays;
      case 'dietPreference':
      case 'diet':
        return dietPreference;
      case 'massUnit':
        return massUnit;
      case 'lengthUnit':
        return lengthUnit;
      case 'subscription':
        return subscription;
      case 'password':
        return password;
      case 'privacy':
        return privacy;
      case 'notificationsEnabled':
        return notificationsEnabled;
      case 'profilePic':
        return profilePic;
      default:
        return extraFields[key];
    }
  }

  /// Map assignment operator for backwards compatibility with dynamic maps
  void operator []=(String key, dynamic value) {
    switch (key) {
      case 'name':
        name = value?.toString() ?? name;
        break;
      case 'email':
        email = value?.toString() ?? email;
        break;
      case 'phone':
        phone = value?.toString() ?? phone;
        break;
      case 'dob':
        dob = value?.toString() ?? dob;
        break;
      case 'gender':
        gender = value?.toString() ?? gender;
        break;
      case 'height':
        height = value?.toString() ?? height;
        break;
      case 'weight':
        weight = value?.toString() ?? weight;
        break;
      case 'fitnessGoal':
      case 'goal':
        fitnessGoal = value?.toString() ?? fitnessGoal;
        extraFields['goal'] = value;
        break;
      case 'workoutExperience':
      case 'level':
        workoutExperience = value?.toString() ?? workoutExperience;
        extraFields['level'] = value;
        break;
      case 'preferredDays':
        if (value is List) {
          preferredDays = value.map((e) => e.toString()).toList();
        }
        break;
      case 'dietPreference':
      case 'diet':
        dietPreference = value?.toString() ?? dietPreference;
        extraFields['diet'] = value;
        break;
      case 'massUnit':
        massUnit = value?.toString() ?? massUnit;
        break;
      case 'lengthUnit':
        lengthUnit = value?.toString() ?? lengthUnit;
        break;
      case 'subscription':
        subscription = value?.toString() ?? subscription;
        break;
      case 'password':
        password = value?.toString() ?? password;
        break;
      case 'privacy':
        privacy = value?.toString() ?? privacy;
        break;
      case 'notificationsEnabled':
        if (value is bool) notificationsEnabled = value;
        break;
      case 'profilePic':
        profilePic = value?.toString() ?? profilePic;
        break;
      default:
        extraFields[key] = value;
        break;
    }
  }

  /// Copy with helper method
  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? dob,
    String? gender,
    String? height,
    String? weight,
    String? fitnessGoal,
    String? workoutExperience,
    List<String>? preferredDays,
    String? dietPreference,
    String? massUnit,
    String? lengthUnit,
    String? subscription,
    String? password,
    String? privacy,
    bool? notificationsEnabled,
    String? profilePic,
    Map<String, dynamic>? extraFields,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      workoutExperience: workoutExperience ?? this.workoutExperience,
      preferredDays: preferredDays ?? List.from(this.preferredDays),
      dietPreference: dietPreference ?? this.dietPreference,
      massUnit: massUnit ?? this.massUnit,
      lengthUnit: lengthUnit ?? this.lengthUnit,
      subscription: subscription ?? this.subscription,
      password: password ?? this.password,
      privacy: privacy ?? this.privacy,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profilePic: profilePic ?? this.profilePic,
      extraFields: extraFields ?? Map.from(this.extraFields),
    );
  }
}

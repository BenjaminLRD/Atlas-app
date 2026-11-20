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
    required this.privacy,
    required this.notificationsEnabled,
    required this.profilePic,
    Map<String, dynamic>? extraFields,
  }) : extraFields = extraFields ?? {};

  /// User identifier linked to authentication identity
  String get userId =>
      extraFields['userId'] as String? ??
      (email.isNotEmpty ? email : 'usr_local_01');
  set userId(String val) => extraFields['userId'] = val;

  /// Alias for fitnessGoal
  String get goal => fitnessGoal;
  set goal(String val) => fitnessGoal = val;

  /// Alias for workoutExperience
  String get experienceLevel => workoutExperience;
  set experienceLevel(String val) => workoutExperience = val;

  /// Available equipment list
  List<String> get equipment =>
      (extraFields['equipment'] as List?)?.map((e) => e.toString()).toList() ??
      const [];
  set equipment(List<String> list) => extraFields['equipment'] = list;

  /// Target weight goal string
  String get targetWeight => extraFields['targetWeight']?.toString() ?? '';
  set targetWeight(String val) => extraFields['targetWeight'] = val;

  /// User bio description
  String get bio => extraFields['bio']?.toString() ?? '';
  set bio(String val) => extraFields['bio'] = val;

  /// List of physical injuries or limitations
  List<String> get injuries =>
      (extraFields['injuries'] as List?)?.map((e) => e.toString()).toList() ??
      const [];
  set injuries(List<String> list) => extraFields['injuries'] = list;

  /// Computed or stored age
  int get age {
    if (dob.isNotEmpty) {
      try {
        final birthDate = DateTime.parse(dob);
        final today = DateTime.now();
        int calculated = today.year - birthDate.year;
        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          calculated--;
        }
        return calculated > 0 ? calculated : 25;
      } catch (_) {}
    }
    return (extraFields['age'] as num?)?.toInt() ?? 25;
  }

  set age(int val) => extraFields['age'] = val;

  /// Creates a default empty UserProfile instance for new users
  factory UserProfile.defaultProfile({String email = ''}) {
    return UserProfile(
      name: '',
      email: email,
      phone: '',
      dob: '',
      gender: '',
      height: '',
      weight: '',
      fitnessGoal: '',
      workoutExperience: '',
      preferredDays: const [],
      dietPreference: '',
      massUnit: 'kg',
      lengthUnit: 'cm',
      subscription: 'Free',
      privacy: 'Friends Only',
      notificationsEnabled: true,
      profilePic: '',
    );
  }

  /// Known hardcoded placeholder names to sanitize
  static const Set<String> _placeholderNames = {
    'zothanmawia',
    'user',
    'athlete',
  };

  /// Sanitizes input name string. Returns empty string if name is null, empty, or a known placeholder.
  static String sanitizeName(String? rawName) {
    if (rawName == null) return '';
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '';
    if (_placeholderNames.contains(trimmed.toLowerCase())) {
      return '';
    }
    return trimmed;
  }

  /// Checks if a profile matches the legacy demo profile dataset
  static bool isLegacyDemoProfile(UserProfile profile) {
    final lowerEmail = profile.email.trim().toLowerCase();
    if (lowerEmail == 'zothana@aizawlgym.com') {
      return true;
    }
    final isDemoPhone = profile.phone.trim() == '9876543210';
    final isDemoHeight =
        profile.height.trim() == '175' || profile.height.trim() == '175.0';
    final isDemoWeight =
        profile.weight.trim() == '68.2' || profile.weight.trim() == '68.2 kg';
    final isDemoGender = profile.gender.trim().toLowerCase() == 'male';

    if (isDemoPhone && isDemoHeight && isDemoWeight && isDemoGender) {
      return true;
    }

    if (lowerEmail.isEmpty && isDemoPhone && isDemoHeight && isDemoWeight) {
      return true;
    }

    return false;
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

    final profile = UserProfile(
      name: sanitizeName(json['name'] as String?),
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      dob: json['dob'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      height: json['height']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      fitnessGoal:
          json['fitnessGoal'] as String? ?? json['goal'] as String? ?? '',
      workoutExperience:
          json['workoutExperience'] as String? ??
          json['level'] as String? ??
          '',
      preferredDays:
          (json['preferredDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dietPreference:
          json['dietPreference'] as String? ?? json['diet'] as String? ?? '',
      massUnit: json['massUnit'] as String? ?? 'kg',
      lengthUnit: json['lengthUnit'] as String? ?? 'cm',
      subscription: json['subscription'] as String? ?? 'Free',
      privacy: json['privacy'] as String? ?? 'Friends Only',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      profilePic: json['profilePic'] as String? ?? '',
      extraFields: extra,
    );

    if (isLegacyDemoProfile(profile)) {
      final authEmail = json['email'] as String? ?? '';
      final cleanEmail =
          authEmail.trim().toLowerCase() == 'zothana@aizawlgym.com'
          ? ''
          : authEmail;
      return UserProfile.defaultProfile(email: cleanEmail);
    }

    return profile;
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
      privacy: privacy ?? this.privacy,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profilePic: profilePic ?? this.profilePic,
      extraFields: extraFields ?? Map.from(this.extraFields),
    );
  }
}

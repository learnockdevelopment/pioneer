import 'dart:convert';

class Workspace {
  final String id;
  final String tenant;
  final String host;
  final String name;
  final String studentName;
  final String email;
  final String? studentPhotoUrl;
  final String token;
  final String deviceId;
  final int addedAt;
  
  // BRANDING ENRICHMENT
  final String? teacherName;
  final String? theme;
  final String? heroTitle;
  final String? heroSubtitle;
  final String? aboutTeacher;
  final String? whatsappNumber;
  final String? logoUrl;
  final String? themeColor;
  
  // JSON DATA
  final String? faqsJson;
  final String? featuresJson;
  final String? latestCoursesJson;
  final bool enablePurchasing;

  Workspace({
    required this.id,
    required this.tenant,
    required this.host,
    required this.name,
    required this.studentName,
    required this.email,
    this.studentPhotoUrl,
    required this.token,
    required this.deviceId,
    required this.addedAt,
    this.teacherName,
    this.theme,
    this.heroTitle,
    this.heroSubtitle,
    this.aboutTeacher,
    this.whatsappNumber,
    this.logoUrl,
    this.themeColor,
    this.faqsJson,
    this.featuresJson,
    this.latestCoursesJson,
    this.enablePurchasing = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant': tenant,
    'host': host,
    'name': name,
    'studentName': studentName,
    'email': email,
    'studentPhotoUrl': studentPhotoUrl,
    'token': token,
    'deviceId': deviceId,
    'addedAt': addedAt,
    'teacherName': teacherName,
    'theme': theme,
    'heroTitle': heroTitle,
    'heroSubtitle': heroSubtitle,
    'aboutTeacher': aboutTeacher,
    'whatsappNumber': whatsappNumber,
    'logoUrl': logoUrl,
    'themeColor': themeColor,
    'faqsJson': faqsJson,
    'featuresJson': featuresJson,
    'latestCoursesJson': latestCoursesJson,
    'enablePurchasing': enablePurchasing,
  };

  Workspace copyWith({
    String? id,
    String? tenant,
    String? host,
    String? name,
    String? studentName,
    String? email,
    String? studentPhotoUrl,
    String? token,
    String? deviceId,
    int? addedAt,
    String? teacherName,
    String? theme,
    String? heroTitle,
    String? heroSubtitle,
    String? aboutTeacher,
    String? whatsappNumber,
    String? logoUrl,
    String? themeColor,
    String? faqsJson,
    String? featuresJson,
    String? latestCoursesJson,
    bool? enablePurchasing,
  }) => Workspace(
    id: id ?? this.id,
    tenant: tenant ?? this.tenant,
    host: host ?? this.host,
    name: name ?? this.name,
    studentName: studentName ?? this.studentName,
    email: email ?? this.email,
    studentPhotoUrl: studentPhotoUrl ?? this.studentPhotoUrl,
    token: token ?? this.token,
    deviceId: deviceId ?? this.deviceId,
    addedAt: addedAt ?? this.addedAt,
    teacherName: teacherName ?? this.teacherName,
    theme: theme ?? this.theme,
    heroTitle: heroTitle ?? this.heroTitle,
    heroSubtitle: heroSubtitle ?? this.heroSubtitle,
    aboutTeacher: aboutTeacher ?? this.aboutTeacher,
    whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    logoUrl: logoUrl ?? this.logoUrl,
    themeColor: themeColor ?? this.themeColor,
    faqsJson: faqsJson ?? this.faqsJson,
    featuresJson: featuresJson ?? this.featuresJson,
    latestCoursesJson: latestCoursesJson ?? this.latestCoursesJson,
    enablePurchasing: enablePurchasing ?? this.enablePurchasing,
  );

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    id: json['id'] ?? '',
    tenant: json['tenant'] ?? '',
    host: json['host'] ?? '',
    name: json['name'] ?? '',
    studentName: json['studentName'] ?? '',
    email: json['email'] ?? '',
    studentPhotoUrl: json['studentPhotoUrl'],
    token: json['token'] ?? '',
    deviceId: json['deviceId'] ?? '',
    addedAt: json['addedAt'] ?? 0,
    teacherName: json['teacherName'],
    theme: json['theme'],
    heroTitle: json['heroTitle'],
    heroSubtitle: json['heroSubtitle'],
    aboutTeacher: json['aboutTeacher'],
    whatsappNumber: json['whatsappNumber'],
    logoUrl: json['logoUrl'],
    themeColor: json['themeColor'],
    faqsJson: json['faqsJson'],
    featuresJson: json['featuresJson'],
    latestCoursesJson: json['latestCoursesJson'],
    enablePurchasing: json['enablePurchasing'] ?? true,
  );
}

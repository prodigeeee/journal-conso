class UserProfile {
  String id;
  String name;
  String gender;
  int age;
  int weight;
  int colorValue;
  String? imagePath;
  UserProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    this.weight = 70,
    this.colorValue = 0xFFEA9216,
    this.imagePath,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'age': age,
    'weight': weight,
    'colorValue': colorValue,
    'imagePath': imagePath,
  };
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    name: json['name'] ?? '',
    gender: json['gender'] ?? 'Homme',
    age: (json['age'] as num).toInt(),
    weight: (json['weight'] as num?)?.toInt() ?? 70,
    colorValue: json['colorValue'] ?? 0xFFEA9216,
    imagePath: json['imagePath'],
  );
}

class Consumption {
  String id;
  DateTime date;
  String moment;
  String type;
  String volume;
  double degree;
  String userId;
  Consumption({
    required this.id,
    required this.date,
    required this.moment,
    required this.type,
    required this.volume,
    required this.degree,
    required this.userId,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'moment': moment,
    'type': type,
    'volume': volume,
    'degree': degree,
    'userId': userId,
  };
  factory Consumption.fromJson(Map<String, dynamic> json) => Consumption(
    id: json['id'],
    date: DateTime.parse(json['date']),
    moment: json['moment'] ?? 'Soir',
    type: json['type'],
    volume: json['volume'],
    degree: (json['degree'] as num).toDouble(),
    userId: json['userId'] ?? '1',
  );
}

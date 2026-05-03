class Category {
  final int? id;
  final String name;
  final String icon;
  final String type;

  Category({this.id, required this.name, required this.icon, required this.type});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'type': type,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'],
    name: map['name'],
    icon: map['icon'],
    type: map['type'],
  );
}
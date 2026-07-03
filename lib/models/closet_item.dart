class ClosetItem {
  final String id;
  final String category; // 'top', 'bottom', 'outer', 'shoes', 'accessory'
  final String imagePath;
  final String hexColor;
  final String colorName;

  ClosetItem({
    required this.id,
    required this.category,
    required this.imagePath,
    required this.hexColor,
    required this.colorName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'imagePath': imagePath,
        'hexColor': hexColor,
        'colorName': colorName,
      };

  factory ClosetItem.fromMap(Map<String, dynamic> map) {
    return ClosetItem(
      id: map['id'] as String,
      category: map['category'] as String,
      imagePath: map['imagePath'] as String,
      hexColor: map['hexColor'] as String,
      colorName: map['colorName'] as String,
    );
  }
}

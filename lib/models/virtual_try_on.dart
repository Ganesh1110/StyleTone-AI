enum GarmentType {
  blazer,
  dress,
  top,
  bottom,
  accessory;

  String get label {
    switch (this) {
      case GarmentType.blazer:
        return 'Blazer';
      case GarmentType.dress:
        return 'Dress';
      case GarmentType.top:
        return 'Top';
      case GarmentType.bottom:
        return 'Bottom';
      case GarmentType.accessory:
        return 'Accessory';
    }
  }

  String get iconPath {
    switch (this) {
      case GarmentType.blazer:
        return 'blazer_silhouette';
      case GarmentType.dress:
        return 'dress_silhouette';
      case GarmentType.top:
        return 'top_silhouette';
      case GarmentType.bottom:
        return 'bottom_silhouette';
      case GarmentType.accessory:
        return 'accessory_silhouette';
    }
  }
}

class TryOnPreset {
  final GarmentType type;
  final String label;
  final String hexColor;
  final bool isSelected;

  const TryOnPreset({
    required this.type,
    required this.label,
    required this.hexColor,
    this.isSelected = false,
  });

  TryOnPreset copyWith({bool? isSelected}) {
    return TryOnPreset(
      type: type,
      label: label,
      hexColor: hexColor,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

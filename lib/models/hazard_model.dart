class HazardItem {
  final String id;
  final String title;
  final String description;
  final String type;
  final double latitude;
  final double longitude;
  final String timestamp;

  HazardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory HazardItem.fromJson(Map<String, dynamic> json) {
    return HazardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Road Hazard',
      description: json['description'] ?? '',
      type: json['type'] ?? 'General',
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp,
      };
}

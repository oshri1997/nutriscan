class ScanEvent {
  final String id;
  final String userId;
  final String? imageUrl;
  final String aiResponse;
  final bool wasEdited;
  final DateTime createdAt;

  const ScanEvent({
    required this.id,
    required this.userId,
    this.imageUrl,
    required this.aiResponse,
    this.wasEdited = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'imageUrl': imageUrl,
        'aiResponse': aiResponse,
        'wasEdited': wasEdited ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScanEvent.fromMap(Map<String, dynamic> m) => ScanEvent(
        id: m['id'],
        userId: m['userId'],
        imageUrl: m['imageUrl'],
        aiResponse: m['aiResponse'] ?? '',
        wasEdited: m['wasEdited'] == 1,
        createdAt: DateTime.parse(m['createdAt']),
      );
}

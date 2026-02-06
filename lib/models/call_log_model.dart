class CallLogModel {
  final String id;
  final String callerId;
  final String callerPhone; // NEW
  final String receiverId;
  final String receiverPhone; // NEW
  final String type; // audio, video
  final String status; // missed, completed, rejected
  final DateTime startedAt;
  final int duration;

  CallLogModel({
    required this.id,
    required this.callerId,
    required this.callerPhone,
    required this.receiverId,
    required this.receiverPhone,
    required this.type,
    required this.status,
    required this.startedAt,
    required this.duration,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    // Robust DateTime parsing with fallback
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      try {
        return DateTime.parse(value.toString()).toLocal();
      } catch (e) {
        print('⚠️ Failed to parse DateTime: $value - Error: $e');
        return DateTime.now();
      }
    }

    return CallLogModel(
      id: json['_id'] ?? 'unknown',
      callerId: (json['from'] is Map ? json['from']['_id'] : json['from']) ?? 'unknown', // Handle populated vs unpopulated vs NULL
      callerPhone: json['callerPhone'] ?? '', 
      receiverId: (json['to'] is Map ? json['to']['_id'] : json['to']) ?? 'unknown',
      receiverPhone: json['receiverPhone'] ?? '',
      type: json['type'],
      status: json['status'],
      startedAt: parseDateTime(json['callTime'] ?? json['startedAt']),
      duration: json['duration'] ?? 0,
    );
  }
}

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
    return CallLogModel(
      id: json['_id'],
      callerId: json['from']['_id'] ?? json['from'], // Handle populated vs unpopulated
      callerPhone: json['callerPhone'] ?? '', 
      receiverId: json['to']['_id'] ?? json['to'],
      receiverPhone: json['receiverPhone'] ?? '',
      type: json['type'],
      status: json['status'],
      startedAt: json['callTime'] != null ? DateTime.parse(json['callTime']).toLocal() : (json['startedAt'] != null ? DateTime.parse(json['startedAt']).toLocal() : DateTime.now()),
      duration: json['duration'] ?? 0,
    );
  }
}

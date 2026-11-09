/// The reason an in-app notification was created.
enum AppNotificationType { reminder, overdue }

extension AppNotificationTypeInfo on AppNotificationType {
  String get value {
    switch (this) {
      case AppNotificationType.reminder:
        return 'reminder';
      case AppNotificationType.overdue:
        return 'overdue';
    }
  }

  static AppNotificationType fromValue(Object? value) {
    return AppNotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AppNotificationType.reminder,
    );
  }
}

/// A notification persisted in SQLite so it survives app restarts.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.taskId,
    required this.type,
    required this.title,
    required this.message,
    required this.dedupeKey,
    required this.eventAt,
    required this.createdAt,
    this.readAt,
    this.clearedAt,
  });

  final int id;
  final int? taskId;
  final AppNotificationType type;
  final String title;
  final String message;

  /// Unique key used to prevent the same notification from being saved twice.
  final String dedupeKey;

  /// When the notification became relevant (reminder or due time).
  final DateTime eventAt;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Set when the user clears the notification center. Cleared rows are kept
  /// so their dedupe key still prevents the same event from being recreated.
  final DateTime? clearedAt;

  bool get isRead => readAt != null;
  bool get isCleared => clearedAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final String eventAtValue = map['event_at'] as String;
    final String createdAtValue = map['created_at'] as String;

    return AppNotification(
      id: map['id'] as int,
      taskId: (map['task_id'] as num?)?.toInt(),
      type: AppNotificationTypeInfo.fromValue(map['type']),
      title: map['title'] as String,
      message: map['message'] as String? ?? '',
      dedupeKey: map['dedupe_key'] as String,
      eventAt: DateTime.parse(eventAtValue).toLocal(),
      createdAt: DateTime.parse(createdAtValue).toLocal(),
      readAt: _parseOptionalDate(map['read_at']),
      clearedAt: _parseOptionalDate(map['cleared_at']),
    );
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return null;
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'task_id': taskId,
      'type': type.value,
      'title': title,
      'message': message,
      'dedupe_key': dedupeKey,
      'event_at': eventAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'read_at': readAt?.toUtc().toIso8601String(),
      'cleared_at': clearedAt?.toUtc().toIso8601String(),
    };
  }

  AppNotification copyWith({
    int? id,
    Object? taskId = _unset,
    AppNotificationType? type,
    String? title,
    String? message,
    String? dedupeKey,
    DateTime? eventAt,
    DateTime? createdAt,
    Object? readAt = _unset,
    Object? clearedAt = _unset,
  }) {
    return AppNotification(
      id: id ?? this.id,
      taskId: identical(taskId, _unset) ? this.taskId : taskId as int?,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      eventAt: eventAt ?? this.eventAt,
      createdAt: createdAt ?? this.createdAt,
      readAt: identical(readAt, _unset) ? this.readAt : readAt as DateTime?,
      clearedAt: identical(clearedAt, _unset)
          ? this.clearedAt
          : clearedAt as DateTime?,
    );
  }

  static const Object _unset = Object();
}

import '../../data/database/app_database.dart';

class CalendarEventRequest {
  const CalendarEventRequest({
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.alarmOffset,
  });

  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final Duration? alarmOffset;

  @override
  bool operator ==(Object other) {
    return other is CalendarEventRequest &&
        other.title == title &&
        other.description == description &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.alarmOffset == alarmOffset;
  }

  @override
  int get hashCode {
    return Object.hash(title, description, startDate, endDate, alarmOffset);
  }

  @override
  String toString() {
    return 'CalendarEventRequest($title, $startDate, $endDate, $alarmOffset)';
  }
}

abstract class CalendarEventGateway {
  Future<void> requestCreateEvent(CalendarEventRequest request);
}

class NoopCalendarEventGateway implements CalendarEventGateway {
  const NoopCalendarEventGateway();

  @override
  Future<void> requestCreateEvent(CalendarEventRequest request) async {}
}

class CalendarEventService {
  const CalendarEventService(this._gateway);

  final CalendarEventGateway _gateway;

  Future<void> requestCreateEvent(LifeItem item) {
    final alarmOffset = _alarmOffsetFor(item);
    return _gateway.requestCreateEvent(
      CalendarEventRequest(
        title: item.title,
        description: item.description?.isEmpty == true
            ? null
            : item.description,
        startDate: item.dueTime,
        endDate: item.dueTime.add(const Duration(hours: 1)),
        alarmOffset: alarmOffset,
      ),
    );
  }

  Duration? _alarmOffsetFor(LifeItem item) {
    final remindTime = item.remindTime;
    if (remindTime == null || !remindTime.isBefore(item.dueTime)) {
      return null;
    }
    return item.dueTime.difference(remindTime);
  }
}

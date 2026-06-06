import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/calendar/calendar_event_service.dart';
import 'package:record_everything/data/database/app_database.dart';

void main() {
  group('CalendarEventService', () {
    test('requests native calendar event creation for a life item', () async {
      final gateway = FakeCalendarEventGateway();
      final service = CalendarEventService(gateway);
      final item = LifeItem(
        id: 42,
        title: '办理护照',
        description: '带照片',
        categoryId: null,
        itemType: 'expiration',
        amount: null,
        amountType: 'none',
        dueTime: DateTime(2026, 6, 6, 15, 30),
        remindTime: DateTime(2026, 6, 6, 9),
        repeatRule: null,
        status: 'pending',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await service.requestCreateEvent(item);

      expect(gateway.requests, [
        CalendarEventRequest(
          title: '办理护照',
          description: '带照片',
          startDate: DateTime(2026, 6, 6, 15, 30),
          endDate: DateTime(2026, 6, 6, 16, 30),
          alarmOffset: const Duration(hours: 6, minutes: 30),
        ),
      ]);
    });
  });
}

class FakeCalendarEventGateway implements CalendarEventGateway {
  final requests = <CalendarEventRequest>[];

  @override
  Future<void> requestCreateEvent(CalendarEventRequest request) async {
    requests.add(request);
  }
}

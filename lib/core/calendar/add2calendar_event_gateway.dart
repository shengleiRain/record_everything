import 'package:add_2_calendar/add_2_calendar.dart';

import 'calendar_event_service.dart';

class Add2CalendarEventGateway implements CalendarEventGateway {
  const Add2CalendarEventGateway();

  @override
  Future<void> requestCreateEvent(CalendarEventRequest request) async {
    await Add2Calendar.addEvent2Cal(
      Event(
        title: request.title,
        description: request.description,
        startDate: request.startDate,
        endDate: request.endDate,
        iosParams: IOSParams(reminder: request.alarmOffset),
      ),
    );
  }
}

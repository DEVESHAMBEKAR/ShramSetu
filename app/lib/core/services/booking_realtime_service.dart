import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BookingRealtimeEventType {
  insert,
  update,
  delete,
  other,
}

class BookingRealtimeEvent {
  final BookingRealtimeEventType eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;
  final String? bookingId;

  const BookingRealtimeEvent({
    required this.eventType,
    required this.newRecord,
    required this.oldRecord,
    this.bookingId,
  });

  @override
  String toString() => 'BookingRealtimeEvent(type: $eventType, id: $bookingId)';
}

/// Dedicated Realtime service abstracting Supabase WebSocket subscriptions for bookings.
/// Ensures clean separation between the database connection and repository layer.
class BookingRealtimeService {
  final SupabaseClient _client;

  BookingRealtimeService(this._client);

  /// Streams raw booking change events filtered by [customerId], [workerId], or [bookingId].
  /// If no filter is specified, streams all booking changes (authorized by Admin RLS).
  Stream<BookingRealtimeEvent> streamBookingChanges({
    String? customerId,
    String? workerId,
    String? bookingId,
  }) {
    late StreamController<BookingRealtimeEvent> controller;
    RealtimeChannel? channel;

    // Construct deterministic, clear channel name
    final String channelName;
    PostgresChangeFilter? filter;

    if (bookingId != null && bookingId.isNotEmpty) {
      channelName = 'booking_${bookingId}_${DateTime.now().microsecondsSinceEpoch}';
      filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: bookingId,
      );
    } else if (customerId != null && customerId.isNotEmpty) {
      channelName = 'customer_bookings_${customerId}_${DateTime.now().microsecondsSinceEpoch}';
      filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: customerId,
      );
    } else if (workerId != null && workerId.isNotEmpty) {
      channelName = 'worker_bookings_${workerId}_${DateTime.now().microsecondsSinceEpoch}';
      filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'worker_id',
        value: workerId,
      );
    } else {
      channelName = 'admin_bookings_${DateTime.now().microsecondsSinceEpoch}';
      filter = null;
    }

    void onListen() {
      try {
        channel = _client.channel(channelName);
        channel!.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: filter,
          callback: (PostgresChangePayload payload) {
            BookingRealtimeEventType eventType;
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                eventType = BookingRealtimeEventType.insert;
                break;
              case PostgresChangeEvent.update:
                eventType = BookingRealtimeEventType.update;
                break;
              case PostgresChangeEvent.delete:
                eventType = BookingRealtimeEventType.delete;
                break;
              default:
                eventType = BookingRealtimeEventType.other;
                break;
            }

            final newRec = payload.newRecord;
            final oldRec = payload.oldRecord;
            final id = (newRec['id'] ?? oldRec['id'])?.toString();

            if (!controller.isClosed) {
              controller.add(BookingRealtimeEvent(
                eventType: eventType,
                newRecord: newRec,
                oldRecord: oldRec,
                bookingId: id,
              ));
            }
          },
        );

        channel!.subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Realtime channel $channelName error: $error');
          }
        });
      } catch (e) {
        debugPrint('Failed to subscribe to realtime channel $channelName: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    Future<void> onCancel() async {
      try {
        if (channel != null) {
          await _client.removeChannel(channel!);
          channel = null;
        }
      } catch (e) {
        debugPrint('Error removing realtime channel $channelName: $e');
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    controller = StreamController<BookingRealtimeEvent>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
    );

    return controller.stream;
  }
}

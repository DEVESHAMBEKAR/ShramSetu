import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/data/repositories/supabase_customer_repository.dart';

void main() {
  group('SupabaseCustomerRepository Date & Time Normalization Tests', () {
    test('normalizes direct ISO dates', () {
      expect(SupabaseCustomerRepository.normalizeScheduledDate('2026-10-03'), equals('2026-10-03'));
      expect(SupabaseCustomerRepository.normalizeScheduledDate('2025-12-25'), equals('2025-12-25'));
    });

    test('normalizes relative "Today, X Month"', () {
      final now = DateTime.now();
      final expected = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(SupabaseCustomerRepository.normalizeScheduledDate('Today, 3 Oct'), equals(expected));
      expect(SupabaseCustomerRepository.normalizeScheduledDate('Today'), equals(expected));
    });

    test('normalizes relative "Tomorrow, X Month"', () {
      final tom = DateTime.now().add(const Duration(days: 1));
      final expected = '${tom.year.toString().padLeft(4, '0')}-${tom.month.toString().padLeft(2, '0')}-${tom.day.toString().padLeft(2, '0')}';
      expect(SupabaseCustomerRepository.normalizeScheduledDate('Tomorrow, 4 Oct'), equals(expected));
      expect(SupabaseCustomerRepository.normalizeScheduledDate('tomorrow'), equals(expected));
    });

    test('normalizes weekday dates like "Mon, 5 Oct"', () {
      final year = DateTime.now().year;
      expect(SupabaseCustomerRepository.normalizeScheduledDate('Mon, 5 Oct'), equals('$year-10-05'));
      expect(SupabaseCustomerRepository.normalizeScheduledDate('Wed, 12 Nov'), equals('$year-11-12'));
    });

    test('normalizes 12-hour AM/PM times into strict HH:mm:ss format', () {
      expect(SupabaseCustomerRepository.normalizeScheduledTime('09:00 AM'), equals('09:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('10:00 AM'), equals('10:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('11:00 AM'), equals('11:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('12:00 PM'), equals('12:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('01:00 PM'), equals('13:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('02:00 PM'), equals('14:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('04:00 PM'), equals('16:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('12:00 AM'), equals('00:00:00'));
    });

    test('normalizes time ranges (extracts start time)', () {
      expect(SupabaseCustomerRepository.normalizeScheduledTime('11:30 AM - 12:30 PM'), equals('11:30:00'));
    });

    test('preserves already formatted HH:mm:ss times', () {
      expect(SupabaseCustomerRepository.normalizeScheduledTime('10:00:00'), equals('10:00:00'));
      expect(SupabaseCustomerRepository.normalizeScheduledTime('15:45:00'), equals('15:45:00'));
    });
  });
}

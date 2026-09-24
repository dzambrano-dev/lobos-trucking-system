import 'load_record.dart';

const dispatchGroupLabels = [
  'Needs attention',
  'Today',
  'Ready to invoice',
  'Upcoming',
  'History',
];

int dispatchGroup(LoadRecord load, Set<String> billed, DateTime now) {
  if (load.needsAttention) return 0;
  if (load.isComplete && !billed.contains(load.id)) return 2;
  if (load.isClosed) return 4;
  final date = load.scheduledPickupAt;
  if (date == null) return 0;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day.isBefore(today)) return 0;
  if (day == today) return 1;
  return 3;
}

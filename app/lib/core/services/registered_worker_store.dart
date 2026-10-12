import '../../features/customer/data/models/customer_models.dart';

/// In-memory store of real registered workers across the app lifecycle.
/// Retains actual artisan names, trades, and details so customer discovery
/// never displays dummy placeholder text like 'Verified Union Artisan'.
class RegisteredWorkerStore {
  static final Map<String, String> names = {};
  static final Map<String, String> trades = {};
  static final Map<String, String> phones = {};
  static final Map<String, Worker> workers = {};

  static void registerWorker({
    required String workerId,
    required String fullName,
    required String trade,
    String? phone,
    Worker? workerModel,
  }) {
    final cleanName = fullName.trim();
    if (cleanName.isNotEmpty && !cleanName.startsWith('User ') && !cleanName.startsWith('Artisan (')) {
      names[workerId] = cleanName;
    }
    if (trade.trim().isNotEmpty) {
      trades[workerId] = trade.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      phones[workerId] = phone.trim();
    }
    if (workerModel != null) {
      workers[workerId] = workerModel;
    }
  }

  static String? getName(String workerId) => names[workerId];
  static String? getTrade(String workerId) => trades[workerId];
  static String? getPhone(String workerId) => phones[workerId];
  static List<Worker> getRegisteredWorkers() => workers.values.toList();
}

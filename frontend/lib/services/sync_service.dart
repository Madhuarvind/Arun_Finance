
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'local_db_service.dart';

class SyncService {
  final ApiService _apiService = ApiService();
  final LocalDbService _localDb = LocalDbService();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> syncCollections() async {
    if (kIsWeb) return;

    debugPrint('=== SyncService: Checking for pending collections... ===');
    final pending = await _localDb.getPendingCollections();
    
    if (pending.isEmpty) {
      debugPrint('=== SyncService: No pending collections ===');
      return;
    }

    debugPrint('=== SyncService: Found ${pending.length} pending collections ===');
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      debugPrint('=== SyncService: No token, cannot sync ===');
      return;
    }

    for (var item in pending) {
      try {
        debugPrint('Syncing collection local_id: ${item['local_id']}...');
        final result = await _apiService.submitCollection(
          loanId: item['loan_id'],
          amount: item['amount'],
          paymentMode: item['payment_mode'],
          latitude: item['latitude'],
          longitude: item['longitude'],
          token: token,
        );

        if (result.containsKey('msg') && 
           (result['msg'] == 'collection_submitted_successfully' || 
            result['msg'].toString().contains('Duplicate'))) { // Handle duplicate gracefully
           
           await _localDb.markCollectionSynced(item['local_id']);
           debugPrint('Collection ${item['local_id']} synced successfully');
           
        } else {
           debugPrint('Collection ${item['local_id']} sync failed: ${result['msg']}');
        }
      } catch (e) {
        debugPrint('Collection ${item['local_id']} sync error: $e');
      }
    }
  }
}

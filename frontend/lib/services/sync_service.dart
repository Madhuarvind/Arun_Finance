import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'local_db_service.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static const String syncTaskName = "com.vasooldrive.syncTask";
  final ApiService _apiService = ApiService();
  final LocalDbService _localDb = LocalDbService();
  final _storage = const FlutterSecureStorage();

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      final syncService = SyncService();
      await syncService.performSync();
      return true;
    });
  }

  Future<void> init() async {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    
    // Listen for connectivity changes to trigger immediate sync
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        performSync();
      }
    });

    // Schedule periodic sync every 15 mins
    Workmanager().registerPeriodicTask(
      "1",
      syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  Future<void> performSync() async {
    debugPrint("=== STARTING SYNC PROCESS ===");
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    // 1. Sync Customers
    final pendingCustomers = await _localDb.getPendingCustomers();
    for (var cust in pendingCustomers) {
      try {
        final result = await _apiService.createCustomer(cust, token);
        if (result['id'] != null) {
          await _localDb.updateCustomerSyncStatus(
            int.parse(cust['local_id']), 
            result['id'], 
            result['customer_id']
          );
        }
      } catch (e) {
        debugPrint("Sync Customer Error: $e");
      }
    }

    // 2. Sync Loans
    final pendingLoans = await _localDb.getPendingLoans();
    for (var loan in pendingLoans) {
      try {
        final result = await _apiService.createLoan(loan, token);
        if (result['id'] != null) {
          await _localDb.markLoanSynced(
            loan['local_id'], 
            result['id'], 
            result['loan_id']
          );
        }
      } catch (e) {
         debugPrint("Sync Loan Error: $e");
      }
    }

    // 3. Sync Collections
    final pendingCollections = await _localDb.getPendingCollections();
    for (var col in pendingCollections) {
      try {
        final result = await _apiService.submitCollection(
          loanId: col['loan_id'],
          amount: col['amount'].toDouble(),
          paymentMode: col['payment_mode'],
          token: token,
          latitude: col['latitude'],
          longitude: col['longitude']
        );
        if (result['msg']?.contains('success') ?? false) {
          await _localDb.markCollectionSynced(col['local_id']);
        }
      } catch (e) {
        debugPrint("Sync Collection Error: $e");
      }
    }
    
    debugPrint("=== SYNC PROCESS COMPLETED ===");
  }
}

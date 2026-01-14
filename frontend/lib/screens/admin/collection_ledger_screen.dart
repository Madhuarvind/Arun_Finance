import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class CollectionLedgerScreen extends StatefulWidget {
  const CollectionLedgerScreen({super.key});

  @override
  State<CollectionLedgerScreen> createState() => _CollectionLedgerScreenState();
}

class _CollectionLedgerScreenState extends State<CollectionLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  List<dynamic> _logs = [];
  List<dynamic> _targets = [];
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  Future<void> _initialize() async {
    _token = await _apiService.getToken();
    if (_token != null) {
      await _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final logData = await _apiService.getDailyReport(
        _token!, 
        startDate: start.toIsoformatString(), 
        endDate: end.toIsoformatString()
      );
      final targetData = await _apiService.getWorkTargets(_token!);
      
      if (mounted) {
        setState(() {
          _logs = logData['report'] ?? [];
          _targets = targetData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching ledger data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Collection Ledger', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: "Collection Log"),
            Tab(text: "Today's Work"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildLogTab(),
              _buildWorkTab(),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchData,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }

  Widget _buildLogTab() {
    if (_logs.isEmpty) return const Center(child: Text("No collections recorded today"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final collection = _logs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  collection['payment_mode'] == 'cash' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                  color: AppTheme.primaryColor,
                ),
                Text((collection['payment_mode']?.toString() ?? 'Unknown').toUpperCase(), style: const TextStyle(fontSize: 8)),
              ],
            ),
            title: Text(collection['customer_name']?.toString() ?? 'Unknown Name', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${collection['agent_name']?.toString() ?? 'Unknown Agent'} • ${collection['loan_id']?.toString() ?? 'N/A'}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${collection['amount']?.toString() ?? '0'}", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                Text(_formatTime(collection['time']?.toString() ?? ''), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkTab() {
    if (_targets.isEmpty) return const Center(child: Text("All targets for today completed!"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _targets.length,
      itemBuilder: (context, index) {
        final target = _targets[index];
        final bool isOverdue = target['is_overdue'] ?? false;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isOverdue ? Icons.priority_high : Icons.today, color: isOverdue ? Colors.red : Colors.blue, size: 20),
            ),
            title: Text(target['customer_name']?.toString() ?? 'Unknown Name', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${target['area']?.toString() ?? 'N/A'} • ${target['agent_name']?.toString() ?? 'Unknown Agent'}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${target['amount_due']?.toString() ?? '0'}", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(isOverdue ? "OVERDUE" : "DUE TODAY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOverdue ? Colors.red : Colors.blue)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return '';
    }
  }
}

extension DateTimeIso on DateTime {
  String toIsoformatString() {
    return toIso8601String().split('.').first;
  }
}

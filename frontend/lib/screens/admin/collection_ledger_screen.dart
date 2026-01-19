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
    _tabController.addListener(_handleTabChange);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
       _fetchData();
    }
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Collection Ledger', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: "Collection Log"),
            Tab(text: "Today's Work"),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLogTab(),
                _buildWorkTab(),
              ],
            ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchData,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }

  Widget _buildLogTab() {
    if (_logs.isEmpty) return Center(child: Text("No collections recorded today", style: GoogleFonts.outfit(color: Colors.white70)));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final collection = _logs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                collection['payment_mode'] == 'cash' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            title: Text(collection['customer_name']?.toString() ?? 'Unknown Name', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text(
              "${collection['agent_name']?.toString() ?? 'Unknown Agent'} • ${collection['loan_id']?.toString() ?? 'N/A'}",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${collection['amount']?.toString() ?? '0'}", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                Text(_formatTime(collection['time']?.toString() ?? ''), style: GoogleFonts.outfit(fontSize: 10, color: Colors.white30)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkTab() {
    if (_targets.isEmpty) return Center(child: Text("All targets for today completed!", style: GoogleFonts.outfit(color: Colors.white70)));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
      itemCount: _targets.length,
      itemBuilder: (context, index) {
        final target = _targets[index];
        final bool isOverdue = target['is_overdue'] ?? false;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isOverdue ? Icons.priority_high : Icons.today, color: isOverdue ? Colors.redAccent : Colors.blueAccent, size: 20),
            ),
            title: Text(target['customer_name']?.toString() ?? 'Unknown Name', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text(
              "${target['area']?.toString() ?? 'N/A'} • ${target['agent_name']?.toString() ?? 'Unknown Agent'}",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${target['amount_due']?.toString() ?? '0'}", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(
                  isOverdue ? "OVERDUE" : "DUE TODAY",
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isOverdue ? Colors.redAccent : Colors.blueAccent)
                ),
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

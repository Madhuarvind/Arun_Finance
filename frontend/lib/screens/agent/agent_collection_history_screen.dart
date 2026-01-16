import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class AgentCollectionHistoryScreen extends StatefulWidget {
  const AgentCollectionHistoryScreen({super.key});

  @override
  State<AgentCollectionHistoryScreen> createState() => _AgentCollectionHistoryScreenState();
}

class _AgentCollectionHistoryScreenState extends State<AgentCollectionHistoryScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final data = await _apiService.getCollectionHistory(token);
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('My Collection History', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _history.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return _buildHistoryCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          ),
          const SizedBox(height: 24),
          Text('NO COLLECTIONS RECORDED YET', style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c) {
    final status = (c['status'] ?? 'pending').toString().toLowerCase();
    Color statusColor = status == 'approved' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.red);
    
    final dateStr = c['time'] ?? c['created_at'] ?? DateTime.now().toIso8601String();
    final date = DateTime.parse(dateStr).toLocal();
    final formattedDate = DateFormat('dd MMM, hh:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 24),
        ),
        title: Text(
          c['customer_name']?.toString() ?? 'Unknown',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${c['payment_mode']?.toString().toUpperCase()} • $formattedDate',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${c['amount']}',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
          ],
        ),
      ),
    );
  }
}

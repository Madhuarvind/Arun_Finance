import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';

class FinancialAnalyticsScreen extends StatefulWidget {
  // Analytical dashboard for administrators
  const FinancialAnalyticsScreen({super.key});

  @override
  State<FinancialAnalyticsScreen> createState() => _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getFinancialStats(token);
      if (mounted) {
        setState(() {
          _stats = result;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('financial_analytics'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Collection by Payment Mode'),
                        _buildModeDistributionChart(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Top Performing Agents'),
                        _buildAgentPerformanceList(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('TOTAL APPROVED', '₹ ${_stats?['total_approved'] ?? 0}', Icons.account_balance_wallet_rounded, Colors.blueAccent)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('TODAY TOTAL', '₹ ${_stats?['today_total'] ?? 0}', Icons.today_rounded, Colors.greenAccent)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1.5)),
    );
  }

  Widget _buildModeDistributionChart() {
    final modeData = _stats?['mode_distribution'] as Map<String, dynamic>? ?? {};
    if (modeData.isEmpty) {

      return const Center(child: Text('No data distribution available'));

    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: modeData.entries.map((e) {
            final color = e.key.toLowerCase() == 'cash' ? Colors.orangeAccent : Colors.indigoAccent;
            return PieChartSectionData(
              color: color.withValues(alpha: 0.8),
              value: (e.value as num).toDouble(),
              title: '${e.key.toUpperCase()}\n₹${e.value}',
              radius: 50,
              titleStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAgentPerformanceList() {
    final agents = List<dynamic>.from(_stats?['agent_performance'] ?? []);
    if (agents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05), 
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Center(child: Text('NO AGENT DATA AVAILABLE', style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 12))),
      );
    }

    return Column(
      children: agents.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(a['name'][0].toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(a['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
              Text('₹ ${a['total']}', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

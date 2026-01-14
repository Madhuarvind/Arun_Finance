import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceAnalyticsScreen extends StatefulWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  State<PerformanceAnalyticsScreen> createState() => _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState extends State<PerformanceAnalyticsScreen> {
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
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getPerformanceStats(token);
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(context.translate('performance_analytics'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context.translate('role_distribution')),
                  const SizedBox(height: 16),
                  _buildRoleDistributionChart(),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context.translate('biometric_adoption')),
                  const SizedBox(height: 16),
                  _buildBiometricAdoptionCard(),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context.translate('login_activity')),
                  const SizedBox(height: 16),
                  _buildLoginActivityChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
    );
  }

  Widget _buildRoleDistributionChart() {
    final dist = _stats?['role_distribution'] as Map<String, dynamic>? ?? {};
    final List<PieChartSectionData> sections = [];
    final colors = [AppTheme.primaryColor, Colors.blueAccent, Colors.purpleAccent, Colors.orange];
    int i = 0;

    dist.forEach((role, count) {
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        title: '$count',
        color: colors[i % colors.length],
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Expanded(child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: dist.entries.map((e) => _buildLegendItem(e.key, colors[dist.keys.toList().indexOf(e.key) % colors.length])).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBiometricAdoptionCard() {
    double rate = (_stats?['biometric_adoption'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Adoption Rate', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              Text('${rate.toStringAsFixed(1)}%', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 12,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Percentage of users who have registered face biometric', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLoginActivityChart() {
    final activity = List<Map<String, dynamic>>.from(_stats?['login_activity'] ?? []);
    if (activity.isEmpty) {

      return const SizedBox();

    }

    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 24, right: 24, bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: activity.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble())).toList(),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('performance_analytics'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
        titleStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
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
          Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildBiometricAdoptionCard() {
    double rate = (_stats?['biometric_adoption'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Adoption Rate', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${rate.toStringAsFixed(1)}%', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 12,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Text('Percentage of users who have registered face biometric', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) {
               if (val.toInt() >= 0 && val.toInt() < activity.length) {
                 final dt = DateTime.parse(activity[val.toInt()]['date']);
                 return Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text("${dt.day}/${dt.month}", style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10)),
                 );
               }
               return const Text('');
            })),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: activity.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble())).toList(),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: AppTheme.primaryColor, strokeWidth: 2, strokeColor: Colors.black),
              ),
              belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';

class RiskPredictionScreen extends StatefulWidget {
  const RiskPredictionScreen({super.key});

  @override
  State<RiskPredictionScreen> createState() => _RiskPredictionScreenState();
}

class _RiskPredictionScreenState extends State<RiskPredictionScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _aiInsights;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final results = await Future.wait([
          _apiService.getRiskDashboard(token),
          _apiService.getDashboardAIInsights(token),
        ]);
        
        if (mounted) {
          setState(() {
            _dashboardData = results[0];
            _aiInsights = results[1];
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching risk data: $e");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          context.translate('risk_predictions'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopInsightCard(),
                    const SizedBox(height: 24),
                    _buildRiskDistributionSection(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('AI Strategic Summaries'),
                    _buildAiSummariesList(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Priority Collection (High Risk)'),
                    _buildProblemLoansList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopInsightCard() {
    final status = _aiInsights?['ai_summaries'] != null && _aiInsights!['ai_summaries'].isNotEmpty
        ? "Action Required"
        : "System Healthy";
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.psychology_outlined, color: Colors.white, size: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "AI Neural Risk Analysis",
            style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "Real-time Probability Engine",
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskDistributionSection() {
    final high = _dashboardData?['high_risk_count'] ?? 0;
    final med = _dashboardData?['medium_risk_count'] ?? 0;
    final low = _dashboardData?['low_risk_count'] ?? 0;
    final total = _dashboardData?['total_active'] ?? 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatIndicator("High", high, Colors.redAccent),
              _buildStatIndicator("Med", med, Colors.orangeAccent),
              _buildStatIndicator("Low", low, Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: high.toDouble(), color: Colors.redAccent, title: '', radius: 50),
                  PieChartSectionData(value: med.toDouble(), color: Colors.orangeAccent, title: '', radius: 50),
                  PieChartSectionData(value: low.toDouble(), color: Colors.greenAccent, title: '', radius: 50),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Total Active Portfolio: $total Loans",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildAiSummariesList() {
    final summaries = List<String>.from(_aiInsights?['ai_summaries'] ?? []);
    if (summaries.isEmpty) {
      return _buildEmptyState("No critical AI alerts detected.");
    }

    return Column(
      children: summaries.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.indigo, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s,
                style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildProblemLoansList() {
    final loans = List<dynamic>.from(_aiInsights?['problem_loans'] ?? []);
    if (loans.isEmpty) {
      return _buildEmptyState("No defaulted loans in priority queue.");
    }

    return Column(
      children: loans.map((l) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l['customer'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Loan ID: ${l['loan_id']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹ ${l['pending']}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                Text("${l['missed']} Missed", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: Colors.green.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

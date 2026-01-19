import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AgentPerformanceScreen extends StatefulWidget {
  const AgentPerformanceScreen({super.key});

  @override
  State<AgentPerformanceScreen> createState() => _AgentPerformanceScreenState();
}

class _AgentPerformanceScreenState extends State<AgentPerformanceScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  Map<String, dynamic> _stats = {"collected": 0.0, "goal": 50000.0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = await _apiService.getAgentStats(token);
        if (mounted) {
          setState(() {
            if (data['collected'] != null) {
               _stats = data;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching performance stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double collected = double.tryParse(_stats['collected']?.toString() ?? '0') ?? 0.0;
    final double goal = double.tryParse(_stats['goal']?.toString() ?? '50000') ?? 50000.0;
    final double progress = (goal > 0 ? (collected / goal) : 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('My AI Performance', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildGoalCard(progress),
                  const SizedBox(height: 16),
                  _buildInsightCard(
                    "Collection Velocity",
                    "Your average collection speed is optimal. Try to cover the remaining ${(_stats['goal'] - _stats['collected']).toStringAsFixed(0)} INR this week.",
                    Icons.speed_rounded,
                    Colors.blue,
                  ),
                  const SizedBox(height: 32),
                  _buildStatsGrid(),
                ],
              ),
            ),
    );
  }

  Widget _buildGoalCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MONTHLY GOAL', style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              Text('₹${_stats['goal']}', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const Text('Achieved', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '₹${_stats['collected']} Collected',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMiniStat("Collections", "24", Icons.receipt_long_rounded, Colors.purple),
        _buildMiniStat("Success Rate", "98%", Icons.verified_user_rounded, Colors.teal),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          Text(label.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

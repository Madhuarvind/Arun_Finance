import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';

class OptimizationDashboard extends StatefulWidget {
  const OptimizationDashboard({super.key});

  @override
  State<OptimizationDashboard> createState() => _OptimizationDashboardState();
}

class _OptimizationDashboardState extends State<OptimizationDashboard> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  bool _isLoading = false;
  Map<String, dynamic>? _budgetSuggestion;
  List<dynamic>? _lastAssignments;

  Future<void> _runAutoAssignment() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.autoAssignWorkers(token, dryRun: true);
      debugPrint("Optimization Result: $result");
      if (mounted) {
        setState(() {
          _lastAssignments = result['assignments'];
          _isLoading = false;
        });
        if (_lastAssignments == null || _lastAssignments!.isEmpty) {
           String debugInfo = "";
           if (result['debug'] != null) {
             final d = result['debug'];
             debugInfo = "\n(Workers: ${d['workers_found']}, Custs: ${d['customers_found']}, Filter: ${d['area_filter']})";
           }
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No customers available for auto-assignment.$debugInfo")));
        } else {
           _showAssignmentPreview();
        }
      }
    }
  }

  Future<void> _fetchBudgetSuggestion() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getBudgetSuggestion(token);
      debugPrint("Budget Suggestion: $result");
      if (mounted) {
        setState(() {
          _budgetSuggestion = result['suggestions'];
          _isLoading = false;
        });
        if (_budgetSuggestion == null || _budgetSuggestion!.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No area data found for budget suggestions.")));
        }
      }
    }
  }

  Future<void> _applyAssignments() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.autoAssignWorkers(token, dryRun: false);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['msg'] == 'optimization_complete' ? 'Assignments Applied Successfully' : 'Failed to apply assignments')),
        );
      }
    }
  }

  void _showAssignmentPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text("Optimization Preview", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("AI suggesting optimal worker-customer distribution.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _lastAssignments?.length ?? 0,
                itemBuilder: (context, index) {
                  final assign = _lastAssignments![index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text("Worker ID: ${assign['worker_id']}"),
                    subtitle: Text("${assign['count']} customers assigned"),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyAssignments();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Apply Assignments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Resource Optimization", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightCard(),
                const SizedBox(height: 32),
                _buildSectionTitle("AI Mathematical Engines"),
                const SizedBox(height: 16),
                _buildActionTile(
                  "Optimal Workload Distribution",
                  "Auto-assign customers to field agents using Integer Programming.",
                  Icons.group_add_rounded,
                  Colors.blue,
                  _runAutoAssignment
                ),
                const SizedBox(height: 16),
                _buildActionTile(
                  "Capital Allocation Suggestion",
                  "Optimize loan disbursement budget across areas (Linear Programming).",
                  Icons.point_of_sale_rounded,
                  Colors.green,
                  _fetchBudgetSuggestion
                ),
                if (_budgetSuggestion != null) ...[
                   const SizedBox(height: 32),
                   _buildSectionTitle("Budget Suggestions"),
                   const SizedBox(height: 16),
                   _buildBudgetList(),
                ]
              ],
            ),
          ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(
            "Operations Optimizer",
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Maximize ROI and collection efficiency using advanced constraints.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetList() {
    return Column(
      children: _budgetSuggestion!.entries.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.green, radius: 4),
            const SizedBox(width: 12),
            Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text("₹ ${e.value.toStringAsFixed(2)}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 1.2));
  }
}

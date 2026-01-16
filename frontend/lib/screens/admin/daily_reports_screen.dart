import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:printing/printing.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class DailyReportsScreen extends StatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  State<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends State<DailyReportsScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final data = await _apiService.getDailyReportsArchive(token);
      setState(() {
        _reports = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Daily Accounting Archive", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchReports,
          ),
        ],
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
            : _reports.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return _buildReportCard(report);
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
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text("No reports found", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          Text("Reports are generated automatically at end of day.", 
            style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReportCard(dynamic report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white54,
          title: Text(report['date'] ?? 'Unknown Date', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text("Total: ₹${report['total']}", style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("Morning", "₹${report['morning']}", Colors.orangeAccent),
                      _buildStatItem("Evening", "₹${report['evening']}", Colors.indigoAccent),
                    ],
                  ),
                  Divider(height: 24, color: Colors.white.withValues(alpha: 0.1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("Cash", "₹${report['cash']}", Colors.blueGrey),
                      _buildStatItem("UPI", "₹${report['upi']}", Colors.deepPurpleAccent),
                    ],
                  ),
                  Divider(height: 24, color: Colors.white.withValues(alpha: 0.1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("Principal", "₹${report['principal']}", Colors.tealAccent),
                      _buildStatItem("Interest", "₹${report['interest']}", Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text("${report['count']} Collections Recorded", style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadPDF(report['id'], report['date']),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.black),
                      label: Text("VIEW PDF REPORT", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPDF(int reportId, String date) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating PDF..."), duration: Duration(seconds: 1)),
    );

    final pdfBytes = await _apiService.getDailyReportPDF(reportId, token);
    
    if (pdfBytes != null) {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Report_$date',
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to download PDF"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

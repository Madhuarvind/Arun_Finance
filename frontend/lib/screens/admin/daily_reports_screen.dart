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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Daily Accounting Archive", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _reports.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return _buildReportCard(report);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No reports found", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Text("Reports are generated automatically at end of day.", 
            style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReportCard(dynamic report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        title: Text(report['date'] ?? 'Unknown Date', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: Text("Total: ₹${report['total']}", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem("Morning", "₹${report['morning']}", Colors.orange),
                    _buildStatItem("Evening", "₹${report['evening']}", Colors.indigo),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem("Cash", "₹${report['cash']}", Colors.blueGrey),
                    _buildStatItem("UPI", "₹${report['upi']}", Colors.deepPurple),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem("Principal", "₹${report['principal']}", Colors.teal),
                    _buildStatItem("Interest", "₹${report['interest']}", Colors.amber[800]!),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text("${report['count']} Collections Recorded", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadPDF(report['id'], report['date']),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text("VIEW PDF REPORT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[900],
                      foregroundColor: Colors.white,
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

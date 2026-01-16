import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'package:intl/intl.dart';

class PublicPassbookScreen extends StatefulWidget {
  final String token;
  const PublicPassbookScreen({super.key, required this.token});

  @override
  State<PublicPassbookScreen> createState() => _PublicPassbookScreenState();
}

class _PublicPassbookScreenState extends State<PublicPassbookScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _passbook;

  @override
  void initState() {
    super.initState();
    _fetchPassbook();
  }

  Future<void> _fetchPassbook() async {
    final res = await _apiService.getPublicPassbook(widget.token);
    if (mounted) {
      setState(() {
        if (res.containsKey('customer_name')) {
          _passbook = res;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Digital Passbook", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            : _passbook == null
              ? _buildErrorView()
              : _buildPassbookView(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            Text(
              "Passbook Link Invalid", 
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
            ),
            const SizedBox(height: 8),
            Text(
              "The link might be expired or incorrect.",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context), 
              child: const Text("CLOSE")
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassbookView() {
    final loan = _passbook!['active_loan'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(DateTime.now()),
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _passbook!['customer_name'] ?? 'Customer', 
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)
                ),
                Text(
                  _passbook!['customer_id'] ?? 'ID: Unknown', 
                  style: GoogleFonts.outfit(color: Colors.black54, fontSize: 14)
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          Text(
            "ACTIVE LOAN SUMMARY", 
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white54, fontSize: 12)
          ),
          const SizedBox(height: 16),
          
          if (loan == null)
            _buildNoLoanCard()
          else
            _buildLoanCard(loan),
            
          const SizedBox(height: 48),
          Center(
            child: Text(
              "Powered by AK Finserv Digital Systems",
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLoanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text(
            "No active loans found for this profile.", 
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildDetailRow("Loan ID", loan['loan_id'] ?? 'N/A'),
          const Divider(height: 32, color: Colors.white10),
          _buildDetailRow("Loan Amount", "₹${loan['principal']}", isBold: true, valueColor: Colors.white),
          const SizedBox(height: 16),
          _buildDetailRow("Pending Balance", "₹${loan['pending']}", valueColor: Colors.redAccent, isBold: true, valueSize: 20),
          const SizedBox(height: 16),
          _buildDetailRow("Tenure", loan['tenure'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor, double valueSize = 16}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
        Text(
          value, 
          style: GoogleFonts.outfit(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: valueSize,
            color: valueColor ?? Colors.white70
          )
        ),
      ],
    );
  }
}

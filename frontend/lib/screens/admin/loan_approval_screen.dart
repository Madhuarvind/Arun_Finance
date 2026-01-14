import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';

class LoanApprovalScreen extends StatefulWidget {
  const LoanApprovalScreen({super.key});

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> {
  final _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _pendingLoans = [];
  List<dynamic> _historyLoans = [];
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
      final pending = await _apiService.getLoans(status: 'created', token: token);
      final all = await _apiService.getLoans(token: token);
      setState(() {
        _pendingLoans = pending;
        _historyLoans = all.where((l) => l['status'] != 'created').toList();
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text("Loan Approvals", style: GoogleFonts.outfit(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "PENDING"),
              Tab(text: "HISTORY"),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: TabBarView(
          children: [
            _buildList(_pendingLoans, "No pending loans"),
            _buildList(_historyLoans, "No loan history"),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> loans, String emptyMsg) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (loans.isEmpty) return _buildEmptyState(emptyMsg);
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return _buildLoanCard(loan);
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(msg, style: GoogleFonts.outfit(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoanCard(dynamic loan) {
    final status = (loan['status'] ?? 'N/A').toString().toUpperCase();
    final statusColor = status == 'CREATED' ? Colors.orange : status == 'APPROVED' ? Colors.green : Colors.blue;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loan['loan_id'] ?? "Draft", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(status, style: GoogleFonts.outfit(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(),
            _infoRow(Icons.person, "Customer", loan['customer_name'] ?? "Unknown"),
            _infoRow(Icons.currency_rupee, "Amount", "₹${loan['principal_amount'] ?? 0}"),
            _infoRow(Icons.percent, "Interest", "${loan['interest_rate'] ?? 0}% (${loan['interest_type'] ?? 'flat'})"),
            _infoRow(Icons.calendar_month, "Tenure", "${loan['tenure'] ?? 0} ${loan['tenure_unit'] ?? 'days'}"),
            if (loan['status'] == 'created') ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {}, // TODO: Reject
                      child: const Text("Reject"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () => _approveAction(loan),
                      child: const Text("Approve"),
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text("$label:", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 5),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  void _approveAction(dynamic loan) async {
    // Show Date Picker for Start Date
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.approveLoan(loan['id'], {'start_date': picked.toIsoformat()}, token);
        if (mounted) {
          if (result.containsKey('msg')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan Approved Successfully"), backgroundColor: Colors.green));
            _fetchData();
          }
        }
      }
    }
  }
}

extension DateIso on DateTime {
  String toIsoformat() => toIso8601String();
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EMIScheduleScreen extends StatefulWidget {
  final int loanId;
  const EMIScheduleScreen({super.key, required this.loanId});

  @override
  State<EMIScheduleScreen> createState() => _EMIScheduleScreenState();
}

class _EMIScheduleScreenState extends State<EMIScheduleScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _schedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final loanData = await _apiService.getLoanDetails(widget.loanId, token);
        if (mounted) {
          setState(() {
            _schedule = loanData['emi_schedule'] ?? [];
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('EMI Schedule', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedule.isEmpty
              ? const Center(child: Text("No schedule available"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _schedule.length,
                  itemBuilder: (context, index) {
                    final item = _schedule[index];
                    final bool isPaid = item['status'] == 'paid';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                          child: Text("${item['emi_no']}", style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                        title: Text("₹${item['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Due: ${item['due_date']}"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['status'].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final token = await _apiService.getToken();
    if (token != null) {
      final result = await _apiService.getAuditLogs(token);
      setState(() {
        _logs = result;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'success') {
      return Colors.greenAccent;
    }
    if (status.startsWith('failed')) {
      return Colors.redAccent;
    }
    return Colors.orangeAccent;
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'success': return context.translate('success');
      case 'failed_wrong_pin': return context.translate('invalid_pin');
      case 'failed_device_mismatch': return context.translate('device_bound');
      case 'failed': return context.translate('failure');
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              context.translate('audit_logs'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchLogs,
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
            child: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _logs.isEmpty
                      ? Center(
                          child: Text(
                            context.translate('no_logs'),
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final DateTime time = DateTime.parse(log['time']);
                            final String formattedTime = DateFormat('dd MMM • hh:mm a').format(time.toLocal());
                            final bool isSuccess = log['status'] == 'success';
                            final statusColor = _getStatusColor(log['status']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                isThreeLine: true,
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSuccess ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log['user_name']?.toString() ?? 'Unknown User',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      formattedTime,
                                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      _getStatusLabel(log['status']?.toString() ?? 'unknown').toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: statusColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.white24),
                                        const SizedBox(width: 4),
                                        Text(
                                          log['mobile']?.toString() ?? 'N/A',
                                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.fingerprint_rounded, size: 14, color: Colors.white24),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            log['device']?.toString() ?? 'Unknown Device',
                                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        );
      },
    );
  }
}

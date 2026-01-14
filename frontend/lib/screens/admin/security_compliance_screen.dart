import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';

class SecurityComplianceScreen extends StatefulWidget {
  const SecurityComplianceScreen({super.key});

  @override
  State<SecurityComplianceScreen> createState() => _SecurityComplianceScreenState();
}

class _SecurityComplianceScreenState extends State<SecurityComplianceScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  Map<String, dynamic>? _abuseFlags;
  Map<String, dynamic>? _tamperAlerts;
  List<dynamic> _deviceAlerts = [];
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
      final flags = await _apiService.getSecurityFlags(token);
      final tamper = await _apiService.getTamperDetection(token);
      final devices = await _apiService.getDeviceMonitoring(token);
      
      if (mounted) {
        setState(() {
          _abuseFlags = flags;
          _tamperAlerts = tamper;
          _deviceAlerts = devices;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportAudit() async {
    final url = Uri.parse(_apiService.getAuditExportUrl());
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export audit logs.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(context.translate('security_compliance_title'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppTheme.primaryColor),
            onPressed: _exportAudit,
            tooltip: "Export CSV",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context.translate('data_integrity'), Icons.shield_outlined),
                    _buildTamperCard(),
                    const SizedBox(height: 30),
                    _buildSectionHeader(context.translate('role_abuse'), Icons.gpp_maybe_outlined),
                    _buildAbuseSection(),
                    const SizedBox(height: 30),
                    _buildSectionHeader(context.translate('device_monitoring'), Icons.devices_other_rounded),
                    _buildDeviceSection(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/admin/master_settings'),
                        icon: const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryColor),
                        label: Text(context.translate('system_configuration'), style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildTamperCard() {
    final status = _tamperAlerts?['status'] ?? 'secure';
    final alerts = List<dynamic>.from(_tamperAlerts?['alerts'] ?? []);
    final isSafe = status == 'secure';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSafe ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (isSafe ? Colors.green : Colors.red).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isSafe ? Icons.verified_user_rounded : Icons.report_problem_rounded, color: isSafe ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isSafe ? "SYSTEM INTEGRITY VERIFIED" : "TAMPER ALERT DETECTED", 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isSafe ? Colors.green : Colors.red, fontSize: 13)),
                  Text("Cross-checked ${_tamperAlerts?['checked_count'] ?? 0} active loans", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              )
            ],
          ),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...alerts.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text("• ${a['customer']} (Loan ${a['loan_id']}): ${a['reason']}", style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
            ))
          ]
        ],
      ),
    );
  }

  Widget _buildAbuseSection() {
    final flags = List<dynamic>.from(_abuseFlags?['flags'] ?? []);
    
    if (flags.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text("No unusual role activity detected.", style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }
    
    return Column(
      children: flags.map((f) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${f['user']} - ${f['type']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(f['warning'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Text("${f['action_count']} acts", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildDeviceSection() {
    if (_deviceAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text("All device logins appear legitimate.", style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }

    return Column(
      children: _deviceAlerts.map((d) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.phonelink_lock_rounded, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['user'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(d['risk'], style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text("${d['device_count']} Devices", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
          ],
        ),
      )).toList(),
    );
  }
}

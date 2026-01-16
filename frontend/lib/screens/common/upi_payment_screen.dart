import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UPIPaymentScreen extends StatefulWidget {
  final double amount;
  final String customerName;
  final String loanId;

  const UPIPaymentScreen({
    super.key,
    required this.amount,
    required this.customerName,
    required this.loanId,
  });

  @override
  State<UPIPaymentScreen> createState() => _UPIPaymentScreenState();
}

class _UPIPaymentScreenState extends State<UPIPaymentScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  String _upiId = "arun.finance@okaxis"; // Default fallback
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUPIConfig();
  }

  Future<void> _loadUPIConfig() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final settings = await _apiService.getSystemSettings(token);
      if (mounted) {
        setState(() {
          _upiId = settings['upi_id'] ?? "arun.finance@okaxis";
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateUPILink() {
    // Standard UPI URI format: upi://pay?pa=VPA&pn=NAME&am=AMOUNT&tn=NOTE&cu=CURRENCY
    final String pa = _upiId;
    final String pn = "ARUN FINANCE";
    final String am = widget.amount.toStringAsFixed(2);
    final String tn = "Collection ${widget.loanId}";
    
    return "upi://pay?pa=$pa&pn=${Uri.encodeComponent(pn)}&am=$am&tn=${Uri.encodeComponent(tn)}&cu=INR";
  }

  Future<void> _launchUPIApp() async {
    final url = Uri.parse(_generateUPILink());
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('no_upi_app_found'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final upiUrl = _generateUPILink();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('upi_payment_title'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.customerName,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "LOAN ID: ${widget.loanId}",
                            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: QrImageView(
                              data: upiUrl,
                              version: QrVersions.auto,
                              size: 200.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "₹${widget.amount.toStringAsFixed(2)}",
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.translate('scan_any_upi_hint'),
                            style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        context.translate('pay_via_apps_hint'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                          onPressed: _launchUPIApp,
                          icon: const Icon(Icons.account_balance_wallet_rounded),
                          label: Text(
                            context.translate('pay_via_installed_apps'),
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

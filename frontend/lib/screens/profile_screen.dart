import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import '../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getMyProfile(token);
      if (mounted) {
        setState(() {
          _profile = result;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('my_profile'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white70),
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
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(top: kToolbarHeight + 40, left: 24, right: 24, bottom: 24),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 32),
                    _buildQRCard(),
                    const SizedBox(height: 32),
                    _buildInfoCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: const Icon(Icons.person_rounded, size: 50, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          _profile?['name']?.toString().toUpperCase() ?? '',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          _profile?['role']?.toString().toUpperCase() ?? '',
          style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildQRCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Text(
            "USER IDENTIFICATION",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white24, letterSpacing: 1.5),
          ),
          const SizedBox(height: 24),
          if (_profile?['qr_token'] != null)
            QrImageView(
              data: _profile!['qr_token'],
              version: QrVersions.auto,
              size: 200,
              gapless: false,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.white,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.qr_code_rounded, size: 200, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            (_profile?['qr_token'] ?? 'No Token Available').toUpperCase(),
            style: GoogleFonts.outfit(fontSize: 10, color: Colors.white12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildInfoTile(Icons.phone_android_rounded, context.translate('mobile_number'), _profile?['mobile_number'] ?? ''),
          const Divider(height: 1, color: Colors.white10),
          _buildInfoTile(Icons.map_rounded, context.translate('area'), _profile?['area'] ?? context.translate('not_assigned')),
          const Divider(height: 1, color: Colors.white10),
          _buildInfoTile(Icons.history_rounded, 'Last Login', _profile?['last_login']?.toString().substring(0, 10) ?? 'Never'),
          const Divider(height: 1, color: Colors.white10),
          _buildInfoTile(
            Icons.fingerprint_rounded, 
            context.translate('biometric_status'), 
            _profile?['has_biometric'] == true ? context.translate('active') : context.translate('inactive'),
            color: _profile?['has_biometric'] == true ? Colors.green : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {Color? color}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color ?? AppTheme.primaryColor, size: 20),
      ),
      title: Text(label.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      subtitle: Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(context.translate('my_profile'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.person_rounded, size: 50, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          _profile?['name'] ?? '',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          _profile?['role']?.toString().toUpperCase() ?? '',
          style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildQRCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(
            context.translate('user_qr_identification'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 20),
          if (_profile?['qr_token'] != null)
            QrImageView(
              data: _profile!['qr_token'],
              version: QrVersions.auto,
              size: 200,
              gapless: false,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            )
          else
            const Icon(Icons.qr_code_rounded, size: 200, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _profile?['qr_token'] ?? 'No Token Available',
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          _buildInfoTile(Icons.phone_rounded, context.translate('mobile_number'), _profile?['mobile_number'] ?? ''),
          const Divider(height: 1),
          _buildInfoTile(Icons.map_rounded, context.translate('area'), _profile?['area'] ?? context.translate('not_assigned')),
          const Divider(height: 1),
          _buildInfoTile(Icons.history_rounded, 'Last Login', _profile?['last_login']?.toString().substring(0, 10) ?? 'Never'),
          const Divider(height: 1),
          _buildInfoTile(
            Icons.fingerprint_rounded, 
            context.translate('biometric_status'), 
            _profile?['has_biometric'] == true ? context.translate('active') : context.translate('inactive'),
            color: _profile?['has_biometric'] == true ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {Color? color}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color ?? AppTheme.primaryColor, size: 20),
      ),
      title: Text(label, style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13)),
      subtitle: Text(value, style: GoogleFonts.outfit(color: AppTheme.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

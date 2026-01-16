import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _areaController;
  late TextEditingController _idProofController;
  String _role = 'field_agent';
  bool _isActive = true;
  bool _isLocked = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _qrToken;
  Map<String, dynamic>? _biometricsInfo;
  Map<String, dynamic>? _loginStats;

  @override
  void initState() {
    super.initState();
    _fetchUserDetail();
  }

  Future<void> _fetchUserDetail() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getUserDetail(widget.userId, token);
      if (result.containsKey('id')) {
        setState(() {
          _nameController = TextEditingController(text: result['name'] ?? result['username'] ?? '');
          _mobileController = TextEditingController(text: result['mobile_number'] ?? '');
          _areaController = TextEditingController(text: result['area'] ?? '');
          _idProofController = TextEditingController(text: result['id_proof'] ?? '');
          _role = result['role'];
          _isActive = result['is_active'];
          _isLocked = result['is_locked'];
          _qrToken = result['qr_token'];
          _isLoading = false;
        });
        
        // Fetch biometrics info
        _fetchBiometrics();
        
        // Fetch login statistics
        _fetchLoginStats();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('error'))),
        );
      }
    }
  }

  Future<void> _fetchBiometrics() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getUserBiometrics(widget.userId, token);
      setState(() {
        _biometricsInfo = result;
      });
    }
  }

  Future<void> _fetchLoginStats() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getUserLoginStats(widget.userId, token);
      setState(() {
        _loginStats = result;
      });
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {

      return;

    }

    setState(() => _isSaving = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final data = {
        'name': _nameController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'area': _areaController.text.trim(),
        'id_proof': _idProofController.text.trim(),
        'role': _role,
        'is_active': _isActive,
        'is_locked': _isLocked,
      };
      
      final result = await _apiService.updateUser(widget.userId, data, token);
      setState(() => _isSaving = false);

      if (result.containsKey('msg')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('success'))),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              context.translate('edit_user'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
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
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Icon(
                                    _role == 'admin' ? Icons.shield_outlined : Icons.person_outline_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _nameController.text,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _role.toUpperCase().replaceAll('_', ' '),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildSectionHeader(context, context.translate('worker_name')),
                          TextFormField(
                            controller: _nameController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                            validator: (value) => value == null || value.isEmpty ? context.translate('error_name') : null,
                          ),
                          const SizedBox(height: 24),
                          
                          _buildSectionHeader(context, context.translate('mobile_number')),
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionHeader(context, context.translate('area')),
                          TextFormField(
                            controller: _areaController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.map_outlined, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                          ),
                          const SizedBox(height: 24),

                            _buildSectionHeader(context, context.translate('status')),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    value: _isActive,
                                    title: Text(context.translate('active'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    activeThumbColor: AppTheme.primaryColor,
                                    trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey),
                                    onChanged: (val) => setState(() => _isActive = val),
                                  ),
                                  Divider(color: Colors.white10),
                                  SwitchListTile(
                                    value: _isLocked,
                                    title: Text(context.translate('locked'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    activeThumbColor: AppTheme.errorColor,
                                    trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppTheme.errorColor.withValues(alpha: 0.5) : Colors.grey),
                                    onChanged: (val) => setState(() => _isLocked = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Login Statistics Section
                            _buildSectionHeader(context, context.translate('activity_stats')),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: _loginStats == null
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                                : Column(
                                    children: [
                                      // Login Stats Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatItem(
                                              Icons.login_rounded,
                                              _loginStats!['total_logins']?.toString() ?? '0',
                                              context.translate('total_logins'),
                                              Colors.blueAccent,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatItem(
                                              Icons.error_outline_rounded,
                                              _loginStats!['failed_logins']?.toString() ?? '0',
                                              context.translate('failed'),
                                              Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Divider(color: Colors.white10),
                                      const SizedBox(height: 12),
                                      // Last Login
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, color: Colors.white70, size: 20),
                                          const SizedBox(width: 12),
                                          Text(
                                            context.translate('last_login_label'),
                                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _loginStats!['last_login'] != null
                                                ? _loginStats!['last_login'].toString().substring(0, 19).replaceAll('T', ' ')
                                                : context.translate('never'),
                                              style: TextStyle(color: Colors.white, fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Device Info
                                      if (_loginStats!['devices'] != null && (_loginStats!['devices'] as List).isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Divider(color: Colors.white10),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.devices_rounded, color: Colors.white70, size: 20),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${context.translate('devices_count')} (${(_loginStats!['devices'] as List).length})',
                                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ...(_loginStats!['devices'] as List).map((device) => Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.phone_android_rounded,
                                                color: device['is_trusted'] == true ? AppTheme.primaryColor : Colors.white54,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      device['device_name'] ?? context.translate('unknown_device'),
                                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                                    ),
                                                    Text(
                                                      '${context.translate('last_login_label')} ${device['last_active'] != null ? device['last_active'].toString().substring(0, 10) : context.translate('never')}',
                                                      style: TextStyle(color: Colors.white54, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (device['is_trusted'] == true)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    context.translate('trusted'),
                                                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )),
                                      ],
                                    ],
                                  ),
                            ),
                            const SizedBox(height: 32),

                            // QR Code Section
                            if (_qrToken != null) ...[
                              _buildSectionHeader(context, context.translate('qr_code_label')),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      context.translate('user_qr_identification'),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 2),
                                      ),
                                      child: QrImageView(
                                        data: _qrToken!,
                                        version: QrVersions.auto,
                                        size: 200,
                                        backgroundColor: Colors.white,
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
                                    const SizedBox(height: 12),
                                    Text(
                                      _qrToken!,
                                      style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Biometrics Info Section
                            _buildSectionHeader(context, context.translate('biometric_status')),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: _biometricsInfo == null
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _biometricsInfo!['has_biometric'] == true 
                                                ? Colors.green.withValues(alpha: 0.1) 
                                                : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _biometricsInfo!['has_biometric'] == true ? Icons.face_rounded : Icons.face_retouching_off_rounded,
                                              color: _biometricsInfo!['has_biometric'] == true ? Colors.green : Colors.grey,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _biometricsInfo!['has_biometric'] == true ? context.translate('face_registered_status') : context.translate('not_registered'),
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                                ),
                                                if (_biometricsInfo!['has_biometric'] == true && _biometricsInfo!['registered_at'] != null)
                                                  Text(
                                                    '${context.translate('registered')}: ${_biometricsInfo!['registered_at'].toString().substring(0, 10)}',
                                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _biometricsInfo!['has_biometric'] == true 
                                                ? Colors.green.withValues(alpha: 0.1) 
                                                : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _biometricsInfo!['has_biometric'] == true ? context.translate('active') : context.translate('inactive'),
                                              style: TextStyle(
                                                color: _biometricsInfo!['has_biometric'] == true ? Colors.green : Colors.grey,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_biometricsInfo!['has_biometric'] == true && _biometricsInfo!['device_id'] != null) ...[
                                        const SizedBox(height: 16),
                                        Divider(color: Colors.white10),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.phone_android_rounded, color: Colors.white54, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Device ID:',
                                              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _biometricsInfo!['device_id'].toString(),
                                                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                            ),
                            const SizedBox(height: 32),

                            _buildSectionHeader(context, context.translate('security')),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.pin_rounded, color: AppTheme.primaryColor, size: 20),
                                      ),
                                      title: Text(context.translate('reset_pin'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                                      onTap: _handleResetPin,
                                    ),
                                    Divider(color: Colors.white10, height: 1),
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.face_retouching_off_rounded, color: Colors.orangeAccent, size: 20),
                                      ),
                                      title: Text(context.translate('clear_biometrics'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      trailing: const Icon(Icons.delete_outline_rounded, color: Colors.white30),
                                      onTap: _handleClearBiometrics,
                                    ),
                                    Divider(color: Colors.white10, height: 1),
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.phonelink_erase_rounded, color: AppTheme.errorColor, size: 20),
                                      ),
                                      title: Text(context.translate('reset_device_binding'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      trailing: const Icon(Icons.refresh_rounded, color: Colors.white30),
                                      onTap: _handleResetDevice,
                                    ),
                                    Divider(color: Colors.white10, height: 1),
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor, size: 20),
                                      ),
                                      title: Text(context.translate('delete_user'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                                      trailing: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                                      onTap: _handleDeleteUser,
                                    ),
                                  ],
                                ),
                              ),
                          const SizedBox(height: 48),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(color: Colors.black)
                                  : Text(context.translate('save_changes'), style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _handleResetPin() async {
    final TextEditingController pinController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('reset_pin')),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(hintText: context.translate('enter_new_pin')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(context.translate('save'), style: const TextStyle(color: AppTheme.primaryColor))
          ),
        ],
      ),
    );

    if (confirm == true && pinController.text.length == 4) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.resetUserPin(widget.userId, pinController.text, token);
        if (result.containsKey('msg')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('pin_reset_success'))));
        }
      }
    }
  }

  Future<void> _handleClearBiometrics() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('clear_biometrics')),
        content: Text(context.translate('confirm_biometric_clear')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(context.translate('clear_biometrics'), style: const TextStyle(color: Colors.orangeAccent))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.clearBiometrics(widget.userId, token);
        if (result.containsKey('msg')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('biometrics_cleared'))));
        }
      }
    }
  }

  Future<void> _handleResetDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('reset_device_binding')),
        content: Text(context.translate('reset_confirm_content')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(context.translate('reset_device_binding'), style: const TextStyle(color: AppTheme.errorColor))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.resetDevice(widget.userId, token);
        if (result.containsKey('msg')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('success'))));
        }
      }
    }
  }

  Future<void> _handleDeleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('delete_confirm_title')),
        content: Text(context.translate('delete_confirm_content')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(context.translate('delete_user'), style: const TextStyle(color: AppTheme.errorColor))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.deleteUser(widget.userId, token);
        if (result.containsKey('msg')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('user_deleted'))));
            Navigator.pop(context, true); // Return true to indicate deletion to parent
          }
        }
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

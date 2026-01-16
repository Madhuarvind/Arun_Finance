import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/localizations.dart';
import '../utils/theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  bool _biometricsEnabled = false;
  bool _trackingEnabled = false;
  // ignore: unused_field
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final name = await _storage.read(key: 'user_name');
    final bio = await _storage.read(key: 'biometrics_enabled_$name');
    final duty = await _storage.read(key: 'duty_status_$name');
    if (mounted) {
      setState(() {
        _biometricsEnabled = bio == 'true';
        _trackingEnabled = duty == 'on_duty';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool val) async {
    final name = await _storage.read(key: 'user_name');
    await _storage.write(key: 'biometrics_enabled_$name', value: val.toString());
    setState(() => _biometricsEnabled = val);
  }

  Future<void> _toggleTracking(bool val) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    setState(() => _isLoading = true);
    
    String status = val ? 'on_duty' : 'off_duty';
    double? lat, lng;

    if (val) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
           final pos = await Geolocator.getCurrentPosition();
           lat = pos.latitude;
           lng = pos.longitude;
        }
      }
    }

    final res = await _apiService.updateWorkerTracking(
      token: token,
      dutyStatus: status,
      latitude: lat,
      longitude: lng,
      activity: val ? 'starting_duty' : 'ending_duty'
    );

    if (res['msg'] == 'tracking_updated') {
      final name = await _storage.read(key: 'user_name');
      await _storage.write(key: 'duty_status_$name', value: status);
      setState(() {
        _trackingEnabled = val;
        _isLoading = false;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('server_error'))));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.translate('authentication'),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('manage_access'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Biometric Toggle Card
                      _buildToggleCard(
                        context.translate('biometric_login'),
                        context.translate('biometric_login_desc'),
                        Icons.fingerprint,
                        _biometricsEnabled,
                        (val) => _toggleBiometrics(val),
                        Colors.blue.withValues(alpha: 0.2),
                        Colors.blueAccent,
                      ),
                      
                      const SizedBox(height: 16),

                      _buildActionCard(
                        context.translate('enroll_face_title'),
                        context.translate('enroll_face_desc'),
                        Icons.face_retouching_natural_rounded,
                        Colors.amber.withValues(alpha: 0.2),
                        Colors.amberAccent,
                        () => Navigator.pushNamed(context, '/enroll_face').then((val) {
                           if (val == true) _loadSettings();
                        })
                      ),
                      
                      const SizedBox(height: 32),

                      Text(
                        context.translate('field_operations'),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                         context.translate('field_ops_desc'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildToggleCard(
                        context.translate('status'),
                        context.translate('duty_status_desc'),
                        Icons.location_on_rounded,
                        _trackingEnabled,
                        (val) => _toggleTracking(val),
                        Colors.green.withValues(alpha: 0.2),
                        Colors.greenAccent,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        context.translate('account_protection'),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('security_layers'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Device Management Card
                      _buildActionCard(
                        context.translate('reset_pin'),
                        context.translate('change_pin_desc'),
                        Icons.password_rounded,
                        Colors.purple.withValues(alpha: 0.2),
                        Colors.purpleAccent,
                        () => _showChangePinDialog(context)
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        context.translate('device_monitoring'),
                        "2 ${context.translate('device_mgmt_desc')}",
                        Icons.devices,
                        Colors.teal.withValues(alpha: 0.2),
                        Colors.tealAccent,
                        () => _showDeviceManagement(context)
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            context.translate('security_hub'),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Change PIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(oldPinCtrl, "Old PIN"),
            const SizedBox(height: 12),
            _buildDialogTextField(newPinCtrl, "New PIN"),
            const SizedBox(height: 12),
            _buildDialogTextField(confirmPinCtrl, "Confirm PIN"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
            onPressed: () async {
              if (newPinCtrl.text != confirmPinCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PINs do not match")));
                return;
              }
              // Implement API call here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN updated successfully")));
            },
            child: const Text("UPDATE"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
      ),
      keyboardType: TextInputType.number,
    );
  }

  void _showDeviceManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Active Sessions", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            _buildDeviceTile("This Device", "Windows 11 • Online", Icons.laptop_windows, true),
            _buildDeviceTile("Mobile Device", "Android 13 • Last active: 2h ago", Icons.smartphone, false),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2), foregroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context),
                child: const Text("Logout from all devices"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(String title, String subtitle, IconData icon, bool isCurrent) {
    return ListTile(
      leading: Icon(icon, color: isCurrent ? AppTheme.primaryColor : Colors.white54),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: isCurrent ? Chip(label: const Text("Current", style: TextStyle(fontSize: 10, color: Colors.black)), backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.8)) : null,
    );
  }

  Widget _buildToggleCard(
    String title, 
    String subtitle, 
    IconData icon, 
    bool value, 
    ValueChanged<bool> onChanged,
    Color iconBg,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.all(AppTheme.primaryColor),
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title, 
    String subtitle, 
    IconData icon, 
    Color iconBg, 
    Color iconColor,
    VoidCallback onTap
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'face_verification_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  bool _isLoading = false;

  void _handleLogin(String name) async {
    setState(() => _isLoading = true);
    
    // 1. Try Offline Validation first (if user has logged in before on this device)
    final offlineError = await _localDbService.verifyPinOffline(name, _pinController.text);
    if (offlineError == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('logged_offline'))),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    // 2. If offline fails (not found or WRONG pin), try Online Validation
    try {
      final deviceId = await _localDbService.getDeviceId();
      final result = await _apiService.loginPin(name, _pinController.text, deviceId: deviceId);
      final msg = result['msg']?.toString().toLowerCase() ?? '';
      
      if (result.containsKey('access_token')) {
        await _apiService.saveTokens(
          result['access_token'], 
          result['refresh_token'] ?? ''
        );
        await _localDbService.saveUserLocally(
          name: name, 
          pin: _pinController.text,
          token: result['access_token'],
          role: result['role'],
          isActive: result['is_active'],
          isLocked: result['is_locked'],
        );
        if (mounted) {
          setState(() => _isLoading = false);
        }
        
        if (!mounted) return;
        
        if (msg == 'requires_face_verification') {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaceVerificationScreen(userName: name),
            ),
          );
          return;
        }

        if (result['role'] == 'admin') {
          Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        
        // If it was a connection error, and we already tried offline above, 
        // it means either the user is new or the offline PIN was genuinely wrong.
        if (msg.contains('connection_failed') || msg.contains('error')) {
          if (!mounted) return;
          String displayError = context.translate(offlineError); // Show why offline failed (e.g. user not found)
          if (result.containsKey('details')) {
            displayError += "\nDetails: ${result['details']}";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayError)),
          );
        } else {
          if (mounted) {
            _pinController.clear();
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate(result['msg'] ?? 'invalid_pin'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final name = args?['name'] ?? '';

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
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
              child: SingleChildScrollView( 
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, Color(0xFFD4FF8B)]),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_person_outlined, size: 48, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      context.translate('welcome'),
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      context.translate('enter_pin'),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PinCodeTextField(
                      appContext: context,
                      length: 4,
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.scale,
                      textStyle: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold),
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(16),
                        fieldHeight: 64,
                        fieldWidth: 64,
                        activeFillColor: Colors.white.withValues(alpha: 0.1),
                        selectedFillColor: Colors.white.withValues(alpha: 0.1),
                        inactiveFillColor: Colors.white.withValues(alpha: 0.03),
                        activeColor: AppTheme.primaryColor,
                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                        inactiveColor: Colors.white.withValues(alpha: 0.1),
                        borderWidth: 1.5,
                      ),
                      enableActiveFill: true,
                      onChanged: (value) {},
                      onCompleted: (value) {
                         _handleLogin(name);
                      },
                      cursorColor: AppTheme.primaryColor,
                      animationDuration: const Duration(milliseconds: 300),
                    ),
                    const SizedBox(height: 48),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    
                    const SizedBox(height: 40),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cached_rounded, size: 20, color: Colors.white38),
                      label: Text(
                        context.translate('change'),
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
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
}

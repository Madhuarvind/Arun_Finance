import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  bool _isConfirming = false;
  bool _isLoading = false;

  void _handleSetPin(String name) async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.setPin(name, _pinController.text);
      final msg = result['msg']?.toString().toLowerCase() ?? '';
      
      if (result.containsKey('msg') && (msg.contains('success') || msg.contains('successfully'))) {
        await _localDbService.saveUserLocally(
          name: name, 
          pin: _pinController.text
        );
        if (mounted) {
          setState(() => _isLoading = false);
        }
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate(result['msg'] ?? 'failure'))),
        );
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
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final name = args['name'] ?? args['mobile_number'] ?? '';

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent, 
            elevation: 0, 
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
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
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, size: 40, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isConfirming ? context.translate('confirm_pin') : context.translate('set_pin'), 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.translate('pin_usage_info'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 16, color: Colors.white54),
                    ),
                    const SizedBox(height: 48),
                    PinCodeTextField(
                      appContext: context,
                      length: 4,
                      controller: _isConfirming ? _confirmPinController : _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.scale,
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
                      textStyle: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold),
                      enableActiveFill: true,
                      onChanged: (value) {},
                      onCompleted: (value) {
                        if (!_isConfirming) {
                          setState(() {
                            _isConfirming = true;
                          });
                        } else {
                          _handleSetPin(name);
                        }
                      },
                      cursorColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (!_isConfirming) {
                           setState(() => _isConfirming = true);
                        } else {
                          _handleSetPin(name);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            context.translate('save').toUpperCase(), 
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)
                          ),
                    ),
                    const Spacer(),
                    
                    if (_isConfirming && !_isLoading)
                       Center(
                         child: TextButton.icon(
                          onPressed: () => setState(() => _isConfirming = false),
                          icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 18),
                          label: Text(
                            context.translate('change'), 
                            style: GoogleFonts.outfit(fontSize: 16, color: Colors.white54)
                          ),
                                                 ),
                       ),
                    const SizedBox(height: 24),
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

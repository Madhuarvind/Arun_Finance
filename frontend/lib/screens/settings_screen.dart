import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = FlutterSecureStorage();
  String? _role;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _storage.read(key: 'user_role');
    if (mounted) {
      setState(() {
        _role = role;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.translate('settings'),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
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
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
              padding: const EdgeInsets.only(top: kToolbarHeight + 40, left: 24, right: 24, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.translate('select_language'),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Tamil Card
                _buildLanguageCard(
                  context, 
                  'ta', 
                  context.translate('tamil'), 
                  '🇮🇳', 
                  languageProvider
                ),
                const SizedBox(height: 16),
                
                // English Card
                _buildLanguageCard(
                  context, 
                  'en', 
                  context.translate('english'), 
                  '🇺🇸', 
                  languageProvider
                ),
                
                const SizedBox(height: 16),

                if (_role != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    "ACCOUNT & SECURITY",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white24,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildActionCard(
                    context,
                    "Security Hub",
                    "MANAGE BIOMETRICS & PIN",
                    Icons.security_rounded,
                    const Color(0xFF3B82F6),
                    () => Navigator.pushNamed(context, '/security')
                  ),
                ],
                
                if (_role == 'admin') ...[
                  const SizedBox(height: 16),
                  _buildActionCard(
                    context,
                    "Admin Config",
                    "INTEREST, UPI & PERMISSIONS",
                    Icons.settings_suggest_rounded,
                    const Color(0xFF16A34A),
                    () => Navigator.pushNamed(context, '/admin/master_settings')
                  ),
                ],
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageCard(BuildContext context, String code, String name, String flag, LanguageProvider provider) {
    final isSelected = provider.currentLocale.languageCode == code;
    final borderColor = isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05);
    
    return InkWell(
      onTap: () => provider.setLanguage(code),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryColor : Colors.white70,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
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
                color: iconColor.withValues(alpha: 0.1),
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
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white24,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

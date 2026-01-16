import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/theme.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkerQrScreen extends StatelessWidget {
  final int userId;
  final String name;
  final String qrToken;

  const WorkerQrScreen({
    super.key, 
    required this.userId, 
    required this.name,
    required this.qrToken,
  });

  @override
  Widget build(BuildContext context) {
    final String qrData = qrToken;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              context.translate('worker_qr'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digital Identity Token',
                    style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 240.0,
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
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            context.translate('qr_footer'),
                            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.popUntil(context, ModalRoute.withName('/admin/dashboard'));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        context.translate('done').toUpperCase(), 
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart'; // To access cameras list

class FaceVerificationScreen extends StatefulWidget {
  final String userName;
  const FaceVerificationScreen({super.key, required this.userName});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    
    // Find front camera
    CameraDescription? frontCamera;
    for (var cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        frontCamera = cam;
        break;
      }
    }
    
    _controller = CameraController(
      frontCamera ?? cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Analyzing face...";
    });
    
    try {
      final image = await _controller!.takePicture();
      final imageBytes = await image.readAsBytes();
      final deviceId = await _localDbService.getDeviceId();
      
      final result = await _apiService.verifyFaceLogin(
        widget.userName,
        imageBytes,
        deviceId
      );

      if (!mounted) return;

      if (result['msg'] == 'face_verified') {
        // Success -> Save tokens and navigate
        await _apiService.saveTokens(result['access_token'], result['refresh_token'] ?? '');
        await _apiService.saveUserData(widget.userName, result['role'] ?? 'field_agent');
        
        // Save locally too
        await _localDbService.saveUserLocally(
          name: widget.userName,
          pin: '****', // We don't have PIN here, store placeholder or fetch if needed
          token: result['access_token'],
          role: result['role'] ?? 'field_agent',
          isActive: true,
          isLocked: false,
        );
        
        setState(() => _statusMessage = "Verified! Redirecting...");
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        if (result['role'] == 'admin') {
          Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        setState(() {
          final errorMsg = result['msg'] ?? "Verification failed";
          final details = result['error'] ?? result['details'] ?? "";
          _statusMessage = details.isNotEmpty ? "$errorMsg\n($details)" : errorMsg;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Camera
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),
          
          // Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.security, color: AppTheme.primaryColor, size: 32),
                      const SizedBox(height: 16),
                      Text(
                        "Security Check",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "New device detected. Verify face to continue.",
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Status Message
                if (_statusMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24)
                    ),
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),

                // Action Button
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _captureAndVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text("VERIFY IDENTITY", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddUserWizardScreen extends StatefulWidget {
  const AddUserWizardScreen({super.key});

  @override
  State<AddUserWizardScreen> createState() => _AddUserWizardScreenState();
}

class _AddUserWizardScreenState extends State<AddUserWizardScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  final PageController _pageController = PageController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _idProofController = TextEditingController();
  
  String _selectedRole = 'field_agent';
  
  final List<String> _stepTitles = ['Basic Info', 'Location', 'Security', 'Review'];

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _idProofController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _createUser();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic Info
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter a name');
          return false;
        }
        if (_mobileController.text.trim().isEmpty || _mobileController.text.length != 10) {
          _showError('Please enter a valid 10-digit mobile number');
          return false;
        }
        return true;
      case 1: // Location
        if (_areaController.text.trim().isEmpty) {
          _showError('Please enter an area');
          return false;
        }
        return true;
      case 2: // Security
        if (_pinController.text.length != 4) {
          _showError('PIN must be 4 digits');
          return false;
        }
        if (_pinController.text != _confirmPinController.text) {
          _showError('PINs do not match');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _createUser() async {
    setState(() => _isLoading = true);
    
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {

      return;

    }

    final result = await _apiService.registerWorker(
      _nameController.text.trim(),
      _mobileController.text.trim(),
      _pinController.text,
      token,
      area: _areaController.text.trim(),
      address: _addressController.text.trim(),
      idProof: _idProofController.text.trim(),
      role: _selectedRole,
    );

    setState(() => _isLoading = false);

    if (result['msg'] == 'Worker created successfully') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        _showError(result['msg'] ?? 'Failed to create user');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text(
          'Add New User',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Step Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_currentStep + 1}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _stepTitles[_currentStep],
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildLocationStep(),
                _buildSecurityStep(),
                _buildReviewStep(),
              ],
            ),
          ),
          
          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(_currentStep == 3 ? 'Create User'.toUpperCase() : 'Next'.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Full Name *',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Enter full name',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Mobile Number *',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Enter 10-digit mobile',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              counterStyle: const TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            dropdownColor: const Color(0xFF1E293B),
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Role',
              labelStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'field_agent', child: Text('Field Agent')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) {
              if (value != null) {

                setState(() => _selectedRole = value);

              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _areaController,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Area *',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Enter area/locality',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            maxLines: 3,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Full Address',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Enter complete address',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.home_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _idProofController,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'ID Proof',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Aadhar/PAN/Driving License',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.credit_card_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set a 4-digit PIN for login',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'PIN *',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Enter 4-digit PIN',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              counterStyle: const TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Confirm PIN *',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Re-enter PIN',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              counterStyle: const TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Information',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildReviewItem('Name', _nameController.text),
          _buildReviewItem('Mobile', _mobileController.text),
          _buildReviewItem('Role', _selectedRole.toUpperCase().replaceAll('_', ' ')),
          _buildReviewItem('Area', _areaController.text),
          if (_addressController.text.isNotEmpty)
            _buildReviewItem('Address', _addressController.text),
          if (_idProofController.text.isNotEmpty)
            _buildReviewItem('ID Proof', _idProofController.text),
          _buildReviewItem('PIN', '****'),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.outfit(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

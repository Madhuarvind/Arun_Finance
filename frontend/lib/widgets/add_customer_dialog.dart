import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/localizations.dart';
import '../screens/customer_id_card_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _idProofController = TextEditingController();
  final _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _idProofController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.isEmpty || _mobileController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.createCustomer({
          'name': _nameController.text,
          'mobile_number': _mobileController.text,
          'area': _areaController.text,
          'address': _addressController.text,
          'id_proof_number': _idProofController.text,
        }, token);

        if (mounted) {
          if (result['msg'] == 'customer_created_successfully') {
            Navigator.pop(context, true);
            // Show the ID Card
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerIdCardScreen(
                  customer: {
                    'id': result['id'],
                    'customer_id': result['customer_id'],
                    'name': _nameController.text,
                    'mobile': _mobileController.text,
                    'area': _areaController.text,
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['msg'] ?? 'Failed to create customer')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {

        setState(() => _isLoading = false);

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      scrollable: true,
      title: Text(
        local.translate('add_customer'), 
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildField(_nameController, local.translate('name'), Icons.person_rounded),
          const SizedBox(height: 16),
          _buildField(_mobileController, local.translate('mobile_number'), Icons.phone_android_rounded, type: TextInputType.phone),
          const SizedBox(height: 16),
          _buildField(_areaController, "${local.translate('area')} (Optional)", Icons.pin_drop_rounded),
          const SizedBox(height: 16),
          _buildField(_addressController, "${local.translate('address')} (Optional)", Icons.home_rounded, maxLines: 2),
          const SizedBox(height: 16),
          _buildField(_idProofController, "ID Proof / Aadhar (Optional)", Icons.badge_rounded),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(local.translate('cancel'), style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isLoading ? null : _handleCreate,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Text(local.translate('create'), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

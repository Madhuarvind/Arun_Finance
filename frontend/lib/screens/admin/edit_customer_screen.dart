import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';

class EditCustomerScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const EditCustomerScreen({super.key, required this.customer});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _idProofCtrl;
  
  bool _isLoading = false;

  File? _newProfileImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer['name']);
    _mobileCtrl = TextEditingController(text: widget.customer['mobile']);
    _areaCtrl = TextEditingController(text: widget.customer['area']);
    _addressCtrl = TextEditingController(text: widget.customer['address']);
    _idProofCtrl = TextEditingController(text: widget.customer['id_proof_number']);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, maxWidth: 600);
    if (pickedFile != null) {
      setState(() => _newProfileImage = File(pickedFile.path));
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final data = {
        'name': _nameCtrl.text,
        'mobile': _mobileCtrl.text,
        'area': _areaCtrl.text,
        'address': _addressCtrl.text,
        'id_proof_number': _idProofCtrl.text,
      };

      if (_newProfileImage != null) {
        final bytes = await _newProfileImage!.readAsBytes();
        data['profile_image'] = base64Encode(bytes);
      }
      
      final result = await _apiService.updateCustomer(widget.customer['id'], data, token);
      if (mounted) {
        if (result.containsKey('msg') && result['msg'] == 'Customer updated successfully') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated successfully!"), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: ${result['msg']}"), backgroundColor: Colors.red));
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Current image can be base64 string or null
    final currentImage = widget.customer['profile_image'];
    ImageProvider? bgImage;
    if (_newProfileImage != null) {
      bgImage = FileImage(_newProfileImage!);
    } else if (currentImage != null && currentImage is String && currentImage.isNotEmpty) {
        // Check if it's a path or base64. If it's online, it's likely base64 or a URL. 
        // Assuming base64 for now as per my plan.
        try {
           bgImage = MemoryImage(base64Decode(currentImage));
        } catch (_) {
           // Fallback if not base64 (maybe a path from offline sync?)
        }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Edit Customer", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
         decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                 GestureDetector(
                   onTap: _pickImage,
                   child: CircleAvatar(
                     radius: 50,
                     backgroundColor: Colors.white.withValues(alpha: 0.1),
                     backgroundImage: bgImage,
                     child: bgImage == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.white54) : null,
                   ),
                 ),
                 const SizedBox(height: 10),
                 Text("Tap to update photo", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                 const SizedBox(height: 20),
                 _buildField(_nameCtrl, "Name", Icons.person),
                 const SizedBox(height: 16),
                 _buildField(_mobileCtrl, "Mobile", Icons.phone, type: TextInputType.phone),
                 const SizedBox(height: 16),
                 _buildField(_areaCtrl, "Area", Icons.map),
                 const SizedBox(height: 16),
                 _buildField(_addressCtrl, "Address", Icons.home, maxLines: 2),
                 const SizedBox(height: 16),
                 _buildField(_idProofCtrl, "ID Proof", Icons.badge),
                 const SizedBox(height: 30),
                 SizedBox(
                   width: double.infinity,
                   height: 50,
                   child: ElevatedButton(
                     onPressed: _isLoading ? null : _update,
                     child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("Update Customer"),
                   ),
                 )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: (v) => v!.isEmpty ? "$label is required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryColor)),
      ),
    );
  }
}

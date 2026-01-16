import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';

class AddLoanScreen extends StatefulWidget {
  final int customerId;
  final String customerName;
  const AddLoanScreen({super.key, required this.customerId, required this.customerName});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _interestCtrl = TextEditingController(text: "10");
  final _tenureCtrl = TextEditingController(text: "100");
  final _feeCtrl = TextEditingController(text: "0");
  final _guarantorNameCtrl = TextEditingController();
  final _guarantorMobileCtrl = TextEditingController();
  final _guarantorRelationCtrl = TextEditingController();
  
  String _interestType = 'flat';
  String _tenureUnit = 'days';
  
  final _storage = FlutterSecureStorage();
  final _apiService = ApiService();
  final _localDb = LocalDbService();
  bool _isLoading = false;
  Map<String, dynamic> _systemSettings = {};

  @override
  void initState() {
    super.initState();
    _fetchDefaults();
  }

  Future<void> _fetchDefaults() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final settings = await _apiService.getSystemSettings(token);
      if (mounted && settings.isNotEmpty) {
        setState(() {
          _systemSettings = settings;
          if (settings.containsKey('default_interest_rate')) {
            _interestCtrl.text = settings['default_interest_rate'];
          }
        });
      }
    }
  }

  Future<void> _createLoan({bool offlineOnly = false}) async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate Max Loan
    if (_systemSettings.containsKey('max_loan_amount')) {
      final maxLoan = double.tryParse(_systemSettings['max_loan_amount']) ?? 50000;
      final currentAmount = double.tryParse(_amountCtrl.text) ?? 0;
      if (currentAmount > maxLoan) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Amount exceeds limit of ₹$maxLoan (See Settings)"),
          backgroundColor: Colors.red
        ));
        return;
      }
    }
    
    final data = {
      'customer_id': widget.customerId,
      'principal_amount': double.parse(_amountCtrl.text),
      'interest_rate': double.parse(_interestCtrl.text),
      'interest_type': _interestType,
      'tenure': int.parse(_tenureCtrl.text),
      'tenure_unit': _tenureUnit,
      'processing_fee': double.parse(_feeCtrl.text),
      'guarantor_name': _guarantorNameCtrl.text,
      'guarantor_mobile': _guarantorMobileCtrl.text,
      'guarantor_relation': _guarantorRelationCtrl.text,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (offlineOnly) {
      await _saveLocally(data);
      return;
    }

    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    
    try {
      if (token != null) {
        final result = await _apiService.createLoan(data, token);
        if (mounted) {
          if (result.containsKey('id')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan draft created online!"), backgroundColor: Colors.green));
            Navigator.pop(context, true);
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server Error: ${result['msg']}. Saving locally..."), backgroundColor: Colors.orange));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection failed. Saving locally..."), backgroundColor: Colors.orange));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // If we reached here, online failed, save locally
    await _saveLocally(data);
  }

  Future<void> _saveLocally(Map<String, dynamic> data) async {
    try {
      await _localDb.saveLoanDraft(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan draft saved locally. Sync when online."), backgroundColor: Colors.blue));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving locally: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Issue Loan to ${widget.customerName}", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text("LOAN DETAILS", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.primaryColor, letterSpacing: 1.5)),
               const SizedBox(height: 20),
               _buildField(_amountCtrl, "Loan Amount (₹)", Icons.currency_rupee, type: TextInputType.number, textInputAction: TextInputAction.next),
               const SizedBox(height: 16),
               
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _interestType,
                        style: GoogleFonts.outfit(color: Colors.white),
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: InputDecoration(
                          labelText: 'Int. Type', 
                          labelStyle: const TextStyle(color: Colors.white38),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'flat', child: Text('Flat')),
                          DropdownMenuItem(value: 'reducing', child: Text('Red.')),
                        ],
                        onChanged: (v) => setState(() => _interestType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildField(_interestCtrl, "Rate %", Icons.percent_rounded, type: TextInputType.number, textInputAction: TextInputAction.next),
                    ),
                  ],
                ),
               const SizedBox(height: 16),
               
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildField(_tenureCtrl, "Tenure", Icons.calendar_today_rounded, type: TextInputType.number, textInputAction: TextInputAction.next),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _tenureUnit,
                        style: GoogleFonts.outfit(color: Colors.white),
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          labelStyle: const TextStyle(color: Colors.white38),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                          DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
                          DropdownMenuItem(value: 'months', child: Text('Months')),
                        ],
                        onChanged: (v) => setState(() => _tenureUnit = v!),
                      ),
                    ),
                  ],
                ),
               const SizedBox(height: 16),
               _buildField(_feeCtrl, "Processing Fee (₹)", Icons.settings_suggest_rounded, type: TextInputType.number, textInputAction: TextInputAction.next),
               
               const SizedBox(height: 32),
               const Divider(color: Colors.white10),
               const SizedBox(height: 24),
               Text("GUARANTOR DETAILS", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white38, letterSpacing: 1.5)),
               const SizedBox(height: 20),
                _buildField(_guarantorNameCtrl, "Guarantor Name", Icons.person_outline_rounded, textInputAction: TextInputAction.next),
                const SizedBox(height: 12),
                _buildField(_guarantorMobileCtrl, "Guarantor Mobile", Icons.phone_android_rounded, type: TextInputType.phone, textInputAction: TextInputAction.next),
                const SizedBox(height: 12),
                _buildField(_guarantorRelationCtrl, "Relation (e.g., Father)", Icons.people_outline_rounded, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _createLoan()),
                
                 const SizedBox(height: 48),
                 SizedBox(
                   width: double.infinity,
                   height: 60,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.primaryColor,
                       foregroundColor: Colors.black,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       elevation: 0,
                     ),
                     onPressed: _isLoading ? null : () => _createLoan(),
                     child: _isLoading 
                       ? const CircularProgressIndicator(color: Colors.black) 
                       : Text("CREATE LOAN DRAFT", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                   ),
                 ),
                 const SizedBox(height: 16),
                 SizedBox(
                   width: double.infinity,
                   height: 55,
                   child: OutlinedButton.icon(
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.white70,
                       side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     ),
                     onPressed: _isLoading ? null : () => _createLoan(offlineOnly: true),
                     icon: const Icon(Icons.cloud_off_rounded, size: 20),
                     label: Text("SAVE AS OFFLINE DRAFT", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                   ),
                 ),
                 const SizedBox(height: 24),
                 Center(child: Text("DRAFT REQUIRES ADMIN APPROVAL", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1))),
                 const SizedBox(height: 40),
              ],
           ),
         ),
       ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, TextInputAction? textInputAction, void Function(String)? onFieldSubmitted}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: GoogleFonts.outfit(color: Colors.white),
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}

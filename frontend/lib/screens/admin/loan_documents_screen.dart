import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:file_picker/file_picker.dart';

class LoanDocumentsScreen extends StatefulWidget {
  final int loanId;
  final String loanNumber;
  
  const LoanDocumentsScreen({super.key, required this.loanId, required this.loanNumber});

  @override
  State<LoanDocumentsScreen> createState() => _LoanDocumentsScreenState();
}

class _LoanDocumentsScreenState extends State<LoanDocumentsScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  List<dynamic> _documents = [];
  Map<String, dynamic>? _penaltySummary;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final docs = await _apiService.getLoanDocuments(widget.loanId, token);
      final penalty = await _apiService.getPenaltySummary(widget.loanId, token);
      
      if (mounted) {
        setState(() {
          _documents = docs;
          _penaltySummary = penalty;
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _uploadDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    
    if (result != null && result.files.single.path != null) {
      final docType = await _selectDocumentType();
      if (docType == null) return;
      
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final response = await _apiService.uploadLoanDocument(
          widget.loanId,
          result.files.single.path!,
          docType,
          token
        );
        
        if (mounted) {
          if (response['msg']?.contains('success') ?? false) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document uploaded!'), backgroundColor: Colors.green)
            );
            _fetchData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: ${response['msg']}'), backgroundColor: Colors.red)
            );
          }
        }
      }
    }
  }
  
  Future<String?> _selectDocumentType() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Select Document Type', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogTile('Agreement', 'agreement'),
            _dialogTile('Signature', 'signature'),
            _dialogTile('ID Proof', 'id_proof'),
            _dialogTile('Other', 'other'),
          ],
        ),
      ),
    );
  }

  Widget _dialogTile(String title, String value) {
    return ListTile(
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white)),
      onTap: () => Navigator.pop(context, value),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Loan ${widget.loanNumber}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: _uploadDocument,
          ),
          const SizedBox(width: 8),
        ],
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Penalty Summary Card
                    if (_penaltySummary != null && (_penaltySummary!['total_penalty'] ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text('PENALTY ALERT', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '₹${_penaltySummary!['total_penalty']}',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_penaltySummary!['overdue_count']} OVERDUE INSTALMENTS',
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                'Grace Period: ${_penaltySummary!['grace_period_days']} days',
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_documents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.folder_open_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                              const SizedBox(height: 16),
                              Text('NO DOCUMENTS UPLOADED', style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      )
                    else
                      for (var doc in _documents) _buildDocumentTile(doc),
                  ],
                ),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadDocument,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded),
        label: Text('UPLOAD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
  
  Widget _buildDocumentTile(Map<String, dynamic> doc) {
    final icons = {
      'agreement': Icons.description_rounded,
      'signature': Icons.draw_rounded,
      'id_proof': Icons.badge_rounded,
      'other': Icons.insert_drive_file_rounded,
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icons[doc['doc_type']] ?? Icons.insert_drive_file_rounded, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['filename'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(doc['doc_type'].toString().toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ],
      ),
    );
  }
}

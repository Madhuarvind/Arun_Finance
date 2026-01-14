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
        title: const Text('Select Document Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Agreement'), onTap: () => Navigator.pop(context, 'agreement')),
            ListTile(title: const Text('Signature'), onTap: () => Navigator.pop(context, 'signature')),
            ListTile(title: const Text('ID Proof'), onTap: () => Navigator.pop(context, 'id_proof')),
            ListTile(title: const Text('Other'), onTap: () => Navigator.pop(context, 'other')),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Loan ${widget.loanNumber}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadDocument,
          )
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Penalty Summary Card
                  if (_penaltySummary != null && (_penaltySummary!['total_penalty'] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red[700]!, Colors.red[500]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Text('Penalty Alert', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '₹${_penaltySummary!['total_penalty']}',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)
                          ),
                          Text(
                            '${_penaltySummary!['overdue_count']} overdue EMI(s)',
                            style: const TextStyle(color: Colors.white70, fontSize: 14)
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Grace Period: ${_penaltySummary!['grace_period_days']} days',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                  
                  if (_penaltySummary != null && (_penaltySummary!['total_penalty'] ?? 0) > 0)
                    const SizedBox(height: 24),
                  
                  // Documents Section
                  Text('Documents', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  if (_documents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No documents uploaded', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  else
                    ...(_documents.map((doc) => _buildDocumentTile(doc)).toList()),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadDocument,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Upload Document'),
      ),
    );
  }
  
  Widget _buildDocumentTile(Map<String, dynamic> doc) {
    final icons = {
      'agreement': Icons.description,
      'signature': Icons.draw,
      'id_proof': Icons.badge,
      'other': Icons.insert_drive_file,
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icons[doc['doc_type']] ?? Icons.insert_drive_file, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['filename'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                Text(doc['doc_type'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

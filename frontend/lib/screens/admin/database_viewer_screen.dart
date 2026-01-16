import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  String _selectedTable = 'Users';
  final List<String> _tables = [
    'Users', 
    'Customers', 
    'Loans', 
    'Lines', 
    'Collections',
    'DailySettlement',
    'CustomerVersion',
    'CustomerNote',
    'CustomerDocument',
    'SystemSetting'
  ];
  List<dynamic> _data = [];
  bool _isLoading = false;
  List<String> _columns = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        List<dynamic> result = [];
        switch (_selectedTable) {
          case 'Users':
            result = await _apiService.getUsers(token);
            break;
          case 'Customers':
            result = await _apiService.getCustomers(token);
            break;
          case 'Loans':
            result = await _apiService.getLoans(token: token); // Fetch all
            break;
          case 'Lines':
            result = await _apiService.getAllLines(token);
            break;
          case 'Collections':
             // History might be large, but it's what we have. 
             // Or getCollectionHistory which usually returns recent. 
             // Ideally we need a full dump but let's use what we have.
            result = await _apiService.getCollectionHistory(token);
            break;
          case 'DailySettlement':
            result = await _apiService.getDailySettlements(token);
            break;
            // For others, we might need new endpoints if they don't exist
            // Assuming for now we skip or add generic getter later
          default:
             // If no specific endpoint, clear
            result = [];
            break;
        }
        
        setState(() {
          _data = result;
          if (_data.isNotEmpty) {
            _columns = _data[0].keys.toList();
             // Simple suppression of complex objects if necessary, or just toString them
          } else {
            _columns = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Database Viewer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchData,
          )
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
        padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                   const Text("Select Table: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12),
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                         color: Colors.white.withValues(alpha: 0.05),
                       ),
                       child: DropdownButtonHideUnderline(
                         child: DropdownButton<String>(
                           value: _selectedTable,
                           isExpanded: true,
                           dropdownColor: const Color(0xFF1E293B),
                           style: GoogleFonts.outfit(color: Colors.white),
                           items: _tables.map((String value) {
                             return DropdownMenuItem<String>(
                               value: value,
                               child: Text(value, style: GoogleFonts.outfit(color: Colors.white)),
                             );
                           }).toList(),
                           onChanged: (newValue) {
                             if (newValue != null) {
                               setState(() {
                                 _selectedTable = newValue;
                               });
                               _fetchData();
                             }
                           },
                         ),
                       ),
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _data.isEmpty 
                    ? Center(child: Text("No records found in $_selectedTable", style: const TextStyle(color: Colors.white54)))
                    : Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.1)),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
                                dataRowColor: WidgetStateProperty.all(Colors.transparent),
                                columns: _columns.map((col) => DataColumn(
                                  label: Text(
                                    col.toUpperCase().replaceAll('_', ' '), 
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  )
                                )).toList(),
                                rows: _data.map((row) {
                                  return DataRow(
                                    cells: _columns.map((col) {
                                      var val = row[col] ?? '-';
                                      return DataCell(Text(val.toString(), style: const TextStyle(color: Colors.white70)));
                                    }).toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

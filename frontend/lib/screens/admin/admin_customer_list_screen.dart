import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/add_customer_dialog.dart';
import 'customer_detail_screen.dart';
import 'dart:async';

class AdminCustomerListScreen extends StatefulWidget {
  const AdminCustomerListScreen({super.key});

  @override
  State<AdminCustomerListScreen> createState() => _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen> {
  final _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _customers = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _customers = [];
    }

    setState(() => _isLoading = true);
    
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getAllCustomers(
        page: _page,
        search: _searchController.text,
        token: token,
      );
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _customers = result['customers'];
          } else {
            _customers.addAll(result['customers']);
          }
          _totalPages = result['pages'] ?? 1;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {

      _debounce!.cancel();

    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadCustomers(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('All Customers', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by Name, Mobile, ID...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
            child: _isLoading && _customers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? Center(child: Text('No customers found', style: GoogleFonts.outfit(fontSize: 16, color: Colors.white30)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _customers.length + (_page < _totalPages ? 1 : 0),
                        itemBuilder: (context, index) {
                           if (index == _customers.length) {
                             // Load more
                             _page++;
                             _loadCustomers();
                             return const Padding(
                               padding: EdgeInsets.all(8.0),
                               child: Center(child: CircularProgressIndicator()),
                             );
                           }
                           
                           final customer = _customers[index];


                           return Container(
                             margin: const EdgeInsets.only(bottom: 12),
                             decoration: BoxDecoration(
                               color: Colors.white.withValues(alpha: 0.05),
                               borderRadius: BorderRadius.circular(24),
                               border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                             ),
                             child: ListTile(
                               onTap: () async {
                                 await Navigator.push(
                                   context,
                                   MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer['id'])),
                                 );
                                 _loadCustomers(refresh: true);
                               },
                               contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                               leading: Container(
                                 width: 52,
                                 height: 52,
                                 decoration: BoxDecoration(
                                   color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(18),
                                 ),
                                 child: Center(
                                   child: Text(
                                     customer['name'][0].toUpperCase(), 
                                     style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)
                                   ),
                                 ),
                               ),
                               title: Text(customer['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                               subtitle: Text(
                                 "${customer['customer_id'] ?? 'Pending'} • ${customer['mobile']}",
                                 style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                               ),
                               trailing: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                     decoration: BoxDecoration(
                                       color: customer['status'] == 'active' ? Colors.green.withValues(alpha: 0.1) : Colors.white10,
                                       borderRadius: BorderRadius.circular(20),
                                     ),
                                     child: Text(
                                       (customer['status'] ?? 'Active').toUpperCase(), 
                                       style: GoogleFonts.outfit(
                                         fontSize: 10, 
                                         fontWeight: FontWeight.w900,
                                         color: customer['status'] == 'active' ? Colors.green : Colors.white38,
                                         letterSpacing: 0.5
                                       )
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                                 ],
                               ),
                             ),
                           );
                        },
                      ),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final result = await showDialog(
          context: context,
          builder: (context) => const AddCustomerDialog(),
        );
        if (result == true && mounted) {
          _loadCustomers(refresh: true);
        }
      },
      backgroundColor: AppTheme.primaryColor,
      icon: const Icon(Icons.person_add_rounded, color: Colors.black),
      label: Text('Add Customer'.toUpperCase(), style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

}
}

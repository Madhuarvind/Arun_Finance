import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'line_report_screen.dart';
import '../widgets/add_customer_dialog.dart';

class AgentLinesScreen extends StatefulWidget {
  const AgentLinesScreen({super.key});

  @override
  State<AgentLinesScreen> createState() => _AgentLinesScreenState();
}

class _AgentLinesScreenState extends State<AgentLinesScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _lines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLines();
  }

  Future<void> _fetchLines() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final lines = await _apiService.getAllLines(token);
        setState(() {
          _lines = lines;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('my_lines'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.assignment_late_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "NO LINES ASSIGNED",
                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "CONTACT ADMIN FOR ASSIGNMENT",
                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.white12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.route_rounded, color: AppTheme.primaryColor, size: 24),
                        ),
                        title: Text(line['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                        subtitle: Text(
                          '${line['area']} • ${line['customer_count']} CUSTOMERS', 
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                        ),
                        trailing: line['is_locked'] 
                          ? const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 20) 
                          : const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                        onTap: line['is_locked'] 
                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Line is locked'), backgroundColor: Colors.red))
                          : () => _viewLineCustomers(line),
                      ),
                    );
                  },
                ),
    );
  }

  void _viewLineCustomers(dynamic line) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _LineCustomersSheet(line: line, apiService: _apiService, storage: _storage),
    );
  }
}

class _LineCustomersSheet extends StatefulWidget {
  final dynamic line;
  final ApiService apiService;
  final FlutterSecureStorage storage;

  const _LineCustomersSheet({required this.line, required this.apiService, required this.storage});

  @override
  State<_LineCustomersSheet> createState() => _LineCustomersSheetState();
}

class _LineCustomersSheetState extends State<_LineCustomersSheet> {
  List<dynamic> _pendingCustomers = [];
  List<dynamic> _collectedCustomers = [];
  List<dynamic> _allCustomers = [];
  bool _isLoading = true;
  double _totalCollected = 0;
  double _totalCash = 0;
  double _totalUpi = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await widget.storage.read(key: 'jwt_token');
      if (token != null) {
        // 1. Fetch all customers in this line (now includes is_collected_today)
        final List<dynamic> custs = await widget.apiService.getLineCustomers(widget.line['id'], token);
        
        double collected = 0;
        double cash = 0;
        double upi = 0;

        // Since the UI needs to show WHO collected today, we still might want history for the amounts,
        // or we can rely on the fact that 'collected' is just for summary.
        // Let's keep a simplified history fetch just for the summary stats.
        final history = await widget.apiService.getCollectionHistory(token);
        final today = DateTime.now();

        final dailyCollections = history.where((c) {
          final dateStr = c['time'] ?? c['created_at'];
          if (dateStr == null) return false;
          try {
            final date = DateTime.parse(dateStr).toLocal();
            return date.year == today.year && date.month == today.month && date.day == today.day && c['status'] != 'rejected';
          } catch(e) { return false; }
        }).toList();

        for (var c in dailyCollections) {
          final amt = (c['amount'] ?? 0).toDouble();
          collected += amt;
          if (c['payment_mode'] == 'cash') cash += amt;
          if (c['payment_mode'] == 'upi') upi += amt;
        }

        // Filter out customers already in the line
        final allCusts = await widget.apiService.getCustomers(token);
        final existingIds = custs.map((lc) => lc['id']).toSet();

        if (mounted) {
          setState(() {
            _collectedCustomers = custs.where((c) => c['is_collected_today'] == true).toList();
            _pendingCustomers = custs.where((c) => c['is_collected_today'] == false).toList();
            _allCustomers = allCusts.where((c) => !existingIds.contains(c['id'])).toList();
            _totalCollected = collected;
            _totalCash = cash;
            _totalUpi = upi;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('AgentLines _fetchData error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _optimizeRoute() async {
    setState(() => _isLoading = true);
    // 1. Get current location (Heuristic coordinates for demo)
    double lat = 12.9716; 
    double lng = 77.5946;
    
    final token = await widget.storage.read(key: 'jwt_token');
    if (token != null) {
      final optimized = await widget.apiService.optimizeRoute(widget.line['id'], lat, lng, token);
      if (mounted) {
        setState(() {
          // Re-map pending customers based on AI priority
          final collectedIds = _collectedCustomers.map((c) => c['id']).toSet();
          _pendingCustomers = optimized.where((c) => !collectedIds.contains(c['id'])).toList();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI: Route prioritized by proximity & risk factor'),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.line['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      _isLoading 
                        ? const Text("Loading...", style: TextStyle(fontSize: 12, color: Colors.white24))
                        : Row(
                            children: [
                              Text(
                                "${_collectedCustomers.length} / ${_pendingCustomers.length + _collectedCustomers.length} COLLECTED",
                                style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              if (widget.line['start_time'] != null && widget.line['end_time'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    "${widget.line['start_time']} - ${widget.line['end_time']}",
                                    style: GoogleFonts.outfit(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _optimizeRoute, 
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF6366F1)),
                  label: Text("AI", style: GoogleFonts.outfit(color: const Color(0xFF6366F1), fontWeight: FontWeight.w900, fontSize: 11)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                  child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white38)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildReportButton(context, Icons.summarize_rounded, "Daily Report", 'daily'),
                const SizedBox(width: 8),
                _buildReportButton(context, Icons.calendar_view_week_rounded, "Weekly Report", 'weekly'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addCustomer,
                  icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.blue),
                  label: const Text("Add Customer", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF334155),
                ),
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                tabs: const [
                  Tab(text: "PENDING"),
                  Tab(text: "PAID"),
                  Tab(text: "STATS"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : TabBarView(
                      children: [
                        _buildCustomerList(_pendingCustomers, true),
                        _buildCustomerList(_collectedCustomers, false),
                        _buildReportTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList(List<dynamic> customers, bool isPending) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.history_rounded, 
              size: 64, 
              color: Colors.grey.withValues(alpha: 0.2)
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? "All collections done!" : "No collections yet",
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final cust = customers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPending ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: (cust['loan_count'] ?? 1) > 1
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${(cust['active_loans'] as List).where((l) => l['is_collected'] == true).length}",
                            style: TextStyle(
                              color: isPending ? AppTheme.primaryColor : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Container(height: 1, width: 20, color: Colors.grey.withValues(alpha: 0.3)),
                          Text(
                            "${cust['loan_count']}",
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      )
                    : Text(
                        (index + 1).toString(),
                        style: GoogleFonts.outfit(
                          color: isPending ? AppTheme.primaryColor : Colors.green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(cust['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
                if ((cust['loan_count'] ?? 0) > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text("${cust['loan_count']} LOANS", style: GoogleFonts.outfit(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
              ],
            ),
            subtitle: Text(cust['area'] ?? 'No Area', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, color: Colors.blue, size: 20),
                  onPressed: () {
                      Navigator.pushNamed(context, '/admin/customer_detail', arguments: cust['id']);
                  },
                ),
                isPending 
                    ? Icon(
                        (cust['loan_count'] ?? 1) > 1 && (cust['active_loans'] as List).any((l) => l['is_collected'] == true)
                          ? Icons.add_circle // Partial icon
                          : Icons.add_circle_outline, 
                        color: AppTheme.primaryColor
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            onTap: isPending ? () {
              // Time Window Check
              final start = widget.line['start_time'];
              final end = widget.line['end_time'];
              bool isWindowOpen = true;

              if (start != null && end != null) {
                final now = DateTime.now();
                final nowStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                if (nowStr.compareTo(start) < 0 || nowStr.compareTo(end) > 0) {
                  isWindowOpen = false;
                }
              }

              if (!isWindowOpen) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${AppLocalizations.of(context).translate('collection_window_closed')}: $start - $end"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context); // Close sheet
              Navigator.pushNamed(context, '/collection_entry', arguments: {
                ...cust,
                'line_id': widget.line['id'],
              });
            } : null,
          ),
        );
      },
    );
  }
  Widget _buildReportTab() {
    final totalCustomers = _pendingCustomers.length + _collectedCustomers.length;
    final paidCount = _collectedCustomers.length;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildSummaryRow("Total Collected", "₹$_totalCollected", icon: Icons.payments_rounded, color: Colors.green),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildSimpleTally("CASH", "₹$_totalCash", Icons.money_rounded, Colors.orangeAccent)),
                    Container(width: 1, height: 40, color: Colors.white10),
                    Expanded(child: _buildSimpleTally("UPI", "₹$_totalUpi", Icons.account_balance_rounded, Colors.indigoAccent)),
                  ],
                ),
                const Divider(height: 24, color: Colors.white10),
                _buildSummaryRow("COVERAGE", "$paidCount / $totalCustomers", icon: Icons.people_rounded, color: Colors.blueAccent),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ROUTE BREAKDOWN", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white24, letterSpacing: 1.5)),
              _buildReportButton(context, Icons.print_rounded, "Print Full PDF", 'daily'),
            ],
          ),
          const SizedBox(height: 12),
          ... [
            ..._collectedCustomers.map((c) => _buildReportItem(c, true)),
            ..._pendingCustomers.map((c) => _buildReportItem(c, false)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {IconData? icon, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) Icon(icon, size: 16, color: color ?? Colors.white24),
            if (icon != null) const SizedBox(width: 10),
            Text(label, style: GoogleFonts.outfit(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: color ?? Colors.white)),
      ],
    );
  }

  Widget _buildSimpleTally(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

  Widget _buildReportItem(dynamic cust, bool isPaid) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isPaid) {
            Navigator.pushNamed(context, '/collection_entry', arguments: {
              ...cust as Map<String, dynamic>,
              'line_id': widget.line['id'],
            });
          } else {
            Navigator.pushNamed(context, '/admin/customer_detail', arguments: cust['id']);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: isPaid ? Colors.green : Colors.white10, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(cust['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: isPaid ? FontWeight.bold : FontWeight.normal, color: isPaid ? Colors.white : Colors.white38, fontSize: 14))),
              if (isPaid)
                 Text("₹${cust['amount']}", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
              if (!isPaid)
                 Text("PENDING", style: GoogleFonts.outfit(color: Colors.white10, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCustomer() async {
    String searchQuery = '';
    
    return showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final filtered = _allCustomers.where((c) => 
            c['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
            c['mobile_number'].contains(searchQuery)
          ).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(
              AppLocalizations.of(dialogContext).translate('add_customer'),
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                   TextField(
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(dialogContext).translate('search_users'),
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setDialogState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  AppLocalizations.of(dialogContext).translate('no_customers_found'),
                                  style: GoogleFonts.outfit(color: Colors.white24),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: dialogContext,
                                      builder: (subDialogContext) => const AddCustomerDialog(),
                                    );
                                    if (result == true) {
                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                      _fetchData();
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text("Create New Customer"),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (c, i) => const Divider(),
                            itemBuilder: (c, i) {
                              final cust = filtered[i];
                              return ListTile(
                                title: Text(cust['name']),
                                subtitle: Text(cust['mobile_number'] ?? ''),
                                trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  _submitAddCustomer(cust['id']);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  AppLocalizations.of(dialogContext).translate('cancel'),
                  style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitAddCustomer(int customerId) async {
    setState(() => _isLoading = true);
    final token = await widget.storage.read(key: 'jwt_token');
    if (token != null) {
      final res = await widget.apiService.addCustomerToLine(widget.line['id'], customerId, token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['msg'] ?? 'Added successfully')),
        );
        _fetchData();
      }
    }
  }

  Widget _buildReportButton(BuildContext context, IconData icon, String label, String period) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LineReportScreen(lineId: widget.line['id'], period: period, lineName: widget.line['name'])),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

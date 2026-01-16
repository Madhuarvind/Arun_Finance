import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CashSettlementScreen extends StatefulWidget {
  final bool isTab;
  const CashSettlementScreen({super.key, this.isTab = false});

  @override
  State<CashSettlementScreen> createState() => _CashSettlementScreenState();
}

class _CashSettlementScreenState extends State<CashSettlementScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  List<dynamic> _agents = [];
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchHistory();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = await _apiService.getDailySettlements(token);
        setState(() {
          _agents = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final history = await _apiService.getSettlementHistory(token);
        setState(() {
          _history = history;
        });
      }
    } catch (e) {
      debugPrint("Fetch History Error: $e");
    }
  }

  void _openSettlementDialog(Map<String, dynamic> agent) {
    final physicalCtrl = TextEditingController(text: (agent['physical_cash'] ?? 0).toString());
    final expensesCtrl = TextEditingController(text: (agent['expenses'] ?? 0).toString());
    final notesCtrl = TextEditingController(text: agent['notes'] ?? '');
    
    // Auto-fill physical with system if pending (convenience)
    if (agent['status'] == 'pending' && physicalCtrl.text == "0") {
       // physicalCtrl.text = agent['system_cash'].toString();
       physicalCtrl.text = ""; // Force them to type it? Or 0. Let's keep empty/0 to force count.
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double physical = double.tryParse(physicalCtrl.text) ?? 0;
          double expense = double.tryParse(expensesCtrl.text) ?? 0;
          double system = (agent['system_cash'] as num).toDouble();
          double diff = (physical + expense) - system;
          
          Color diffColor = Colors.greenAccent;
          if (diff < 0) diffColor = Colors.redAccent;
          if (diff > 0) diffColor = Colors.blueAccent;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("Settle: ${agent['agent_name']}", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text("System Total (Cash):", style: GoogleFonts.outfit(color: Colors.white70)),
                         Text("₹$system", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 20),
                   _buildTextField("Physical Cash Received", physicalCtrl, setDialogState),
                   const SizedBox(height: 12),
                   _buildTextField("Expenses (Snacks/Petrol)", expensesCtrl, setDialogState),
                   const SizedBox(height: 12),
                   TextField(
                     controller: notesCtrl,
                     style: GoogleFonts.outfit(color: Colors.white),
                     decoration: InputDecoration(
                       labelText: "Notes",
                       labelStyle: const TextStyle(color: Colors.white54),
                       filled: true,
                       fillColor: Colors.white.withValues(alpha: 0.05),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                     ),
                   ),
                   const SizedBox(height: 24),
                   Divider(color: Colors.white.withValues(alpha: 0.1)),
                   const SizedBox(height: 12),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text("Difference:", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                       Text(
                         "₹${diff.toStringAsFixed(2)}", 
                         style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: diffColor)
                       ),
                     ],
                   ),
                   if (diff != 0)
                     Padding(
                       padding: const EdgeInsets.only(top: 8.0),
                       child: Text(
                         diff < 0 ? "Shortage of ₹${diff.abs().toStringAsFixed(2)}" : "Excess of ₹${diff.abs().toStringAsFixed(2)}",
                         style: GoogleFonts.outfit(color: diffColor, fontSize: 12, fontWeight: FontWeight.bold),
                       ),
                     )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: Text("CANCEL", style: GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.bold))
              ),
              ElevatedButton(
                onPressed: () async {
                   final token = await _storage.read(key: 'jwt_token');
                   if (token != null) {
                     await _apiService.verifySettlement({
                       'agent_id': agent['agent_id'],
                       'physical_cash': physical,
                       'expenses': expense,
                       'notes': notesCtrl.text
                     }, token);
                     if (context.mounted) Navigator.pop(context);
                     _fetchData();
                   }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text("VERIFY & SAVE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, StateSetter setState) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor)),
      ),
      onChanged: (v) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shared Gradient background
    final gradient = const BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
      ),
    );

    if (widget.isTab) {
      return DefaultTabController(
        length: 2,
        child: Container(
          decoration: gradient,
          child: Column(
            children: [
              Container(
                color: Colors.transparent,
                child: TabBar(
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: const [
                    Tab(text: "Pending / Today"),
                    Tab(text: "History"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPendingList(),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('Daily Cash Settlement', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
               Tab(text: "Pending / Today"),
               Tab(text: "History"),
            ],
          ),
        ),
        body: Container(
          decoration: gradient,
          child: TabBarView(
            children: [
               _buildPendingList(),
               _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    if (_agents.isEmpty) return Center(child: Text("No active agents found", style: GoogleFonts.outfit(color: Colors.white70)));
    final pendingAgents = _agents; 
    
    if (pendingAgents.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.check_circle_outline, size: 64, color: Colors.greenAccent.withValues(alpha: 0.5)),
             const SizedBox(height: 16),
             Text("All Settled!", style: GoogleFonts.outfit(fontSize: 18, color: Colors.white54)),
           ],
         ),
       );
    }

    return ListView.builder(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
            itemCount: pendingAgents.length,
            itemBuilder: (ctx, i) {
              final agent = pendingAgents[i];
              final bool isVerified = agent['status'] == 'verified';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: InkWell(
                  onTap: () => _openSettlementDialog(agent),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  child: Text(agent['agent_name'][0].toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(agent['agent_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    if (isVerified)
                                      const Text("Verified", style: TextStyle(color: Colors.greenAccent, fontSize: 12))
                                    else
                                      const Text("Pending", style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("System: ₹${agent['system_cash']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                                if (isVerified)
                                  Text("Diff: ₹${agent['difference']}", 
                                    style: GoogleFonts.outfit(
                                      color: (agent['difference'] as num) < 0 ? Colors.redAccent : Colors.greenAccent, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12
                                    )
                                  ),
                              ],
                            )
                          ],
                        ),
                        if (isVerified) ...[
                          Divider(color: Colors.white.withValues(alpha: 0.1)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Handover: ₹${agent['physical_cash']}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
                              Text("Exp: ₹${agent['expenses']}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text("No past settlements found", style: GoogleFonts.outfit(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final item = _history[i];
        final diff = (item['difference'] as num).toDouble();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['agent_name'] ?? 'Agent', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      Text(item['date'] ?? '', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: diff == 0 ? Colors.green.withValues(alpha: 0.2) : (diff < 0 ? Colors.red.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "₹$diff",
                      style: GoogleFonts.outfit(
                        color: diff == 0 ? Colors.greenAccent : (diff < 0 ? Colors.redAccent : Colors.blueAccent),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildHistItem("System", "₹${item['system_cash']}"),
                   _buildHistItem("Physical", "₹${item['physical_cash']}"),
                   _buildHistItem("Expenses", "₹${item['expenses']}"),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'edit_customer_screen.dart';
import 'add_loan_screen.dart';
import 'emi_schedule_screen.dart';
import 'loan_documents_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _riskAnalysis;
  Map<String, dynamic>? _behaviorAnalysis;
  List<dynamic> _audioNotes = [];
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final data = await _apiService.getCustomerDetail(widget.customerId, token);
        final role = await _storage.read(key: 'user_role');
        final risk = await _apiService.getRiskScore(widget.customerId, token);
        final behavior = await _apiService.getCustomerBehaviorAnalytics(widget.customerId, token);
        final audio = await _apiService.getAudioHistory(widget.customerId, token);
        if (mounted) {
          setState(() {
            _customer = data;
            _userRole = role;
            _riskAnalysis = risk;
            _behaviorAnalysis = behavior;
            _audioNotes = audio;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Customer Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
               if (_customer != null) {
                 final result = await Navigator.push(
                   context,
                   MaterialPageRoute(builder: (_) => EditCustomerScreen(customer: _customer!)),
                 );
                 if (result == true) {
                   _fetchDetails();
                 }
               }
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _customer == null 
          ? const Center(child: Text("Error loading profile"))
          : RefreshIndicator(
              onRefresh: _fetchDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                   // Profile Header
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: Colors.white.withValues(alpha: 0.05),
                       borderRadius: BorderRadius.circular(32),
                       border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                     ),
                     child: Column(
                       children: [
                         Container(
                           width: 80,
                           height: 80,
                           decoration: BoxDecoration(
                             color: Colors.white.withValues(alpha: 0.05),
                             shape: BoxShape.circle,
                           ),
                           child: const Icon(Icons.person_rounded, size: 40, color: Colors.white54),
                         ),
                         const SizedBox(height: 16),
                         Text(
                           _customer!['name'],
                           style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                         ),
                         Text(
                           _customer!['customer_id'] ?? 'No ID',
                           style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, letterSpacing: 1),
                         ),
                         const SizedBox(height: 16),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             _buildStatusBadge(_customer!['status']),
                             if (_customer!['is_locked'] == true) ...[
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: Colors.red.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(20),
                                   border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                 ),
                                 child: Text('LOCKED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 0.5)),
                               ),
                             ],
                           ],
                         ),
                         const SizedBox(height: 12),
                         Text('Version: ${_customer!['version'] ?? 1}', 
                           style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 20),
                   
                   // Admin Status Change
                   if (_isAdmin()) ...[
                     Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: Colors.white.withValues(alpha: 0.05),
                         borderRadius: BorderRadius.circular(24),
                         border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text('ADMIN CONTROLS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white38, letterSpacing: 1.2)),
                           const SizedBox(height: 16),
                           Row(
                             children: [
                               Expanded(
                                 child: ElevatedButton.icon(
                                   onPressed: () => _showStatusChangeDialog(),
                                   icon: const Icon(Icons.sync_alt, size: 18),
                                   label: const Text('STATUS'),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.orange.withValues(alpha: 0.2),
                                     foregroundColor: Colors.orange,
                                     elevation: 0,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                   ),
                                 ),
                               ),
                               const SizedBox(width: 10),
                               Expanded(
                                 child: ElevatedButton.icon(
                                   onPressed: () => _toggleLock(),
                                   icon: Icon(_customer!['is_locked'] == true ? Icons.lock_open : Icons.lock, size: 18),
                                   label: Text(_customer!['is_locked'] == true ? 'UNLOCK' : 'LOCK'),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: (_customer!['is_locked'] == true ? Colors.green : Colors.red).withValues(alpha: 0.2),
                                     foregroundColor: _customer!['is_locked'] == true ? Colors.green : Colors.red,
                                     elevation: 0,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                   ),
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 12),
                           SizedBox(
                             width: double.infinity,
                             child: OutlinedButton.icon(
                               onPressed: () => _showPassbookQR(),
                               icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                               label: Text("SHOW PASSBOOK QR".toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                               style: OutlinedButton.styleFrom(
                                 side: const BorderSide(color: AppTheme.primaryColor),
                                 foregroundColor: AppTheme.primaryColor,
                                 padding: const EdgeInsets.symmetric(vertical: 16),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 20),
                    ],
                    
                    if (_riskAnalysis != null) ...[
                      _buildRiskCard(),
                      const SizedBox(height: 20),
                    ],

                    if (_behaviorAnalysis != null) ...[
                      _buildBehaviorCard(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Loan Section
                    _buildLoanSection(),
                    const SizedBox(height: 20),

                    // AI Voice Notes Section
                    if (_audioNotes.isNotEmpty) ...[
                      _buildAudioNotesSection(),
                      const SizedBox(height: 20),
                    ],

                    // Info Cards
                   _buildInfoCard(Icons.phone, "Mobile", _customer!['mobile']),
                   _buildInfoCard(Icons.map, "Area", _customer!['area'] ?? "N/A"),
                   _buildInfoCard(Icons.home, "Address", _customer!['address'] ?? "N/A"),
                   _buildInfoCard(Icons.badge, "ID Proof", _customer!['id_proof_number'] ?? "N/A"),
                   if (_customer!['latitude'] != null && _customer!['longitude'] != null)
                     _buildInfoCard(Icons.location_on, "GPS Location", 
                       "Lat: ${_customer!['latitude'].toStringAsFixed(4)}, Long: ${_customer!['longitude'].toStringAsFixed(4)}"),

                   const SizedBox(height: 30),
                   
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                           final result = await Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => AddLoanScreen(customerId: widget.customerId, customerName: _customer!['name']))
                           );
                           if (result == true) {
                             _fetchDetails();
                           }
                        },
                        icon: const Icon(Icons.monetization_on_outlined, color: Colors.black),
                        label: Text("PROVIDE LOAN", style: GoogleFonts.outfit(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
    );
  }



  Widget _buildRiskCard() {
    final score = _riskAnalysis!['risk_score'] ?? 0;
    final level = _riskAnalysis!['risk_level'] ?? 'N/A';
    final insights = List<String>.from(_riskAnalysis!['insights'] ?? []);
    
    Color riskColor = Colors.green;
    if (level == 'MEDIUM') riskColor = Colors.orange;
    if (level == 'HIGH') riskColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: riskColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: riskColor),
                  const SizedBox(width: 8),
                  Text("AI RISK ANALYSIS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: riskColor, letterSpacing: 1.2, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: riskColor, borderRadius: BorderRadius.circular(20)),
                child: Text(level, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                "$score",
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: riskColor),
              ),
              const SizedBox(width: 4),
              Text("/100", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white24)),
              const Spacer(),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  color: riskColor,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: riskColor),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(insight, style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70))),
              ],
            ),
          )),
        ],
      ),
    );
  }



  Widget _buildBehaviorCard() {
    final segment = _behaviorAnalysis!['segment'] ?? 'N/A';
    final reliability = _behaviorAnalysis!['reliability_score'] ?? 0;
    final suggestion = _behaviorAnalysis!['loan_limit_suggestion'] ?? 0;
    final observations = List<String>.from(_behaviorAnalysis!['observations'] ?? []);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue),
              const SizedBox(width: 8),
              Text("ML BEHAVIORAL ANALYSIS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 1.2, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                child: Text(segment, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("RELIABILITY", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text("$reliability%", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SUGGESTED LIMIT", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text("₹$suggestion", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("ML INSIGHTS", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...observations.map((obs) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text("• $obs", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
          )),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ],
            ),
          )
        ],
      ),
    );
  }

  bool _isAdmin() {
    return _userRole == 'admin'; 
  }

  Widget _buildStatusBadge(String status) {
    final Map<String, Color> colors = {
      'created': Colors.orange,
      'verified': Colors.blue,
      'active': Colors.green,
      'inactive': Colors.grey,
      'closed': Colors.red,
    };
    
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  Future<void> _showStatusChangeDialog() async {
    final statuses = ['created', 'verified', 'active', 'inactive', 'closed'];
    final currentStatus = _customer!['status'];
    
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Change Customer Status', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) {
            String? selectedStatus = currentStatus;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: statuses.map((s) => RadioListTile<String>(
                title: Text(s.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
                value: s,
                // ignore: deprecated_member_use
                groupValue: selectedStatus,
                activeColor: AppTheme.primaryColor,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) {
                    setState(() => selectedStatus = val);
                    Navigator.pop(context, val);
                  }
                },
              )).toList(),
            );
          },
        ),
      ),
    );
    
    if (selected != null && selected != currentStatus) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        try {
          final response = await _apiService.updateCustomerStatus(widget.customerId, selected, token);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['msg'] ?? 'Status updated'), backgroundColor: Colors.green),
            );
            _fetchDetails();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleLock() async {
    final isLocked = _customer!['is_locked'] == true;
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        await _apiService.toggleCustomerLock(widget.customerId, !isLocked, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isLocked ? 'Customer unlocked' : 'Customer locked'), backgroundColor: Colors.green),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildLoanSection() {
    final loan = _customer!['active_loan'];
    if (loan == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.monetization_on_outlined, color: Colors.white10, size: 48),
            const SizedBox(height: 16),
            Text("NO ACTIVE LOAN", style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
            const SizedBox(height: 4),
            Text("This customer has no active borrowing", style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan['status'].toString().toUpperCase() == 'ACTIVE' ? "ACTIVE LOAN" : "APPROVED LOAN", 
                    style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)
                  ),
                  Text(loan['loan_id'] ?? "ID Pending", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  loan['status'].toString().toLowerCase() == 'active' 
                      ? Icons.verified_user_rounded 
                      : (loan['status'].toString().toLowerCase() == 'approved' 
                          ? Icons.hourglass_top_rounded 
                          : Icons.edit_note_rounded), 
                   color: Colors.white70, 
                   size: 24
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _loanStats("Principal", "₹${loan['amount']}"),
              if (loan['status'].toString().toLowerCase() == 'created')
                _loanStats("Status", "DRAFT")
              else ...[
                _loanStats("Interest", "${loan['interest_rate']}%"),
                _loanStats("Tenure", "${loan['tenure']} ${loan['tenure_unit']}"),
              ]
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (loan['status'].toString().toLowerCase() == 'approved')
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      onPressed: () => _activateLoan(loan['id']),
                      child: const Text("ACTIVATE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ),
                ),
              if (loan['status'].toString().toLowerCase() == 'created' && _isAdmin())
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      onPressed: () => _approveLoan(loan['id']),
                      child: const Text("APPROVE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ),
                ),
              if (loan['status'].toString().toLowerCase() == 'active')
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _forecloseLoan(loan['id']),
                      child: const Text("SETTLE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ),
                ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => _viewSchedule(loan['id']),
                  child: const Text("EMI", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  onPressed: () => _viewDocuments(loan['id'], loan['loan_id']),
                  child: const Text("DOCS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _approveLoan(int loanId) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final result = await _apiService.approveLoan(loanId, {}, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['msg'] ?? 'Loan Approved!'), backgroundColor: Colors.green),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _loanStats(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  void _viewSchedule(int loanId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EMIScheduleScreen(loanId: loanId)),
    );
  }

  void _viewDocuments(int loanId, String loanNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoanDocumentsScreen(loanId: loanId, loanNumber: loanNumber)),
    );
  }

  Future<void> _activateLoan(int loanId) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        await _apiService.activateLoan(loanId, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loan Activated successfully!'), backgroundColor: Colors.green),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _forecloseLoan(int loanId) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Foreclose / Settle Loan", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Text("Enter the final settlement amount received from customer.", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl, 
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Settlement Amount (₹)", 
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ), 
              keyboardType: TextInputType.number
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl, 
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Reason", 
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              )
            ),
          ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("CANCEL", style: GoogleFonts.outfit(color: Colors.white38))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ), 
            child: const Text("SETTLE")
          ),
        ],
      )
    );
    
    if (confirmed == true && amountCtrl.text.isNotEmpty) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
          try {
            final res = await _apiService.forecloseLoan(loanId, double.tryParse(amountCtrl.text) ?? 0.0, reasonCtrl.text, token);
            if (mounted) {
               if (res.containsKey('msg') && res['msg'].toString().contains('successfully')) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan Foreclosed!"), backgroundColor: Colors.green));
                 _fetchDetails();
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['msg']}"), backgroundColor: Colors.red));
               }
            }
          } catch (e) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
          }
      }
    }
  }

  void _showPassbookQR() {
    if (_customer == null) return;
    _displayQRDialog(_customer!['customer_id'] ?? 'N/A');
  }

  void _displayQRDialog(String customerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Center(child: Text("Customer Passbook", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Scan this permanent QR to view customer passbook", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: customerId,
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 24),
              Text(_customer!['name'], style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("ID: $customerId", style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.primaryColor, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text("Unified QR for ID Card & Passbook".toUpperCase(), style: GoogleFonts.outfit(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("CLOSE", style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  Widget _buildAudioNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("AI FIELD NOTES", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text("${_audioNotes.length} RECORDED", style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _audioNotes.length,
            itemBuilder: (context, index) {
              final note = _audioNotes[index];
              final sentiment = note['sentiment']?.toString().toLowerCase() ?? 'neutral';
              final color = _getSentimentColor(sentiment);
              
              return GestureDetector(
                onTap: () => _showTranscriptionDetail(note),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getSentimentIcon(sentiment), color: color, size: 16),
                          const SizedBox(width: 8),
                          Text(sentiment.toUpperCase(), style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const Spacer(),
                          Text(_formatAudioDate(note['created_at']), style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Text(
                          note['transcription'] ?? "No transcription available",
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTranscriptionDetail(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getSentimentIcon(note['sentiment']), color: _getSentimentColor(note['sentiment']), size: 24),
                const SizedBox(width: 12),
                Text("Field Note Detail", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatAudioDate(note['created_at'], full: true), style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 24),
            Text(
              note['transcription'] ?? "No transcription available",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("CLOSE"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSentimentColor(String? sentiment) {
    switch (sentiment?.toLowerCase()) {
      case 'distressed': return Colors.redAccent;
      case 'evasive': return Colors.orangeAccent;
      case 'positive': return Colors.greenAccent;
      default: return Colors.blueAccent;
    }
  }

  IconData _getSentimentIcon(String? sentiment) {
    switch (sentiment?.toLowerCase()) {
      case 'distressed': return Icons.mood_bad_rounded;
      case 'evasive': return Icons.warning_amber_rounded;
      case 'positive': return Icons.sentiment_satisfied_alt_rounded;
      default: return Icons.notes_rounded;
    }
  }

  String _formatAudioDate(String? iso, {bool full = false}) {
    if (iso == null) return "N/A";
    try {
      final dt = DateTime.parse(iso).toLocal();
      if (full) return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      return DateFormat('dd MMM').format(dt);
    } catch (e) {
      return "N/A";
    }
  }
}

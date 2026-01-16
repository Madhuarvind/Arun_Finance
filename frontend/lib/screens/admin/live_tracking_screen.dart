import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _agents = [];
  bool _isLoading = true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchLocations(isAuto: true);
    });
  }

  Future<void> _fetchLocations({bool isAuto = false}) async {
    if (!isAuto) setState(() => _isLoading = true);
    final token = await _apiService.getToken();
    if (token != null) {
      final data = await _apiService.getFieldAgentsLocation(token);
      if (mounted) {
        setState(() {
          _agents = data;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMap(double? lat, double? lng, String name) async {
    if (lat == null || lng == null) return;
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Google Maps")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Live Field Tracking", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _fetchLocations, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
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
          : _agents.isEmpty 
            ? const Center(child: Text("No agents found", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
                itemCount: _agents.length,
                itemBuilder: (context, index) {
                  final agent = _agents[index];
                  final status = agent['status'] ?? 'off_duty';
                  final isOnDuty = status == 'on_duty';
                  final lastUpdate = agent['last_update'] != null 
                      ? DateFormat('hh:mm a').format(DateTime.parse(agent['last_update']).toLocal())
                      : 'Never';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isOnDuty ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_pin_circle_rounded, 
                                color: isOnDuty ? Colors.greenAccent : Colors.white54,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(agent['name'] ?? 'Agent', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(agent['mobile'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOnDuty ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOnDuty ? "ONLINE" : "OFFLINE",
                                style: TextStyle(
                                  color: isOnDuty ? Colors.greenAccent : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniInfo("Last Update", lastUpdate),
                            _buildMiniInfo("Activity", (agent['activity'] ?? 'idle').toString().toUpperCase()),
                          ],
                        ),
                        Divider(height: 32, color: Colors.white.withValues(alpha: 0.1)),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: agent['latitude'] != null
                                        ? () => _openMap(agent['latitude'], agent['longitude'], agent['name'])
                                        : null,
                                    icon: const Icon(Icons.map_rounded),
                                    label: Text(agent['latitude'] != null ? "VIEW ON MAP" : "GPS NOT READY"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                  if (agent['latitude'] == null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        "Waiting for active sync...",
                                        style: TextStyle(fontSize: 10, color: Colors.white30, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }
}

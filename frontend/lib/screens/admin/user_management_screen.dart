import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'user_detail_screen.dart';
import 'add_user_wizard_screen.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'all';
  String _filterStatus = 'all'; // all, active, inactive, locked
  String _filterBiometric = 'all'; // all, registered, not_registered
  String _sortBy = 'name'; // name, role, created
  bool _sortAscending = true;
  bool _selectionMode = false;
  Set<int> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (_users.isEmpty) {

      setState(() => _isLoading = true);

    }
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getUsers(token);
      setState(() {
        _users = result;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final username = (user['username'] ?? '').toString().toLowerCase();
        final mobile = (user['mobile_number'] ?? '').toString();
        final matchesSearch = name.contains(_searchQuery.toLowerCase()) || 
                             username.contains(_searchQuery.toLowerCase()) ||
                             mobile.contains(_searchQuery);
        
        final matchesRole = _filterRole == 'all' || user['role'] == _filterRole;
        
        bool matchesStatus = true;
        if (_filterStatus == 'active') {
          matchesStatus = user['is_active'] == true;
        } else if (_filterStatus == 'inactive') {
          matchesStatus = user['is_active'] == false;
        } else {

          if (_filterStatus == 'locked') matchesStatus = user['is_locked'] == true;

        }
        
        bool matchesBiometric = true;
        if (_filterBiometric == 'registered') {
          matchesBiometric = user['has_device_bound'] == true;
        } else if (_filterBiometric == 'not_registered') {
          matchesBiometric = user['has_device_bound'] != true;
        }
        
        return matchesSearch && matchesRole && matchesStatus && matchesBiometric;
      }).toList();
      
      // Apply sorting
      _filteredUsers.sort((a, b) {
        int comparison = 0;
        if (_sortBy == 'name') {
          comparison = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        } else if (_sortBy == 'role') {
          comparison = (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString());
        } else if (_sortBy == 'created') {
          comparison = (a['id'] ?? 0).compareTo(b['id'] ?? 0);
        }
        return _sortAscending ? comparison : -comparison;
      });
      
      // Reset to first page after filtering
    });
  }

  Future<void> _toggleStatus(int userId, bool currentStatus) async {
    // OPTIMISTIC UPDATE
    setState(() {
      final idx = _users.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        _users[idx]['is_active'] = !currentStatus;
      }
      _applyFilters();
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.patchUserStatus(userId, {'is_active': !currentStatus}, token);
      
      if (result['msg'] == 'Status updated') {
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate(!currentStatus ? 'user_activated' : 'user_deactivated'))),
          );
        }
      } else {
        // REVERT OPTIMISTIC UPDATE
        setState(() {
          final idx = _users.indexWhere((u) => u['id'] == userId);
          if (idx != -1) {
            _users[idx]['is_active'] = currentStatus;
          }
          _applyFilters();
        });
        
        if (mounted) {
          final errorMsg = result['msg'] == 'connection_failed' 
            ? context.translate('connection_failed') 
            : context.translate('error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
          );
        }
        _fetchUsers(); 
      }
    }
  }

  void _toggleSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        if (_selectedUserIds.isEmpty) {

          _selectionMode = false;

        }
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedUserIds.length == _filteredUsers.length) {
        _selectedUserIds.clear();
        _selectionMode = false;
      } else {
        _selectedUserIds = _filteredUsers.map((u) => u['id'] as int).toSet();
        _selectionMode = true;
      }
    });
  }

  Future<void> _bulkActivate() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {

      return;

    }
    
    for (int userId in _selectedUserIds) {
      await _apiService.patchUserStatus(userId, {'is_active': true}, token);
    }
    
    setState(() {
      _selectedUserIds.clear();
      _selectionMode = false;
    });
    _fetchUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Users activated successfully')),
      );
    }
  }

  Future<void> _bulkDeactivate() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {

      return;

    }
    
    for (int userId in _selectedUserIds) {
      await _apiService.patchUserStatus(userId, {'is_active': false}, token);
    }
    
    setState(() {
      _selectedUserIds.clear();
      _selectionMode = false;
    });
    _fetchUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Users deactivated successfully')),
      );
    }
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Users'),
        content: Text('Are you sure you want to delete ${_selectedUserIds.length} users? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {


      return;


    }

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {

      return;

    }
    
    for (int userId in _selectedUserIds) {
      await _apiService.deleteUser(userId, token);
    }
    
    setState(() {
      _selectedUserIds.clear();
      _selectionMode = false;
    });
    _fetchUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Users deleted successfully')),
      );
    }
  }

  Future<void> _exportToCSV() async {
    try {
      List<List<dynamic>> rows = [];
      // Header row
      rows.add(['ID', 'Name', 'Username', 'Mobile', 'Role', 'Area', 'Active', 'Locked', 'Has Biometric']);
      
      // Data rows
      for (var user in _filteredUsers) {
        rows.add([
          user['id'],
          user['name'] ?? '',
          user['username'] ?? '',
          user['mobile_number'] ?? '',
          user['role'] ?? '',
          user['area'] ?? '',
          user['is_active'] == true ? 'Yes' : 'No',
          user['is_locked'] == true ? 'Yes' : 'No',
          user['has_device_bound'] == true ? 'Yes' : 'No',
        ]);
      }
      
      String csv = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csv);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'users_export_${DateTime.now().millisecondsSinceEpoch}.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile/Desktop implementation
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/users_export_${DateTime.now().millisecondsSinceEpoch}.csv";
        final file = io.File(path);
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV saved to: $path'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  // In a real app, you might use 'open_file' package here
                },
              ),
            ),
          );
        }
      }
      
      if (mounted && kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('success')}! Downloaded ${_filteredUsers.length} ${context.translate('users')}'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: _selectionMode
              ? Text(
                  '${_selectedUserIds.length} ${context.translate('selected')}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                )
              : Text(
                  context.translate('user_management'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
            actions: _selectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.done_all),
                    onPressed: _selectAll,
                    tooltip: context.translate('select_all'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedUserIds.clear();
                        _selectionMode = false;
                      });
                    },
                    tooltip: context.translate('cancel'),
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: _exportToCSV,
                    tooltip: context.translate('export_csv'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.checklist_rtl_rounded),
                    onPressed: () {
                      setState(() {
                        _selectionMode = true;
                      });
                    },
                    tooltip: context.translate('select_mode'),
                  ),
                ],
          ),
          body: Column(
            children: [
              // Statistics Dashboard
              if (!_isLoading) _buildStatsDashboard(),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppTheme.secondaryTextColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            _searchQuery = value;
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            hintText: context.translate('search_users'),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showFilterSheet(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_filterRole != 'all' || _filterStatus != 'all' || _filterBiometric != 'all') 
                              ? AppTheme.primaryColor.withValues(alpha: 0.1) 
                              : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune_rounded, 
                            color: (_filterRole != 'all' || _filterStatus != 'all' || _filterBiometric != 'all') 
                              ? AppTheme.primaryColor 
                              : AppTheme.secondaryTextColor.withValues(alpha: 0.5), 
                            size: 20
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Sort and results count bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${_filteredUsers.length} ${context.translate('users')}',
                      style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                          _applyFilters();
                        });
                      },
                      child: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 18,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      icon: Icon(Icons.sort_rounded, size: 18, color: AppTheme.secondaryTextColor),
                      style: TextStyle(color: AppTheme.textColor, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                        DropdownMenuItem(value: 'role', child: Text('Role')),
                        DropdownMenuItem(value: 'created', child: Text('Created')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortBy = value;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredUsers.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final bool isActive = user['is_active'] ?? true;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedUserIds.contains(user['id']) 
                            ? AppTheme.primaryColor.withValues(alpha: 0.1) 
                            : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _selectedUserIds.contains(user['id']) 
                              ? AppTheme.primaryColor 
                              : Colors.black.withValues(alpha: 0.04),
                            width: _selectedUserIds.contains(user['id']) ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () async {
                            if (_selectionMode) {
                              _toggleSelection(user['id']);
                            } else {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDetailScreen(userId: user['id']),
                                ),
                              );
                              if (result == true) {

                                _fetchUsers();

                              }
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _selectionMode = true;
                              _toggleSelection(user['id']);
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: _selectionMode
                            ? Checkbox(
                                value: _selectedUserIds.contains(user['id']),
                                onChanged: (_) => _toggleSelection(user['id']),
                                activeColor: AppTheme.primaryColor,
                              )
                            : Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              user['role'] == 'admin' ? Icons.shield_outlined : Icons.person_outline_rounded,
                              color: isActive ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            user['name'] ?? user['username'] ?? 'Unknown User',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textColor),
                          ),
                          subtitle: Text(
                            '${user['area'] ?? context.translate('no_area')} • ${user['mobile_number'] ?? 'N/A'}',
                            style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_selectionMode)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: AppTheme.secondaryTextColor.withValues(alpha: 0.5)),
                                  onSelected: (value) {
                                    if (value == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserDetailScreen(userId: user['id']),
                                        ),
                                      ).then((_) => _fetchUsers());
                                    } else if (value == 'toggle') {
                                      _toggleStatus(user['id'], isActive);
                                    } else if (value == 'delete') {
                                      _selectedUserIds = {user['id']};
                                      _bulkDelete();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.visibility_outlined, size: 20),
                                          const SizedBox(width: 12),
                                          Text(context.translate('view_details')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Row(
                                        children: [
                                          Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 20),
                                          const SizedBox(width: 12),
                                          Text(isActive ? context.translate('deactivate') : context.translate('activate')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          const SizedBox(width: 12),
                                          Text(context.translate('delete'), style: const TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              if (!_selectionMode) const SizedBox(width: 4),
                              Switch(
                                value: isActive,
                                activeThumbColor: AppTheme.primaryColor,
                                onChanged: (value) => _toggleStatus(user['id'], isActive),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          floatingActionButton: _selectedUserIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.green),
                            ),
                            title: const Text('Activate Selected'),
                            onTap: () {
                              Navigator.pop(context);
                              _bulkActivate();
                            },
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.cancel, color: Colors.orange),
                            ),
                            title: const Text('Deactivate Selected'),
                            onTap: () {
                              Navigator.pop(context);
                              _bulkDeactivate();
                            },
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
                            ),
                            title: Text('Delete Selected', style: TextStyle(color: AppTheme.errorColor)),
                            onTap: () {
                              Navigator.pop(context);
                              _bulkDelete();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.more_horiz),
                label: Text('${_selectedUserIds.length} ${context.translate('actions')}'),
                backgroundColor: AppTheme.primaryColor,
              )
            : FloatingActionButton.extended(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddUserWizardScreen()),
                  );
                  if (result == true) {

                    _fetchUsers();

                  }
                },
                icon: const Icon(Icons.person_add_rounded),
                label: Text(context.translate('add_worker')),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
        );
      },
    );
  }

  Widget _buildStatsDashboard() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u['is_active'] == true).length;
    final lockedUsers = _users.where((u) => u['is_locked'] == true).length;
    final withBiometric = _users.where((u) => u['has_device_bound'] == true).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overview',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryTextColor),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/admin/analytics'),
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: Text(context.translate('performance_analytics'), style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _buildStatCard(totalUsers.toString(), context.translate('total'), Icons.people_outline, AppTheme.primaryColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(activeUsers.toString(), context.translate('active'), Icons.check_circle_outline, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(lockedUsers.toString(), context.translate('locked'), Icons.lock_outline, AppTheme.errorColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(withBiometric.toString(), context.translate('bio'), Icons.fingerprint, Colors.blueAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String count, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            count,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Role Filter
            Text('Role', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip(context.translate('all'), _filterRole == 'all', () => setState(() { _filterRole = 'all'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('admin'), _filterRole == 'admin', () => setState(() { _filterRole = 'admin'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('field_agent'), _filterRole == 'field_agent', () => setState(() { _filterRole = 'field_agent'; _applyFilters(); Navigator.pop(context); })),
              ],
            ),
            const SizedBox(height: 20),
            
            // Status Filter
            Text('Status', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip(context.translate('all'), _filterStatus == 'all', () => setState(() { _filterStatus = 'all'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('active'), _filterStatus == 'active', () => setState(() { _filterStatus = 'active'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('inactive'), _filterStatus == 'inactive', () => setState(() { _filterStatus = 'inactive'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('locked'), _filterStatus == 'locked', () => setState(() { _filterStatus = 'locked'; _applyFilters(); Navigator.pop(context); })),
              ],
            ),
            const SizedBox(height: 20),
            
            // Biometric Filter
            Text('Biometric', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip(context.translate('all'), _filterBiometric == 'all', () => setState(() { _filterBiometric = 'all'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('registered'), _filterBiometric == 'registered', () => setState(() { _filterBiometric = 'registered'; _applyFilters(); Navigator.pop(context); })),
                _buildFilterChip(context.translate('not_registered'), _filterBiometric == 'not_registered', () => setState(() { _filterBiometric = 'not_registered'; _applyFilters(); Navigator.pop(context); })),
              ],
            ),
            const SizedBox(height: 20),
            
            // Clear Filters Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _filterRole = 'all';
                    _filterStatus = 'all';
                    _filterBiometric = 'all';
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear All Filters'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.black.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.black : AppTheme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:elmasa/services/security_service.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:elmasa/models/workspace.dart';
import 'package:elmasa/screens/simple_scanner_screen.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:elmasa/services/api_service.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:elmasa/screens/courses_screen.dart';
import 'package:elmasa/screens/wallet_screen.dart';
import 'package:elmasa/screens/profile_screen.dart';
import 'package:elmasa/widgets/course_card.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:elmasa/utils/iconly.dart';
import 'package:elmasa/widgets/modern_empty_state_illustration.dart';
import 'package:google_fonts/google_fonts.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _lastWorkspaceId;
  String _walletBalanceStr = "0.00";
  bool _isModalShowing = false;
  late AnimationController _waController;
  String _courseTypeFilter = "ALL";
  int _currentIndex = 0;
  
  List<dynamic> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode && !SecurityService.bypassSecurityChecks && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      try {
        NoScreenshot.instance.screenshotOff();
      } catch (e) {
        debugPrint('Security Error: $e');
      }
    }
    _waController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waController.dispose();
    super.dispose();
  }

  bool _hasFetched = false;
  bool _hasCheckedArgs = false;

  void _navigateToTab(int targetIndex) {
    if (!_pageController.hasClients) return;
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final showWallet = !wp.isGuest && (wp.activeWorkspace?.enablePurchasing ?? true);
    
    int pageIdx = targetIndex;
    if (!showWallet && targetIndex == 3) {
      pageIdx = 2;
    }
    
    _pageController.animateToPage(
      pageIdx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_hasCheckedArgs) {
      _hasCheckedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args.containsKey('tab')) {
          _currentIndex = args['tab'] as int;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentIndex);
            }
          });
        }
      }
    }

    final wp = Provider.of<WorkspaceProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final workspace = wp.activeWorkspace;
    final activeId = workspace?.id;
    
    // Allow guest mode to pass through without redirecting to onboarding
    if (activeId == null && !wp.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/onboarding', 
            (route) => false, 
            arguments: wp.lastErrorMessage
          );
        }
      });
      return;
    }
    
    if (!_hasFetched || _lastWorkspaceId != activeId) {
      _hasFetched = true;
      _lastWorkspaceId = activeId;
      if (workspace != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            theme.setTenant(workspace.theme, themeColor: workspace.themeColor);
            _fetch();
          }
        });
      } else if (wp.isGuest) {
        // Guest mode: fetch public courses without auth
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchGuest();
        });
      }
    }
  }


  /// Redirects guest users to login when they try to access gated content.
  /// Returns true if access is allowed, false if redirected.
  bool _guardContent() {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    if (wp.isGuest) {
      Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
      return false;
    }
    return true;
  }

  Future<void> _fetchGuest() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await wp.getPublicSiteSettings(kSiteHost);
    } catch (e) {
      debugPrint('Failed to fetch guest courses: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  Widget _buildGuestPrompt(
      BuildContext context,
      dynamic lang,
      Color primaryColor,
      Color onSurface,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_outline,
            size: 48,
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            lang.guestPrompt ?? 'Please sign in to continue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  Future<void> _toggleFavorite(Map<String, dynamic> course) async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (wp.isGuest) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(lang.translate('login_required') ?? 'Login Required', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: Text(lang.translate('please_login_to_favorite') ?? 'Please login to save favorite courses.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(lang.translate('cancel') ?? 'Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.pop(c);
                Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false);
              },
              child: Text(lang.translate('login') ?? 'Login', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }
    final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
    if (cid == 0) return;

    final bool newFav = !wp.localFavoriteIds.contains(cid);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(newFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Text(newFav ? (lang.translate('added_to_favorites') ?? 'Added to favorites') : (lang.translate('removed_from_favorites') ?? 'Removed from favorites')),
      ]),
      backgroundColor: newFav ? Colors.green.shade700 : Colors.grey.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));

    try {
      await wp.toggleFavoriteOptimistic(cid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      }
    }
  }


  Future<void> _fetch() async {
    if (!mounted) return;
    
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    // IF WE HAVE CACHED DATA AND IT IS THE SAME WORKSPACE, USE IT IMMEDIATELY
    if (wp.isEagerLoaded && wp.cachedDashboard != null) {
      final cached = wp.cachedDashboard!;
      final balRes = wp.cachedWallet ?? {'balance': '0.00'};
      final meRes = wp.cachedME ?? {'user': {'has_group': true}};
      
      setState(() {
        _dashboardData = Map<String, dynamic>.from(cached);
        _categories = (_dashboardData?['categories'] as List?) ?? [];
        _walletBalanceStr = (meRes['user']?['wallet_balance'] ?? balRes['balance'] ?? "0").toString();
        _isLoading = false;
      });
      
      // CHECK GROUP EVEN IF CACHED
      _checkGroupMembership(meRes);

      // OPTIONAL: RE-FETCH IN BACKGROUND TO KEEP IT FRESH WITHOUT SHOWING LOADER
      _backgroundRefresh();
      return;
    }

    // No cached data — show loading skeleton
    setState(() { _isLoading = true; });
    try {
      final active = wp.activeWorkspace;
      
      // PARALLEL FETCH
      final futures = [
        if (active != null) wp.enrichWorkspace(active.id, context),
        wp.getDashboard(),
        wp.getFavorites(),
        wp.getWalletBalance(),
        wp.getMe(),
        wp.getGroups(),
      ];
      
      final results = await Future.wait(futures);
      final offset = active != null ? 1 : 0;
      
      final data = Map<String, dynamic>.from(results[0 + offset] as Map);
      final favsRes = results[1 + offset] as Map<String, dynamic>;
      final balRes = results[2 + offset] as Map<String, dynamic>;
      final meRes = results[3 + offset] as Map<String, dynamic>;

      if (mounted) {
        setState(() { 
          _dashboardData = data; 
          _categories = (_dashboardData?['categories'] as List?) ?? [];
          _walletBalanceStr = (meRes['user']?['wallet_balance'] ?? balRes['balance'] ?? "0").toString();
          _isLoading = false; 
        });

        _checkGroupMembership(meRes);
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (e is DeviceMismatchException || e.toString().toLowerCase().contains('mismatch device id')) {
        if (mounted) {
           Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false, arguments: 'device_mismatch');
        }
      } else if (e.toString().contains('Session expired')) {
        if (mounted) {
           Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Set<int> _getDescendantCategoryIds(int targetId, List<dynamic> categories) {
    final Set<int> result = {targetId};
    bool addedAny;
    do {
      addedAny = false;
      for (final cat in categories) {
        final catId = int.tryParse(cat['id']?.toString() ?? '') ?? 0;
        final parentId = int.tryParse(cat['parent_id']?.toString() ?? '') ?? 0;
        if (catId != 0 && parentId != 0 && result.contains(parentId)) {
          if (result.add(catId)) {
            addedAny = true;
          }
        }
      }
    } while (addedAny);
    return result;
  }

  Widget _buildCategoryFilters(Color primaryColor, Color onSurface) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          final bool isAll = index == 0;
          final dynamic category = isAll ? null : _categories[index - 1];
          final categoryId = isAll ? null : int.tryParse(category['id']?.toString() ?? '') ?? 0;
          final String title = isAll 
              ? (lang.currentLocale.languageCode == 'ar' ? 'الكل' : 'All') 
              : (category['name']?.toString() ?? category['title']?.toString() ?? '');
          final bool isSelected = isAll ? _selectedCategoryId == null : _selectedCategoryId == categoryId;

          return Padding(
            padding: EdgeInsets.only(
              left: isRTL ? 8 : (isAll ? 0 : 8),
              right: isRTL ? (isAll ? 0 : 8) : 8,
            ),
            child: ChoiceChip(
              label: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : onSurface.withOpacity(0.6),
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: onSurface.withOpacity(0.05),
              showCheckmark: false,
              side: BorderSide(color: isSelected ? Colors.transparent : onSurface.withOpacity(0.1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryId = isAll ? null : categoryId;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkGroupMembership(Map<String, dynamic> meRes) async {
    if (_isModalShowing) return;
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final user = meRes['user'];
    if (user == null) return;

    final hg = user['has_group'];
    final bool hasGroup = hg == true || hg == 1 || hg == 'true' || hg == '1';
    
    if (!hasGroup) {
       final groupsRes = await wp.getGroups();
       final groups = groupsRes['groups'] as List? ?? [];
       if (groups.isNotEmpty) {
          setState(() => _isModalShowing = true);
          await _showMandatoryGroupModal(groups);
          if (mounted) setState(() => _isModalShowing = false);
       }
    }
  }

  void _showCouponModal() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final primary = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          bool isLoading = false;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 24), decoration: BoxDecoration(color: onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.confirmation_num_rounded, color: primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lang.translate('redeem_coupon'), style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(lang.translate('coupon_hint'), style: TextStyle(color: onSurface.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX',
                      filled: true,
                      fillColor: primary.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary, width: 2)),
                      prefixIcon: Icon(Icons.qr_code_rounded, color: primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        setModalState(() => isLoading = true);
                        try {
                          final res = await wp.redeemCoupon(controller.text.trim());
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(res['message'] ?? lang.translate('success')),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                            _fetch();
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                          setModalState(() => isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(lang.translate('confirm') ?? 'Confirm', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: onSurface.withOpacity(0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(lang.translate('or') ?? 'OR', style: TextStyle(color: onSurface.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: onSurface.withOpacity(0.1))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.qr_code_scanner_rounded, color: primary),
                      label: Text(lang.translate('scan_new_code') ?? 'Scan QR Code', style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 16)),
                      onPressed: () async {
                        final code = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (_) => SimpleScannerScreen(title: lang.translate('scan_new_code') ?? 'Scan Code')),
                        );
                        if (code != null && code.isNotEmpty) {
                          controller.text = code;
                          // Auto-submit if scanned
                          if (ctx.mounted) {
                            setModalState(() => isLoading = true);
                            try {
                              final res = await wp.redeemCoupon(code);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(res['message'] ?? lang.translate('success')),
                                  backgroundColor: Colors.green,
                                ));
                                await wp.eagerLoad();
                                _fetch();
                              }
                            } catch (e) {
                              if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                            } finally {
                              if (ctx.mounted) setModalState(() => isLoading = false);
                            }
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: BorderSide(color: primary.withOpacity(0.5), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: primary.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  Future<void> _showMandatoryGroupModal(List groups) async {
     final lang = Provider.of<LanguageProvider>(context, listen: false);
     await showDialog(
       context: context,
       barrierDismissible: false,
       builder: (context) => WillPopScope(
         onWillPop: () async => false,
         child: AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
           title: Text(lang.translate('select_batch') ?? "SELECT YOUR BATCH", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
           content: SizedBox(
             width: double.maxFinite,
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(lang.translate('must_join_group') ?? "You must be added to a group before you can continue.", style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white60)),
                 const SizedBox(height: 20),
                 Flexible(
                   child: ListView.builder(
                     shrinkWrap: true,
                     itemCount: groups.length,
                     itemBuilder: (c, i) {
                        final g = groups[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            title: Text(g['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text("${g['day_name'] ?? ''} @ ${g['session_time'] ?? ''}", style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.add_circle_outline_rounded, color: Colors.white30),
                            onTap: () async {
                               final confirm = await showDialog<bool>(
                                 context: context,
                                 builder: (c) => AlertDialog(
                                   title: Text(lang.translate('confirm_selection') ?? "CONFIRM SELECTION", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                   content: Text("${lang.translate('join_group_confirm') ?? 'Join group'} ${g['name']}?"),
                                   actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(lang.translate('cancel') ?? "CANCEL")),
                                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(lang.translate('yes_join') ?? "YES, JOIN")),
                                   ],
                                 ),
                               );
                               if (confirm == true) {
                                  final wp = Provider.of<WorkspaceProvider>(context, listen: false);
                                  await wp.joinGroup(g['id']);
                                  if (context.mounted) Navigator.pop(context);
                                  _fetch(); // Refresh
                               }
                            },
                          ),
                        );
                     },
                   ),
                 ),
               ],
             ),
           ),
         ),
       ),
     );
  }

  Future<void> _backgroundRefresh() async {
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await wp.eagerLoad();
      if (mounted) {
        final cached = wp.cachedDashboard;
        if (cached != null) {
          final data = Map<String, dynamic>.from(cached);
          data['favorites_list'] = (wp.cachedFavorites?['favorites'] ?? []);
          final meRes = wp.cachedME ?? {};
          final favIds = (data['favorites_list'] as List)
              .map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0)
              .toSet();
          setState(() {
            _dashboardData = data;
            _walletBalanceStr = (meRes['user']?['wallet_balance'] ?? wp.cachedWallet?['balance'] ?? "0").toString();
            // Sync provider state (no longer uses local set)
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    // TYPE-RESILIENT DATA PARSING
    final dynamic rawDataObj = _dashboardData?['data'] ?? _dashboardData;
    final Map<String, dynamic> rawData = rawDataObj is Map<String, dynamic> ? rawDataObj : {};
    
    final List apiCourses = (rawData['courses'] as List?) ?? [];
    final List initialAllCoursesRawRaw = wp.isGuest 
        ? (wp.publicCourses ?? [])
        : ((rawData['all_courses'] as List?) ?? json.decode(workspace?.latestCoursesJson ?? '[]'));
        
    final List initialAllCoursesRaw = initialAllCoursesRawRaw.where((c) {
      if (c is! Map) return true;
      if (c.containsKey('is_active') && c['is_active'] != null) {
        final a = c['is_active'];
        if (a == 0 || a == false || a == '0') return false;
      }
      if (c.containsKey('status') && c['status'] != null) {
        final s = c['status'].toString().toLowerCase();
        if (s == '0' || s == 'inactive' || s == 'draft' || s == 'false') return false;
      }
      return true;
    }).toList();

    final List allCoursesRaw;
    if (wp.isGuest) {
      allCoursesRaw = initialAllCoursesRaw;
    } else {
      final List wpGroups = wp.cachedGroups?['groups'] as List? ?? [];
      final joinedGroups = wpGroups.where((g) => g['is_member'] == true || g['is_member'] == 1 || g['is_member'] == 'true').toList();
      final joinedGroupIds = joinedGroups.map((g) => int.tryParse(g['id']?.toString() ?? '0') ?? 0).where((id) => id > 0).toSet();
      
      final groupCourseIds = <int>{};
      for (final g in joinedGroups) {
        final gCourses = g['courses'] ?? g['courseIds'] ?? g['course_ids'] ?? g['courseList'] ?? g['courses_list'];
        if (gCourses is List) {
          for (final c in gCourses) {
            final cid = int.tryParse(c is Map ? (c['id']?.toString() ?? '0') : c.toString()) ?? 0;
            if (cid > 0) groupCourseIds.add(cid);
          }
        }
      }

      final filtered = initialAllCoursesRaw.where((course) {
        final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
        
        final cGroupId = int.tryParse(
          course['groupId']?.toString() ?? 
          course['batchId']?.toString() ?? 
          course['group_id']?.toString() ?? 
          course['batch_id']?.toString() ?? 
          '0'
        ) ?? 0;

        final nestedGroupId = () {
          final gObj = course['group'] ?? course['batch'];
          if (gObj is Map) {
            return int.tryParse(gObj['id']?.toString() ?? gObj['groupId']?.toString() ?? gObj['group_id']?.toString() ?? '0') ?? 0;
          }
          return 0;
        }();

        final pivotGroupId = () {
          final pivot = course['pivot'];
          if (pivot is Map) {
            return int.tryParse(
              pivot['groupId']?.toString() ??
              pivot['batchId']?.toString() ??
              pivot['group_id']?.toString() ??
              pivot['batch_id']?.toString() ??
              '0'
            ) ?? 0;
          }
          return 0;
        }();
        
        final belongsToGroup = groupCourseIds.contains(cid) || 
                              (cGroupId > 0 && joinedGroupIds.contains(cGroupId)) ||
                              (nestedGroupId > 0 && joinedGroupIds.contains(nestedGroupId)) ||
                              (pivotGroupId > 0 && joinedGroupIds.contains(pivotGroupId));
        return belongsToGroup;
      }).toList();

      if (filtered.isEmpty && initialAllCoursesRaw.isNotEmpty) {
        // Output debug keys/structure to help trace why it did not match
        debugPrint('⚠️ [DashboardScreen Group Filter] Fallback triggered. Course keys: ${initialAllCoursesRaw.first.keys.toList()}');
        if (initialAllCoursesRaw.first['pivot'] is Map) {
          debugPrint('🔍 pivot keys: ${(initialAllCoursesRaw.first['pivot'] as Map).keys.toList()}');
        }
        allCoursesRaw = initialAllCoursesRaw;
      } else {
        allCoursesRaw = filtered;
      }
    }

    final List<dynamic> catFilteredCourses = () {
      if (_selectedCategoryId == null) return allCoursesRaw;
      final allowedIds = _getDescendantCategoryIds(_selectedCategoryId!, _categories);
      return allCoursesRaw.where((course) {
        final courseCatId = int.tryParse(course['category_id']?.toString() ?? '') ?? 
                            int.tryParse(course['categoryId']?.toString() ?? '') ?? 0;
        return allowedIds.contains(courseCatId);
      }).toList();
    }();
    

    
    final List favoritesList = (rawData['favorites_list'] as List?) ?? [];
    final Set<int> favoriteIds = favoritesList.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).toSet();
    
    // API returns strictly enrolled courses with progress
    final List enrolledCourses = apiCourses.map((c) {
      final map = Map<String, dynamic>.from(c);
      final cid = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
      map['enrolled'] = true; // explicitly force true
      map['is_favorite'] = favoriteIds.contains(cid);
      return map;
    }).toList();
    
    if (_isLoading) return Scaffold(backgroundColor: theme.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white, body: const Center(child: PremiumLoader()));

    // ── REQUIRE LOGIN GUARD ───────────────────────────────────────────────────
    if (wp.requireLogin && wp.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
      });
      return Scaffold(backgroundColor: theme.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white, body: const Center(child: PremiumLoader()));
    }

    // ── GUEST BANNER ──────────────────────────────────────────────────────────
    final isGuest = wp.isGuest;
    final lang2 = lang; // alias for closure
    final Set<int> enrolledIds = enrolledCourses.map((c) => int.tryParse(c['id']?.toString() ?? '0') ?? 0).toSet();
    
    // Available courses are all courses minus the enrolled ones
    final List availableCourses = allCoursesRaw.map((c) {
      final map = Map<String, dynamic>.from(c);
      final cid = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
      
      // Check for any implicit enrollment flags from metadata
      map['enrolled'] = enrolledIds.contains(cid); 
      
      map['is_favorite'] = favoriteIds.contains(cid);
      return map;
    }).where((c) {
      final cid = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
      final bool alreadyEnrolled = enrolledIds.contains(cid) || (c['enrolled'] == true);
      if (alreadyEnrolled || cid <= 0) return false;
      
      if (c.containsKey('is_active') && c['is_active'] != null) {
        final a = c['is_active'];
        if (a == 0 || a == false || a == '0') return false;
      }
      if (c.containsKey('status') && c['status'] != null) {
        final s = c['status'].toString().toLowerCase();
        if (s == '0' || s == 'inactive' || s == 'draft' || s == 'false') return false;
      }
      
      return true;
    }).toList();
    
    final Map<String, dynamic> stats = rawData['stats'] is Map ? rawData['stats'] : {};
    final Map<String, dynamic> user = rawData['user'] is Map ? rawData['user'] : {};

    final walletBalance = _walletBalanceStr != "0.00" ? _walletBalanceStr : (user['wallet_balance'] ?? stats['walletBalance'] ?? stats['wallet_balance'] ?? 0).toString();
    final totalCoursesCount = (stats['totalCourses'] ?? stats['total_courses'] ?? enrolledCourses.length).toString();
    final studyHoursValue = (stats['studyHours'] ?? stats['study_hours'] ?? "0").toString();
    final pointsValue = (stats['points'] ?? "0").toString();

    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final List features = json.decode(workspace?.featuresJson ?? '[]');

    final showWallet = !wp.isGuest && (wp.activeWorkspace?.enablePurchasing ?? true);

    Widget homeTab = Stack(
        children: [
          // TOP BRANDING GRADIENT
          Positioned(
            top: 0, left: 0, right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [primaryColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          

            
          SafeArea(
            child: Column(
              children: [
                // GUEST BANNER
                if (isGuest)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            lang2.translate('guest_login_prompt') ?? 'You\'re browsing as guest. Tap to login →',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                // TOP BAR (Menu + Notification)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(IconlyLight.category, color: onSurface, size: 24),
                        onPressed: () => isRTL ? _scaffoldKey.currentState?.openDrawer() : _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                      IconButton(
                        icon: Icon(IconlyLight.notification, color: onSurface, size: 24),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('no_notifications') ?? 'لا توجد إشعارات جديدة')));
                        },
                      ),
                    ],
                  ),
                ),

                // SCROLLABLE CONTENT (HERO, STATS, FAQS)
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetch,
                    color: primaryColor,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        const SizedBox(height: 16),
                        _buildHeroSection(),
                        const SizedBox(height: 24),
                        
                        if (!isGuest) ...[
                          if (workspace?.enablePurchasing ?? true)
                            _buildHeaderBox(context, (lang.translate('wallet_balance') ?? 'رصيد المحفظة').toUpperCase(), "$walletBalance ${lang.translate('currency_le') ?? 'جنيه'}", Icons.account_balance_wallet_rounded, primaryColor, false, () {
                              _navigateToTab(2);
                            }),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildMiniStat(lang.translate('my_courses') ?? 'كورساتي', totalCoursesCount, Icons.book_rounded, primaryColor)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMiniStat(lang.translate('study_hours') ?? 'ساعات الدراسة', studyHoursValue, Icons.timer_rounded, primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        _buildCategoryFilters(primaryColor, onSurface),
                        _buildLatestCoursesSection(catFilteredCourses, lang, primaryColor, onSurface, isRTL),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ); // end Stack
  
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      extendBody: true,
      drawer: isRTL ? _buildLuxurySidebar(wp, lang, theme, workspace, primaryColor, isRTL) : null,
      endDrawer: !isRTL ? _buildLuxurySidebar(wp, lang, theme, workspace, primaryColor, isRTL) : null,
      bottomNavigationBar: _buildBottomNavigationBar(lang),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (idx) {
          int mappedIndex = idx;
          if (!showWallet && idx == 2) mappedIndex = 3;
          setState(() => _currentIndex = mappedIndex);
        },
        children: [
          homeTab,
          const CoursesScreen(),
          if (showWallet) const WalletScreen(),
          const ProfileScreen(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(LanguageProvider lang) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final showWallet = !wp.isGuest && (wp.activeWorkspace?.enablePurchasing ?? true);

    int mappedIndex = _currentIndex;
    if (!showWallet && _currentIndex == 3) mappedIndex = 2; // adjust for hidden wallet

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 30, offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GNav(
              gap: 8,
              activeColor: Colors.white,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(milliseconds: 300),
              tabBackgroundColor: primary,
              color: isDark ? Colors.white54 : Colors.black54,
              textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              selectedIndex: mappedIndex,
              onTabChange: (index) {
                int targetIdx = index;
                if (!showWallet && index == 2) targetIdx = 3;

                if (wp.isGuest && (targetIdx == 2 || targetIdx == 3)) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
                  return;
                }
                _navigateToTab(targetIdx);
              },
              tabs: [
                GButton(icon: IconlyLight.home, text: lang.translate('home') ?? 'Home'),
                GButton(icon: IconlyLight.play, text: lang.translate('courses') ?? 'Courses'),
                if (showWallet) GButton(icon: IconlyLight.wallet, text: lang.translate('academy_wallet') ?? 'Wallet'),
                GButton(icon: IconlyLight.profile, text: lang.translate('profile') ?? 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeroSection() {
    final primaryColor = Theme.of(context).primaryColor;
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isAr = lang.currentLocale.languageCode == 'ar';
    final siteName = wp.appName;

    final titleText = isAr 
        ? (siteName.isNotEmpty ? "تعلم بذكاء. تطور بثقة مع $siteName" : "تعلم بذكاء. تطور بثقة")
        : (siteName.isNotEmpty ? "Learn elmasa. Grow with Confidence at $siteName" : "Learn elmasa. Grow with Confidence");
    final subText = isAr
        ? "منصة تعليمية تقدم تجربة تعلم مرنة تساعدك على تطوير مهاراتك وتحقيق أهدافك."
        : "A comprehensive platform offering flexible learning to develop your skills.";
    final btnText = isAr ? "تصفح الدورات" : "Browse Courses";

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.85), primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.25),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subText,
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          _navigateToTab(1);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(btnText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: isAr ? null : -15,
            left: isAr ? -15 : null,
            top: -10,
            child: IgnorePointer(
              child: Icon(
                Icons.school_rounded,
                size: 76,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestCoursesSection(List allCourses, LanguageProvider lang, Color primaryColor, Color onSurface, bool isRTL) {
    final wp = Provider.of<WorkspaceProvider>(context);
    if (allCourses.isEmpty) {
      return _buildNoDataWidget(context, lang, isRTL);
    }

    // Compute enrolledIds from cached dashboard/stats to ensure identical flow to Courses page
    final List apiCourses = (wp.cachedDashboard?['courses'] ?? wp.cachedDashboard?['data']?['courses'] ?? []) as List;
    final Set<int> enrolledIds = apiCourses.map((c) => int.tryParse(c['id']?.toString() ?? '0') ?? 0).toSet();

    final List enrolledList = [];
    final List otherList = [];

    for (final courseRaw in allCourses) {
      final course = Map<String, dynamic>.from(courseRaw);
      final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
      final bool isEnrolled = enrolledIds.contains(cid);
      
      course['enrolled_computed'] = isEnrolled;
      if (isEnrolled) {
        enrolledList.add(course);
      } else {
        otherList.add(course);
      }
    }

    if (allCourses.isEmpty && enrolledList.isEmpty) {
      return _buildNoDataWidget(context, lang, isRTL);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (enrolledList.isNotEmpty) ...[
          Text(
            lang.translate('my_courses') ?? (isRTL ? 'كورساتي المشتركة' : 'My Enrolled Courses'),
            style: GoogleFonts.cairo(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          ...enrolledList.map((course) {
            final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CourseCard(
                course: course,
                isEnrolled: true,
                enablePurchasing: wp.activeWorkspace?.enablePurchasing ?? true,
                isFavorite: wp.localFavoriteIds.contains(cid),
                onTap: () {
                  if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid);
                },
                onFavoriteTap: () => _toggleFavorite(course),
                lang: lang,
                currency: wp.publicCurrency,
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],

        if (otherList.isNotEmpty || enrolledList.isEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.translate('latest_courses') ?? (isRTL ? 'أحدث الكورسات' : 'Latest Courses'),
                style: GoogleFonts.cairo(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              TextButton(
                onPressed: () {
                  _navigateToTab(1);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.translate('see_all') ?? (isRTL ? 'عرض الكل' : 'See All'),
                      style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isRTL ? Icons.arrow_left_rounded : Icons.arrow_right_rounded,
                      size: 20,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(otherList.isNotEmpty ? otherList : allCourses).map((courseRaw) {
            final course = Map<String, dynamic>.from(courseRaw);
            final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
            final isEnrolled = course['enrolled_computed'] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CourseCard(
                course: course,
                isEnrolled: isEnrolled,
                enablePurchasing: wp.activeWorkspace?.enablePurchasing ?? true,
                isFavorite: wp.localFavoriteIds.contains(cid),
                onTap: () {
                  if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid);
                },
                onFavoriteTap: () => _toggleFavorite(course),
                lang: lang,
                currency: wp.publicCurrency,
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildNoDataWidget(BuildContext context, LanguageProvider lang, bool isRTL) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: onSurface.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ModernEmptyStateIllustration(primaryColor: primaryColor, size: 130),
          const SizedBox(height: 20),
          Text(
            isRTL ? 'استكشف محتوانا التعليمي المميز' : 'Explore Our Featured Content',
            style: TextStyle(
              color: onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isRTL ? 'سيتم إضافة دورات ومحاضرات جديدة قريبًا. اضغط تحديث لمزامنة البيانات.' : 'New courses and lectures will be added soon. Tap refresh to check.',
            style: TextStyle(
              color: onSurface.withOpacity(0.6),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.85)],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                final wp = Provider.of<WorkspaceProvider>(context, listen: false);
                if (wp.isGuest) {
                  _fetchGuest();
                } else {
                  _fetch();
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
              label: Text(
                isRTL ? 'تحديث المحتوى' : 'Refresh Content',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFaqsSection() {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final workspace = wp.activeWorkspace;
    List faqs = [];
    try {
      if (wp.publicFaqs != null && wp.publicFaqs!.isNotEmpty) {
        faqs = List.from(wp.publicFaqs!);
      } else {
        faqs = json.decode(workspace?.faqsJson ?? '[]');
      }
    } catch (_) {}

    if (faqs.isEmpty) {
      faqs = [
        {
          "question": "كيف أستطيع إنشاء حساب وبدء المشاهدة؟",
          "answer": "الأمر يستغرق ثوانٍ معدودة. اضغط على أزرار التسجيل، أدخل بياناتك أو استخدم حساب جوجل الخاص بك، ثم ابدأ في تصفح المنهج وتفعيل الكورسات."
        },
        {
          "question": "هل الكورسات مسجلة أم يتم بثها مباشرة؟",
          "answer": "نظامنا هجين؛ يعتمد بشكل أساسي على المحاضرات المسجلة بأعلى جودة تقنية لكي تتابعها في الوقت الذي يناسبك، بالإضافة لمراجعات دورية مباشرة."
        },
        {
          "question": "ما هي طرق الدفع المتاحة لفتح محتوى الكورسات؟",
          "answer": "نوفر طرق دفع متعددة لتناسب الجميع، تشمل المحافظ الإلكترونية المتعددة وكروت الفيزا وماستركارد، ويتم التفعيل بشكل فوري بعد الدفع."
        },
        {
          "question": "هل هناك دعم فني إذا واجهتني مشكلة بالتطبيق؟",
          "answer": "بالتأكيد، فريقنا جاهز يومياً للرد على أي استفسار تقني أو أكاديمي لضمان سير تعليمك دون أي عقبات."
        }
      ];
    }

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.translate('faqs') ?? (isRTL ? "الأسئلة الشائعة" : "FAQs"), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          ...faqs.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              title: Text(f['question']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(f['answer']?.toString() ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13, height: 1.5)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _stripHtml(String? html) {
    if (html == null) return '';
    // Unescape common HTML entities
    String result = html.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ');
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return result.replaceAll(exp, '').trim();
  }

  Widget _buildWhatsAppPulse(String number, Color primary) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _waController, curve: Curves.easeInOut)),
      child: FloatingActionButton(
        onPressed: () => Provider.of<WorkspaceProvider>(context, listen: false).launchUrl('https://wa.me/${number.replaceAll('+', '')}'),
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.message_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feat, Color primary, Color onSurface) {
    IconData getIcon(String? name) {
      if (name == null) return Icons.auto_awesome_rounded;
      switch (name.toLowerCase()) {
        case 'layout': return Icons.dashboard_customize_rounded;
        case 'shieldcheck': return Icons.verified_user_rounded;
        case 'award': return Icons.emoji_events_rounded;
        case 'phone': return Icons.phone_rounded;
        default: return Icons.auto_awesome_rounded;
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(18), 
        border: Border.all(color: primary.withOpacity(0.1), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(getIcon(feat['icon_name']), color: primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feat['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w900, height: 1.2)),
                const SizedBox(height: 4),
                Text(
                  _stripHtml(feat['description']), 
                  style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBox(BuildContext context, String label, String val, IconData icon, Color color, bool isAccent, VoidCallback onTap) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isAccent ? color : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: isAccent ? null : Border.all(color: Theme.of(context).dividerColor, width: 2)),
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: TextStyle(color: isAccent ? Colors.white.withOpacity(0.7) : onSurface.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text(val, style: TextStyle(color: isAccent ? Colors.white : onSurface, fontSize: 13, fontWeight: FontWeight.w900)),
            ])),
            Icon(icon, color: isAccent ? Colors.white : color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor, width: 2)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
        ],
      ),
    );
  }

  Future<bool?> _showPremiumAlert(BuildContext context, {required String title, required String message, String? confirmText, String? cancelText, bool isDestructive = false}) async {
    final primary = Theme.of(context).primaryColor;
    return showDialog<bool>(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: (isDestructive ? Colors.red : primary).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isDestructive ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: isDestructive ? Colors.red : primary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(title.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(cancelText ?? 'CANCEL', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDestructive ? Colors.red : primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(confirmText ?? 'CONFIRM', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyState(LanguageProvider lang) {
     return Center(
       child: Column(
         children: [
           const SizedBox(height: 80),
           Icon(Icons.auto_awesome_mosaic_rounded, size: 80, color: Theme.of(context).dividerColor),
           const SizedBox(height: 24),
           Text(lang.translate('no_courses_yet') ?? 'No courses found', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
         ],
       ),
     );
  }

  Widget _buildEmptyFilterState(LanguageProvider lang) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 40),
       child: Center(
         child: Column(
           children: [
             Icon(Icons.filter_list_off_rounded, size: 48, color: Theme.of(context).dividerColor),
             const SizedBox(height: 16),
             Text(lang.translate('no_matches') ?? 'No matches found for this filter', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.bold)),
           ],
         ),
       ),
     );
  }

  bool _matchesFilter(Map<String, dynamic> course) {
    if (_courseTypeFilter == "ALL") return true;
    
    final String type = course['course_type']?.toString().toUpperCase() ?? "";
    final String cat = course['category_name']?.toString().toUpperCase() ?? "";
    final String title = course['title']?.toString().toUpperCase() ?? "";

    if (_courseTypeFilter == "VIDEOS") return title.contains("VIDEO") || type.contains("VIDEO") || cat.contains("VIDEO");
    if (_courseTypeFilter == "FILES") return title.contains("PDF") || type.contains("FILE") || cat.contains("FILE") || title.contains("NOTES");
    if (_courseTypeFilter == "QUIZZES") return title.contains("QUIZ") || type.contains("QUIZ") || cat.contains("QUIZ") || title.contains("EXAM");

    return true;
  }

  Widget _buildTypeChip(String filter, String label, IconData icon, Color primary, Color onSurface) {
    final isSelected = _courseTypeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _courseTypeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? primary : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primary : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : onSurface.withOpacity(0.5), size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : onSurface, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxurySidebar(WorkspaceProvider wp, LanguageProvider lang, ThemeProvider theme, Workspace? workspace, Color wsColor, bool isRTL) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardColor = Theme.of(context).cardColor;
    
    return Container(
      width: 290,
      child: Drawer(
        backgroundColor: cardColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(40), bottomLeft: Radius.circular(40))),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 60, 24, 32),
              decoration: BoxDecoration(color: wsColor.withOpacity(0.12), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (wp.isGuest) {
                            Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false);
                          } else {
                            _navigateToTab(3);
                          }
                        },
                        child: (() {
                          final Map<String, dynamic> user = (wp.cachedME?['user'] is Map)
                              ? Map<String, dynamic>.from(wp.cachedME!['user'])
                              : {};
                          final String? userImageUrl = workspace?.studentPhotoUrl ?? user['image_url'] ?? user['image'] ?? user['avatar'] ?? user['avatar_url'];
                          final bool hasUserImage = userImageUrl != null && userImageUrl.isNotEmpty;
                          if (hasUserImage) {
                            return Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: wsColor.withOpacity(0.2), width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.network(
                                  userImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Icon(Icons.person_rounded, color: wsColor, size: 32),
                                ),
                              ),
                            );
                          } else if ((workspace?.logoUrl ?? wp.publicLogoUrl) != null) {
                            return Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: wsColor.withOpacity(0.2), width: 1.5)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Image.network((workspace?.logoUrl ?? wp.publicLogoUrl)!, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: wsColor, size: 32))),
                            );
                          } else {
                            return Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: wsColor, shape: BoxShape.circle),
                              child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                            );
                          }
                        })(),
                      ),
                      
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [ 
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(wp.appName, style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                IconButton(onPressed: () => theme.toggleTheme(), icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: wsColor, size: 20)),
                              ],
                            ),
                            Text(workspace?.studentName ?? lang.translate('student_profile') ?? 'Student Profile', style: TextStyle(color: onSurface.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
                    child: Text((lang.translate('main_menu') ?? 'MAIN MENU').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  _buildSidebarAction(icon: Icons.grid_view_rounded, title: lang.translate('dashboard'), onTap: () => Navigator.pop(context), isSelected: true, wsColor: wsColor),
                  _buildSidebarAction(icon: Icons.library_books_rounded, title: lang.translate('all_courses') ?? 'All Courses', onTap: () { Navigator.pop(context); _navigateToTab(1); }, wsColor: wsColor),
                  _buildSidebarAction(icon: Icons.favorite_rounded, title: lang.translate('favorites') ?? 'Favorites', onTap: () { Navigator.pop(context); if (wp.isGuest) Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false); else Navigator.pushNamed(context, '/favorites'); }, wsColor: wsColor),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
                    child: Text((lang.translate('account') ?? 'ACCOUNT & BILLING').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  _buildSidebarAction(icon: Icons.person_rounded, title: lang.translate('profile'), onTap: () { Navigator.pop(context); if (wp.isGuest) Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false); else _navigateToTab(3); }, wsColor: wsColor),
                  if (workspace?.enablePurchasing ?? true)
                    _buildSidebarAction(icon: Icons.account_balance_wallet_rounded, title: lang.translate('wallet_balance') ?? 'Academy Wallet', onTap: () { Navigator.pop(context); if (wp.isGuest) Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false); else _navigateToTab(2); }, wsColor: wsColor),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: InkWell(
                onTap: () async { 
                  final nav = Navigator.of(context);
                  nav.pop(); // Close drawer
                  if (wp.isGuest) {
                    nav.pushNamedAndRemoveUntil('/onboarding', (r) => false);
                  } else {
                    // Show a brief loading overlay before navigating
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      await wp.logout();
                    } catch (_) {}
                    nav.pushNamedAndRemoveUntil('/onboarding', (r) => false);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: wp.isGuest
                        ? const Color(0xFF22C55E).withOpacity(0.1)
                        : const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        wp.isGuest ? Icons.login_rounded : Icons.power_settings_new_rounded,
                        color: wp.isGuest ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        wp.isGuest
                            ? (lang.translate('login') ?? 'Login')
                            : lang.translate('logout'),
                        style: TextStyle(
                          color: wp.isGuest ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction({required IconData icon, required String title, required VoidCallback onTap, bool isSelected = false, required Color wsColor}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: isSelected ? wsColor : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [Icon(icon, color: isSelected ? Colors.white : onSurface.withOpacity(0.6), size: 20), const SizedBox(width: 16), Text(title, style: TextStyle(color: isSelected ? Colors.white : onSurface, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, fontSize: 14))]),
        ),
      ),
    );
  }


}

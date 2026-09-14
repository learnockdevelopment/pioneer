import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:elmasa/widgets/course_card.dart';
import 'package:elmasa/utils/iconly.dart';
import 'package:elmasa/widgets/modern_empty_state_illustration.dart';

class CoursesScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const CoursesScreen({super.key, this.onMenuPressed});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _isLoading = true;
  List<dynamic> _availableCourses = [];
  List<dynamic> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    if (wp.isGuest) {
      if (mounted) {
        setState(() {
        _availableCourses = (wp.publicCourses ?? []).map((c) {
          final map = Map<String, dynamic>.from(c);
          map['enrolled'] = false;
          map['is_favorite'] = false;
          return map;
        }).where((c) {
          final cid = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
          if (cid <= 0) return false;
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
        _categories = wp.publicCategories ?? [];
        _isLoading = false;
      });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        wp.getCourses(),
        wp.getFavorites(),
        wp.getGroups(),
      ]);
      _applyData(results[0] as Map<String, dynamic>, results[1] as Map<String, dynamic>);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyData(Map<String, dynamic> dashRes, Map<String, dynamic> favRes) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final Map<String, dynamic> data = (dashRes['data'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(dashRes['data'])
        : dashRes;

    final List initialAllCoursesRawRaw = ((data['all_courses'] as List?) ?? (data['courses'] as List?) ?? []);
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
        debugPrint('⚠️ [CoursesScreen Group Filter] Fallback triggered. Course keys: ${initialAllCoursesRaw.first.keys.toList()}');
        if (initialAllCoursesRaw.first['pivot'] is Map) {
          debugPrint('🔍 pivot keys: ${(initialAllCoursesRaw.first['pivot'] as Map).keys.toList()}');
        }
        allCoursesRaw = initialAllCoursesRaw;
      } else {
        allCoursesRaw = filtered;
      }
    }

    final List enrolledCourses = (wp.cachedDashboard?['courses'] as List?) ?? [];
    final Set<int> enrolledIds = enrolledCourses.map((c) => int.tryParse(c['id']?.toString() ?? '0') ?? 0).toSet();
    final List favoritesList = (favRes['favorites'] as List?) ?? [];
    final Set<int> favoriteIds = favoritesList.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).toSet();
    final List categoriesRaw = (dashRes['categories'] as List?) ?? [];

    if (mounted) {
      setState(() {
        _categories = categoriesRaw;
        _availableCourses = allCoursesRaw.map((c) {
          final map = Map<String, dynamic>.from(c);
          final cid = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
          // STRICTLY use enrolledIds to prevent "Progress" bar showing for unenrolled courses
          map['enrolled'] = enrolledIds.contains(cid);
          map['is_favorite'] = favoriteIds.contains(cid);
          return map;
        }).where((c) {
          final cid = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
          if (cid <= 0) return false;
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
      });
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

  List<dynamic> get _filteredCourses {
    if (_selectedCategoryId == null) {
      return _availableCourses;
    }
    final allowedIds = _getDescendantCategoryIds(_selectedCategoryId!, _categories);
    return _availableCourses.where((course) {
      final courseCatId = int.tryParse(course['category_id']?.toString() ?? '') ?? 
                          int.tryParse(course['categoryId']?.toString() ?? '') ?? 0;
      return allowedIds.contains(courseCatId);
    }).toList();
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
          content: Text(lang.translate('please_login_to_favorite') ?? 'Please login to save favorite courses.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(lang.translate('cancel') ?? 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () { Navigator.pop(c); Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false); },
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
        Text(newFav ? (lang.translate('added_to_favorites') ?? 'Added') : (lang.translate('removed_from_favorites') ?? 'Removed')),
      ]),
      backgroundColor: newFav ? Colors.green.shade700 : Colors.grey.shade700,
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
    try { await wp.toggleFavoriteOptimistic(cid); } catch (_) {}
  }

  Widget _buildCategoryFilters(Color primaryColor, Color onSurface) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                  color: isSelected ? Colors.white : onSurface.withOpacity(0.8),
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: Theme.of(context).cardColor,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryId = isAll ? null : categoryId;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
              elevation: isSelected ? 4 : 0,
              pressElevation: 0,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final filtered = _filteredCourses;

    final List enrolledList = [];
    final List otherList = [];
    for (final course in filtered) {
      final dynamic e = course['enrolled'] ?? course['is_enrolled'] ?? course['is_purchased'] ?? course['isEnrolled'];
      final isEnrolled = e == true || e == 1 || e == '1' || e == 'true';
      if (isEnrolled) {
        enrolledList.add(course);
      } else {
        otherList.add(course);
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: Icon(IconlyLight.category, color: onSurface, size: 24),
                onPressed: () {
                  if (widget.onMenuPressed != null) {
                    widget.onMenuPressed!();
                  } else {
                    if (isRTL) Scaffold.of(context).openDrawer(); else Scaffold.of(context).openEndDrawer();
                  }
                },
              ),
              actions: [
                IconButton(
                  icon: Icon(IconlyLight.notification, color: onSurface, size: 24),
                  onPressed: () => _showNotificationsDialog(context, lang),
                ),
              ],
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
                title: Text(
                  lang.translate('all_courses') ?? 'Academy Curriculum',
                  style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [primaryColor.withOpacity(0.08), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

            if (!_isLoading && _categories.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCategoryFilters(primaryColor, onSurface),
              ),

            if (_isLoading)
              const SliverFillRemaining(child: Center(child: PremiumLoader()))
            else if (_availableCourses.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ModernEmptyStateIllustration(primaryColor: primaryColor, size: 120),
                        const SizedBox(height: 24),
                        Text(
                          isRTL ? 'لا توجد بيانات متاحة حالياً، يرجى إعادة التحميل' : 'No data currently available. Please reload',
                          style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isRTL ? 'اسحب للأسفل أو اضغط زر إعادة التحميل لمزامنة البيانات.' : 'Pull down or tap reload to sync latest data.',
                          style: TextStyle(color: onSurface.withOpacity(0.55), fontSize: 13, height: 1.4, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                          label: Text(
                            isRTL ? 'إعادة التحميل' : 'Reload Data',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined, size: 80, color: Theme.of(context).dividerColor),
                      const SizedBox(height: 24),
                      Text(
                        isRTL ? 'لا توجد كورسات في هذا القسم' : 'No courses in this category',
                        style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isRTL ? 'يرجى اختيار قسم آخر لتصفح الكورسات المتاحة.' : 'Try selecting another category to browse available courses.',
                        style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // ENROLLED COURSES SECTION
              if (enrolledList.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      lang.translate('my_courses') ?? (isRTL ? 'كورساتي المشتركة' : 'My Enrolled Courses'),
                      style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final course = enrolledList[index];
                        final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CourseCard(
                            course: course,
                            isEnrolled: true,
                            enablePurchasing: wp.activeWorkspace?.enablePurchasing ?? true,
                            isFavorite: wp.localFavoriteIds.contains(cid),
                            onTap: () { if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid); },
                            onFavoriteTap: () => _toggleFavorite(course),
                            lang: lang,
                            currency: wp.publicCurrency,
                          ),
                        );
                      },
                      childCount: enrolledList.length,
                    ),
                  ),
                ),
              ],

              // LATEST / OTHER COURSES SECTION
              if (otherList.isNotEmpty || enrolledList.isEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      lang.translate('latest_courses') ?? (isRTL ? 'أحدث الكورسات' : 'Latest Courses'),
                      style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final course = otherList.isNotEmpty ? otherList[index] : filtered[index];
                        final bool isEnrolled = course['enrolled'] == true;
                        final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CourseCard(
                            course: course,
                            isEnrolled: isEnrolled,
                            enablePurchasing: wp.activeWorkspace?.enablePurchasing ?? true,
                            isFavorite: wp.localFavoriteIds.contains(cid),
                            onTap: () { if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid); },
                            onFavoriteTap: () => _toggleFavorite(course),
                            lang: lang,
                            currency: wp.publicCurrency,
                          ),
                        );
                      },
                      childCount: otherList.isNotEmpty ? otherList.length : filtered.length,
                    ),
                  ),
                ),
              ] else ...[
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context, LanguageProvider lang) {
    final primary = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Theme.of(ctx).dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.notifications_active_rounded, color: primary, size: 24)),
                  const SizedBox(width: 14),
                  Text(lang.translate('notifications') ?? 'Notifications', style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 40),
              Icon(Icons.notifications_none_rounded, size: 64, color: onSurface.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(lang.translate('no_notifications') ?? 'No new notifications yet', style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(lang.currentLocale.languageCode == 'ar' ? 'سنقوم بإخطارك فور صدور محاضرات أو تحديثات جديدة.' : "We'll notify you when new lectures or updates are available.", style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

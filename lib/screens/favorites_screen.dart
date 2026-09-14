import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = false;
  bool _isInit = true;
  List<dynamic> _favoriteCourses = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    if (wp.isEagerLoaded && wp.cachedFavorites != null && wp.cachedDashboard != null) {
      _applyData(wp.cachedDashboard!, wp.cachedFavorites!);
      if (mounted) setState(() { _isLoading = false; _isInit = false; });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        wp.getFavorites(),
        wp.getDashboard(),
      ]);
      
      _applyData(results[1] as Map<String, dynamic>, results[0] as Map<String, dynamic>);
    } catch (_) {} finally {
      if (mounted) setState(() { _isLoading = false; _isInit = false; });
    }
  }

  void _applyData(Map<String, dynamic> dashRes, Map<String, dynamic> favRes) {
    final List enrolled = (dashRes['courses'] as List?) ?? [];
    final Set<int> enrolledIds = enrolled.map((e) => int.tryParse(e['id']?.toString() ?? '0') ?? 0).toSet();
    
    final List favs = (favRes['favorites'] as List?) ?? [];
    final Set<int> favIds = favs.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).toSet();

    if (mounted) {
      setState(() {
        _favoriteCourses = favs.map((f) {
           final fmap = Map<String, dynamic>.from(f);
           final fid = int.tryParse(fmap['id']?.toString() ?? '0') ?? 0;
        }).toList();
      });
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> course) async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
    if (cid == 0) return;

    final bool newFav = !wp.localFavoriteIds.contains(cid);

    // ✅ OPTIMISTIC UI — Remove from visible list immediately if unfavoriting
    if (!newFav) {
      setState(() {
        _favoriteCourses.removeWhere((c) => (int.tryParse(c['id']?.toString() ?? '0') ?? 0) == cid);
      });
    }

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
        // RE-FETCH ON ERROR TO RESTORE THE CARD IF IT WAS REMOVED
        _fetch(); 
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

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    // Use directly fetched favorite courses
    final List courses = _favoriteCourses;
    
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 20), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
              title: Text(
                lang.translate('favorites') ?? 'Favorites', 
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)
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
          
          if (_isLoading && _isInit)
            const SliverFillRemaining(
              child: Center(
                child: PremiumLoader(),
              ),
            )
          else if (courses.isEmpty)
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 64,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      lang.translate('empty_favorites_title') ?? 'No Favorites Yet',
                      style: TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang.translate('empty_favorites_subtitle') ?? 'Courses you favorite will appear here.',
                      style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildCourseCard(context, courses[index], primaryColor, onSurface, lang),
                  ),
                  childCount: courses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _stripHtml(String? html) {
    if (html == null) return '';
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').trim();
  }

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course, Color primary, Color onSurface, LanguageProvider lang) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
    final isFavorite = wp.localFavoriteIds.contains(cid);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
      ),
      child: InkWell(
        onTap: () {
          final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
          if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid);
        },
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Image.network(
                    course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80',
                    height: 180, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(height: 180, color: Theme.of(context).dividerColor, child: const Icon(Icons.school_rounded, size: 48)),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(100)),
                      child: Text("${course['price']} ${lang.translate('currency_le')}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                   Positioned(
                     top: 12, left: 12,
                     child: InkWell(
                       onTap: () => _toggleFavorite(course), // always instant
                       child: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                         child: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? Colors.red : Colors.grey, size: 20),
                       ),
                     ),
                   ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course['category'] != null && course['category'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(course['category'].toString().toUpperCase(), style: TextStyle(color: primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(course['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                  const SizedBox(height: 8),
                  Text(
                    _stripHtml(course['description']), 
                    style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ...[
                        Icon(Icons.play_circle_fill_rounded, color: primary, size: 20),
                        const SizedBox(width: 8),
                        Text("${course['total_materials'] ?? 0} ${lang.translate('materials_count')}", style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ? 8 : 6), 
                        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]), 
                        child: Text(
                          ((course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ? (lang.translate('open_course') ?? 'START LEARNING') : (lang.translate('subscribe') ?? 'SUBSCRIBE')).toUpperCase(), 
                          style: TextStyle(color: Colors.white, fontSize: (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ? 11 : 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

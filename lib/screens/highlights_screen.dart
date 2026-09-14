import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'dart:convert';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

void _showImageModal(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    List features = [];
    try {
      final decoded = json.decode(workspace?.featuresJson ?? '[]');
      if (decoded is List) {
        features = decoded;
      } else if (decoded is Map && decoded['features'] is List) {
        features = decoded['features'];
      }
      features.sort((a, b) {
        final aOrder = int.tryParse(a['display_order']?.toString() ?? '0') ?? 0;
        final bOrder = int.tryParse(b['display_order']?.toString() ?? '0') ?? 0;
        return aOrder.compareTo(bOrder);
      });
    } catch (_) {}
    
    if (features.isEmpty) {
      features = [
        {"title": lang.translate('high_quality_content') ?? "محتوى عالي الجودة", "description": lang.translate('high_quality_content_desc') ?? "تعلم من أفضل المناهج المصممة بواسطة الخبراء."},
        {"title": lang.translate('interactive_learning') ?? "تعلم تفاعلي", "description": lang.translate('interactive_learning_desc') ?? "تفاعل مع الاختبارات لتقييم معرفتك باستمرار."},
        {"title": lang.translate('expert_teachers') ?? "معلمون خبراء", "description": lang.translate('expert_teachers_desc') ?? "احصل على توجيه مستمر من أفضل المعلمين."},
      ];
    }
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 20), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 20),
              centerTitle: false,
              title: Text(
                lang.translate('features') ?? 'Platform Features',
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [primaryColor.withOpacity(0.12), Colors.transparent],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome_rounded, color: primaryColor.withOpacity(0.1), size: 120),
                ),
              ),
            ),
          ),
          
          if (features.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(lang.translate('no_features') ?? 'No special highlights for this academy.', style: TextStyle(color: onSurface.withOpacity(0.4), fontWeight: FontWeight.bold))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0 && (workspace?.heroSubtitle != null && workspace!.heroSubtitle!.isNotEmpty)) {
                       return _buildHeroDescCard(workspace.heroTitle ?? '', workspace.heroSubtitle!, primaryColor, onSurface, context);
                    }
                    final featIndex = (workspace?.heroSubtitle != null && workspace!.heroSubtitle!.isNotEmpty) ? index - 1 : index;
                    if (featIndex < 0 || featIndex >= features.length) return const SizedBox();
                    return _buildGlowingFeatureCard(features[featIndex], primaryColor, onSurface, context);
                  },
                  childCount: features.length + ((workspace?.heroSubtitle != null && workspace!.heroSubtitle!.isNotEmpty) ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroDescCard(String title, String desc, Color primary, Color onSurface, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primary.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((title.isNotEmpty ? title : 'Academy Vision').toUpperCase(), style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          HtmlWidget(
            desc, 
            textStyle: TextStyle(color: onSurface, fontSize: 15, fontWeight: FontWeight.bold, height: 1.6),
            onTapImage: (src) => _showImageModal(context, src.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingFeatureCard(Map<String, dynamic> feat, Color primary, Color onSurface, BuildContext context) {
    IconData getIcon(String? name) {
      if (name == null) return Icons.auto_awesome_mosaic_rounded;
      switch (name.toLowerCase()) {
        case 'layout': return Icons.dashboard_customize_rounded;
        case 'shieldcheck': return Icons.verified_user_rounded;
        case 'award': return Icons.emoji_events_rounded;
        case 'phone': return Icons.phone_rounded;
        default: return Icons.auto_awesome_mosaic_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primary.withOpacity(0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // DYNAMIC GRADIENT OVERLAY
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [primary.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Icon(getIcon(feat['icon_name']), color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          feat['title'] ?? '',
                          style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary.withOpacity(0.05), width: 1),
                    ),
                    child: HtmlWidget(
                      feat['description'] ?? '',
                      textStyle: TextStyle(
                        color: onSurface.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.6,
                      ),
                      onTapImage: (src) => _showImageModal(context, src.toString()),
                    ),
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

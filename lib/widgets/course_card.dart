import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:elmasa/utils/iconly.dart';
import 'package:elmasa/providers/language_provider.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool isEnrolled;
  final bool enablePurchasing;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final LanguageProvider lang;
  final String? currency;

  const CourseCard({
    super.key,
    required this.course,
    required this.isEnrolled,
    required this.enablePurchasing,
    required this.isFavorite,
    required this.onTap,
    this.onFavoriteTap,
    required this.lang,
    this.currency,
  });

  static String _stripHtml(String? html) {
    if (html == null || html.isEmpty) return '';
    String result = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;

    final String title = course['title'] ?? '';
    final String desc = _stripHtml(course['description']?.toString());
    final String thumb = course['thumbnail_url']?.toString() ?? course['image_url']?.toString() ?? '';
    final String cat = course['category_name']?.toString() ?? '';
    final bool hasDemo = course['demo_video_url'] != null && course['demo_video_url'].toString().isNotEmpty;

    final bool isFree = course['is_free'] == 1 || course['is_free'] == '1' || course['is_free'] == true
        || course['price'] == '0.00' || course['price'] == 0 || course['price'] == '0';
    final String priceStr = course['price']?.toString() ?? '0.00';
    final double progress = double.tryParse(course['progress']?.toString() ?? '0') ?? 0.0;

    final String lecturesCount = course['total_materials']?.toString()
        ?? course['materials_count']?.toString() ?? '0';
    final String studentsCount = course['total_students']?.toString()
        ?? course['enrollment_count']?.toString()
        ?? course['members_count']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : primary.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.3) 
                      : primary.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── THUMBNAIL ─────────────────────────────────────────────────
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: thumb.isNotEmpty
                              ? Image.network(
                                  thumb,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primary.withOpacity(0.2), primary.withOpacity(0.05)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(IconlyLight.image, color: primary, size: 30),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primary.withOpacity(0.2), primary.withOpacity(0.05)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(IconlyLight.image, color: primary, size: 30),
                                ),
                        ),
                      ),
                      if (hasDemo)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(IconlyBold.play, color: Colors.white, size: 16),
                          ),
                        ),
                      if (isEnrolled)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // ── DETAILS COLUMN ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (cat.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cat.toUpperCase(),
                                style: GoogleFonts.cairo(
                                  color: primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          if (onFavoriteTap != null)
                            InkWell(
                              onTap: onFavoriteTap,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isFavorite ? IconlyBold.heart : IconlyLight.heart,
                                  color: isFavorite ? const Color(0xFFEF4444) : onSurface.withOpacity(0.35),
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          color: onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: onSurface.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (isEnrolled) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress / 100,
                                  backgroundColor: primary.withOpacity(0.12),
                                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${progress.round()}%',
                              style: GoogleFonts.cairo(
                                color: primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(IconlyLight.document, size: 12, color: onSurface.withOpacity(0.4)),
                                const SizedBox(width: 4),
                                Text(
                                  '$lecturesCount',
                                  style: GoogleFonts.cairo(
                                    color: onSurface.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(IconlyLight.user, size: 12, color: onSurface.withOpacity(0.4)),
                                const SizedBox(width: 4),
                                Text(
                                  '$studentsCount',
                                  style: GoogleFonts.cairo(
                                    color: onSurface.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (enablePurchasing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isFree 
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isFree ? lang.translate('free') : '$priceStr ${currency ?? ''}',
                                  style: GoogleFonts.cairo(
                                    color: isFree ? const Color(0xFF10B981) : primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'dart:convert';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    // Filter FAQs based on search query
    final filteredFaqs = faqs.where((faq) {
      final q = (faq['question']?.toString() ?? '').toLowerCase();
      final a = (faq['answer']?.toString() ?? '').toLowerCase();
      final search = _searchQuery.toLowerCase();
      return q.contains(search) || a.contains(search);
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Glow Bloom
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryColor.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: IconButton(
                  icon: Icon(
                    isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, 
                    color: onSurface, 
                    size: 20
                  ), 
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsetsDirectional.only(start: 24, bottom: 20),
                  title: Text(
                    lang.translate('faqs') ?? 'Academy FAQ', 
                    style: GoogleFonts.cairo(
                      color: onSurface, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 20, 
                      letterSpacing: -0.5
                    ),
                  ),
                ),
              ),
              
              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: GoogleFonts.cairo(color: onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isRTL ? 'ابحث في الأسئلة الشائعة...' : 'Search FAQs...',
                        hintStyle: GoogleFonts.cairo(color: onSurface.withOpacity(0.4), fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: onSurface.withOpacity(0.4), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: onSurface.withOpacity(0.4), size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (filteredFaqs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.help_outline_rounded, size: 64, color: onSurface.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          isRTL ? 'لم نعثر على نتائج مطابقة' : 'No matching questions found',
                          style: GoogleFonts.cairo(
                            color: onSurface.withOpacity(0.4),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildFaqItem(
                        filteredFaqs[index], 
                        primaryColor, 
                        onSurface, 
                        context, 
                        isRTL,
                        isDark
                      ),
                      childCount: filteredFaqs.length,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, dynamic> faq, Color primary, Color onSurface, BuildContext context, bool isRTL, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          expandedAlignment: isRTL ? Alignment.topRight : Alignment.topLeft,
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: primary,
          collapsedIconColor: onSurface.withOpacity(0.4),
          title: Text(
            faq['question'] ?? '', 
            style: GoogleFonts.cairo(
              color: onSurface, 
              fontSize: 14, 
              fontWeight: FontWeight.w900, 
              letterSpacing: -0.2
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.04), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withOpacity(0.08)),
              ),
              child: Text(
                faq['answer'] ?? '', 
                style: GoogleFonts.cairo(
                  color: onSurface.withOpacity(0.8), 
                  fontSize: 13, 
                  height: 1.7, 
                  fontWeight: FontWeight.w600
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

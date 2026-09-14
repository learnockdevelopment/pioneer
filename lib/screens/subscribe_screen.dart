import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/screens/simple_scanner_screen.dart';
import 'package:elmasa/widgets/premium_loader.dart';

class SubscribeScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const SubscribeScreen({super.key, required this.course});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  bool _isProcessing = false;

  void _showCodeDialog(BuildContext context, {required bool isVoucher}) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVoucher ? (lang.translate('redeem_voucher') ?? 'Top-up Wallet') : (lang.translate('redeem_coupon') ?? 'Activate Coupon'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('coupon_hint') ?? 'Enter your code here to proceed',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.qr_code_rounded, color: primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  final nav = Navigator.of(context);
                  final sm = ScaffoldMessenger.of(context);
                  nav.pop(); // Close sheet
                  setState(() => _isProcessing = true);
                  try {
                    final res = isVoucher 
                        ? await wp.redeemVoucher(controller.text)
                        : await wp.redeemCoupon(controller.text, courseId: int.tryParse(widget.course['id']?.toString() ?? '0') ?? 0);
                    sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                    
                    await wp.eagerLoad();
                    
                    if (mounted) {
                      if (isVoucher) {
                        nav.pushReplacementNamed('/dashboard');
                      } else {
                        final cid = int.tryParse(widget.course['id']?.toString() ?? '0') ?? 0;
                        nav.pushReplacementNamed('/course', arguments: cid);
                      }
                    }
                  } catch (e) {
                    sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang.translate('confirm') ?? 'Confirm', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _handleWalletCheckout() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final nav = Navigator.of(context);
    final sm = ScaffoldMessenger.of(context);
    
    if (_isProcessing) return; // Prevent double trigger
    
    setState(() => _isProcessing = true);
    try {
      final cid = int.tryParse(widget.course['id']?.toString() ?? '0') ?? 0;
      final res = await wp.checkoutWallet(cid);
      sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Enrolled successfully!'), backgroundColor: Colors.green));
      
      // Update global cache to reflect enrollment
      await wp.eagerLoad();
      
      if (mounted) {
        nav.pushReplacementNamed('/course', arguments: cid);
      }
    } catch (e) {
      final errorStr = e.toString();
      final isInsufficientBalance = errorStr.toLowerCase().contains('balance') || 
                                    errorStr.toLowerCase().contains('insufficient') ||
                                    errorStr.contains('رصيد') ||
                                    errorStr.contains('كاف');
      if (isInsufficientBalance) {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/wallet',
            arguments: {'prompt': 'insuff_balance'},
          );
        }
        return;
      }
      final errorMsg = errorStr.contains('already subscribed') || errorStr.contains('مشترك') 
          ? 'You are already enrolled in this course!' 
          : errorStr;
      sm.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: errorStr.contains('already subscribed') || errorStr.contains('مشترك') ? Colors.orange : Colors.red));
      
      if (errorStr.contains('already subscribed') || errorStr.contains('مشترك')) {
         await wp.eagerLoad();
         if (mounted) {
            final cid = int.tryParse(widget.course['id']?.toString() ?? '0') ?? 0;
            nav.pushReplacementNamed('/course', arguments: cid);
         }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final wp = Provider.of<WorkspaceProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // ROBUST CATEGORY DETECTION (STRING OR OBJECT)
    dynamic cat = widget.course['category_name'] ?? widget.course['category'] ?? widget.course['subject'] ?? widget.course['cat_name'];
    String catStr = "";
    if (cat is Map) {
      catStr = (cat['name'] ?? cat['title'] ?? "").toString();
    } else if (cat != null) {
      catStr = cat.toString();
      if (int.tryParse(catStr) != null) catStr = ""; // Ignore pure IDs
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80',
                        fit: BoxFit.cover,
                      ),
                      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PREMIUM COURSE SUMMARY CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: primaryColor.withOpacity(0.1), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 20)),
                            BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 20, spreadRadius: -5),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (catStr.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                    child: Text(catStr.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: onSurface.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                                  child: Text((lang.translate('premium_course') ?? 'Premium Course').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.course['title'] ?? '',
                              style: TextStyle(color: onSurface, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.2),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Colors.black12),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (wp.activeWorkspace?.enablePurchasing ?? true)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lang.translate('course_price') ?? 'COURSE PRICE', style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                      Text("${widget.course['price'] ?? '0.00'} ${lang.translate('currency_le') ?? 'LE'}", style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                Column(
                                  crossAxisAlignment: (wp.activeWorkspace?.enablePurchasing ?? true) ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(lang.translate('materials_count') ?? 'MODULES', style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    Text("${widget.course['total_materials'] ?? 0}", style: TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildFeatureRow(Icons.lock_clock_rounded, lang.translate('subscribe_to_unlock') ?? 'Subscribe to unlock all lessons', primaryColor, onSurface),
                      _buildFeatureRow(Icons.verified_user_rounded, lang.translate('lifetime_access') ?? 'Lifetime access to all materials', primaryColor, onSurface),
                      _buildFeatureRow(Icons.support_agent_rounded, lang.translate('teacher_support') ?? 'Direct support from the teacher', primaryColor, onSurface),
                      
                      const SizedBox(height: 48),
                      
                      if (wp.activeWorkspace?.enablePurchasing ?? true) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleWalletCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wallet_rounded),
                                const SizedBox(width: 12),
                                Text(lang.translate('redeem_wallet') ?? 'Subscribe using Wallet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      InkWell(
                        onTap: () => _showCodeDialog(context, isVoucher: false),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: onSurface.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: onSurface.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.confirmation_num_rounded, color: primaryColor),
                              const SizedBox(width: 12),
                              Text(lang.translate('apply_coupon') ?? 'Coupon Code', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                      

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(child: PremiumLoader(size: 80)),
          ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color primary, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

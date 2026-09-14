import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:elmasa/screens/simple_scanner_screen.dart';
import 'dart:ui' as ui;

class WalletScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const WalletScreen({super.key, this.onMenuPressed});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isProcessing = false;
  Map<String, dynamic>? _dashboardData;
  String _walletBalanceStr = "0.00";
  bool _hasCheckedPrompt = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedPrompt) {
      _hasCheckedPrompt = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['prompt'] == 'insuff_balance') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showInsuffBalanceDialog();
        });
      }
    }
  }

  Future<void> _fetch({bool force = false}) async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    if (!force && wp.cachedWallet != null) {
       _applyData(wp.cachedWallet!);
    } else {
       setState(() => _isProcessing = true);
    }

    try {
      if (force) {
        await wp.reloadWalletData();
      }
      final balRes = await wp.getWalletBalance();
      _applyData(balRes);
    } catch (_) {}
    if (mounted) setState(() => _isProcessing = false);
  }

  void _applyData(Map<String, dynamic> balRes) {
    if (mounted) {
      setState(() {
        _walletBalanceStr = (balRes['balance'] ?? balRes['wallet_balance'] ?? "0").toString();
      });
    }
  }

  void _showInsuffBalanceDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              lang.translate('insufficient_balance') ?? 'Insufficient Balance',
              style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              lang.translate('insufficient_balance_msg') ?? 'Your current balance is not enough to subscribe. Please charge your wallet to continue.',
              style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      lang.translate('cancel') ?? 'Cancel',
                      style: TextStyle(color: onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showVoucherDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      lang.translate('charge_wallet') ?? 'Charge Wallet',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showResultPrompt({required bool success, String? message}) {
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: (success ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: success ? Colors.green : Colors.red, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              success ? (lang.translate('success') ?? 'Success!') : (lang.translate('failure') ?? 'Error'),
              style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? (success ? lang.translate('operation_success') ?? 'Operation completed.' : lang.translate('operation_failure') ?? 'Please try again.'),
              style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(lang.translate('confirm') ?? 'OK', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDialog(BuildContext context) {
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
            Row(
              children: [
                Icon(Icons.stars_rounded, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  lang.translate('redeem_voucher') ?? 'Top-up Wallet',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('coupon_hint') ?? 'Enter your recharge code here (Booklet Code)',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'MA-XXXX-XXXX',
                filled: true,
                fillColor: primaryColor.withOpacity(0.05),
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
                  nav.pop(); // Close sheet
                  setState(() => _isProcessing = true);
                  try {
                    final res = await wp.redeemVoucher(controller.text);
                    _showResultPrompt(success: true, message: res['message']);
                    _fetch(force: true); // Force refresh balance from server
                  } catch (e) {
                    _showResultPrompt(success: false, message: e.toString());
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
                child: Text(lang.translate('confirm') ?? 'RECHARGE NOW', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),

          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isRTL = lang.currentLocale.languageCode == 'ar';

    final balance = _walletBalanceStr;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(isRTL ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                : IconButton(
                    icon: Icon(Icons.menu_rounded, color: onSurface, size: 28),
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
                icon: Icon(Icons.notifications_outlined, color: onSurface, size: 28),
                onPressed: () => _showNotificationsDialog(context, lang),
              ),
            ],
            title: Text(lang.translate('wallet_balance') ?? 'Academy Wallet', style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18)),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: () => _fetch(force: true),
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // PREMIUM BALANCE CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          Text((lang.translate('wallet_balance') ?? 'Wallet Balance').toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(balance, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Text(lang.translate('currency_le') ?? 'LE', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // TRANSACTIONS BUTTON
                    _buildActionCard(
                      title: lang.translate('transactions') ?? 'Transactions History',
                      subtitle: lang.translate('transactions_hint') ?? 'View all your wallet activity',
                      icon: Icons.receipt_long_rounded,
                      color: Colors.blueGrey,
                      onTap: () => Navigator.pushNamed(context, '/transactions'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // RECHARGE SECTION
                    _buildActionCard(
                      title: lang.translate('redeem_voucher') ?? 'Top-up using Booklet Code',
                      subtitle: lang.translate('voucher_desc') ?? 'Use a recharge code to increase your balance',
                      icon: Icons.qr_code_scanner_rounded,
                      color: primaryColor,
                      onTap: () => _showVoucherDialog(context),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // SAFETY INFO
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          Icon(Icons.security_rounded, color: primaryColor, size: 24),
                          const SizedBox(width: 16),
                          Expanded(child: Text(lang.translate('wallet_secure') ?? 'Your transactions are encrypted and managed directly by the academy administration.', style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor, width: 2),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).dividerColor),
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
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_active_rounded, color: primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    lang.translate('notifications') ?? (lang.currentLocale.languageCode == 'ar' ? 'الإشعارات' : 'Notifications'),
                    style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Icon(Icons.notifications_none_rounded, size: 64, color: onSurface.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                lang.translate('no_notifications') ?? (lang.currentLocale.languageCode == 'ar' ? 'لا توجد إشعارات جديدة' : 'No new notifications yet'),
                style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                lang.currentLocale.languageCode == 'ar'
                    ? 'سنقوم بإخطارك فور صدور محاضرات أو تحديثات جديدة.'
                    : 'We\'ll notify you when new lectures or updates are available.',
                style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

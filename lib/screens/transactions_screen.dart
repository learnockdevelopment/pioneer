import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'dart:io' as io;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final res = await wp.getWalletTransactions();
      if (mounted) {
        setState(() {
          _transactions = res['transactions'] ?? res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('transactions') ?? 'Transactions',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: PremiumLoader(size: 80))
          : _transactions.isEmpty
              ? _buildEmptyState(lang, onSurface)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    return _buildTransactionCard(tx, primaryColor, onSurface, lang);
                  },
                ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang, Color onSurface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: io.File('C:\\Users\\dell\\.gemini\\antigravity\\brain\\3609e548-4586-4257-aa07-8b9199d4f59a\\no_courses_mockup_1774986859239.png').existsSync()
                ? Image.file(
                    io.File('C:\\Users\\dell\\.gemini\\antigravity\\brain\\3609e548-4586-4257-aa07-8b9199d4f59a\\no_courses_mockup_1774986859239.png'), // HIGH-FIDELITY MOCKUP
                    width: 280,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.receipt_long_rounded, size: 80, color: Theme.of(context).dividerColor),
          ),
          const SizedBox(height: 32),
          Text(
            lang.translate('no_transactions') ?? 'No transactions found',
            style: TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            lang.translate('transactions_hint') ?? 'Your wallet activity will appear here.',
            style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(dynamic tx, Color primary, Color onSurface, LanguageProvider lang) {
    // Determine type: typically 'credit' (add) or 'debit' (subtract)
    final type = tx['type']?.toString().toLowerCase() ?? 'credit';
    final isCredit = type == 'credit' || type == 'deposit' || type == 'add';
    final amount = tx['amount']?.toString() ?? '0.00';
    final desc = tx['description'] ?? tx['title'] ?? (isCredit ? 'Recharge' : 'Purchase');
    final date = tx['created_at'] ?? tx['date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(color: onSurface.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "${isCredit ? '+' : '-'}$amount ${lang.translate('currency_le')}",
            style: TextStyle(
              color: isCredit ? Colors.green : Colors.red,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';

/// Wallet balance + transaction history.
class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final types = context.types;

    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'کیف پول',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: walletAsync.when(
        loading: () => const PageLoading(),
        error: (error, _) => ViewState<Wallet>(
          loading: false,
          error: error,
          onRetry: () => ref.refresh(walletProvider.future),
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (wallet) => RefreshIndicator(
          onRefresh: () => ref.refresh(walletProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // :: BALANCE CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primaryContainer,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: colors.onPrimary,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'موجودی قابل استفاده',
                          style: types.titleSmall?.copyWith(
                            color: colors.onPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${Formatter.price(wallet.balance)} تومان',
                      style: types.headlineSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // :: TRANSACTIONS
              Text(
                'تراکنش‌ها',
                style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (wallet.transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'تراکنشی ثبت نشده است.',
                      style: types.bodySmall?.copyWith(color: colors.outline),
                    ),
                  ),
                )
              else
                ...wallet.transactions.map(
                  (transaction) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (transaction.isIncome
                                    ? const Color(0xff16a34a)
                                    : colors.error)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            transaction.isIncome
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            size: 18,
                            color: transaction.isIncome
                                ? const Color(0xff16a34a)
                                : colors.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Formatter.transactionType(
                                    transaction.transactionType),
                                style: types.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatter.jalaliFullDate(transaction.createdAt),
                                style: types.bodySmall
                                    ?.copyWith(color: colors.outline),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${transaction.isIncome ? '+' : '−'}${Formatter.price(transaction.amount)}',
                          style: types.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: transaction.isIncome
                                ? const Color(0xff16a34a)
                                : colors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

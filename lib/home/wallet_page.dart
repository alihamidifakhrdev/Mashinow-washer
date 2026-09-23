import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/jalali.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// کیف پول — موجودی و تراکنش‌ها (wallet/wallet/)
class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  Future<Wallet?> _load() async {
    try {
      final dynamic data = await Api.get('/wallet/wallet/');
      return data is Map<String, dynamic> ? Wallet.fromJson(data) : null;
    } on ApiException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('کیف پول')),
      body: FutureBuilder<Wallet?>(
        future: _load(),
        builder: (BuildContext context, AsyncSnapshot<Wallet?> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          final Wallet? wallet = snap.data;

          if (wallet == null) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: 'کیف پول در دسترس نیست',
              message: 'در حال حاضر اطلاعات کیف پول قابل دریافت نیست؛ دوباره تلاش کنید.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              // :: کارت موجودی — آبی برند (تک‌رنگ، بدون گرادینت)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.blue.withOpacity(0.30),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'موجودی قابل استفاده',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          toToman(wallet.balance),
                          style: const TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'تومان',
                            style: TextStyle(
                              fontFamily: 'IRANYekan',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // :: تراکنش‌ها
              const SectionTitle(text: 'تراکنش‌ها'),
              if (wallet.transactions.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'تراکنشی ثبت نشده است',
                    message: 'تراکنش‌های کیف پول شما اینجا نمایش داده می‌شوند.',
                  ),
                )
              else
                for (final WalletTransaction t in wallet.transactions)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.amount >= 0
                                ? AppColors.successTint()
                                : AppColors.redTint(),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            t.amount >= 0
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: t.amount >= 0
                                ? AppColors.success
                                : AppColors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                t.description.isEmpty
                                    ? (t.amount >= 0 ? 'واریز' : 'برداشت')
                                    : t.description,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'IRANYekan',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.createdAt != null
                                    ? Jalali.fullDate(t.createdAt!)
                                    : '',
                                style: TextStyle(
                                  fontFamily: 'IRANYekan',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${t.amount >= 0 ? '+' : '-'}${toToman(t.amount.abs())} تومان',
                          style: TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color:
                                t.amount >= 0 ? AppColors.success : AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

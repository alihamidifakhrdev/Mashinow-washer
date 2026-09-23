import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../onboarding/hours_page.dart';
import '../onboarding/services_page.dart';
import 'carwash_edit_page.dart';
import 'wallet_page.dart';

/// تب «بیشتر» — پروفایل کارواش، دسترسی به خدمات/زمان‌ها/کیف پول و خروج
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  CarwashProfile? _profile;
  bool _loading = true;

  SessionStore get _session => SessionScope.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final dynamic data = await Api.get('/carwash/profile');

      if (!mounted) return;

      setState(() {
        _profile = data is Map<String, dynamic>
            ? CarwashProfile.fromJson(data)
            : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, e.message, error: true);
    }
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => page),
    );
  }

  Future<void> _confirmLogout() async {
    // نشست را قبل از دیالوگ (await) می‌گیریم
    final SessionStore session = _session;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'خروج از حساب',
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'می‌خواهید از حساب کارواش خود خارج شوید؟',
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.ink2,
            height: 1.8,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'انصراف',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                color: AppColors.ink2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'خروج',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                color: AppColors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await session.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? Center(child: CircularProgressIndicator(color: AppColors.accent))
        : RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 160),
              children: <Widget>[
                Text(
                  'بیشتر',
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),

                // :: کارت پروفایل کارواش
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.accentTint(),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.local_car_wash_rounded,
                            color: AppColors.accent, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _profile?.name ?? 'کارواش شما',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'IRANYekan',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _profile?.address ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'IRANYekan',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink3,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // :: تم اپ (روشن / شب / سیستم)
                _MenuItem(
                  icon: Icons.dark_mode_rounded,
                  color: AppColors.accent,
                  tint: AppColors.accentTint(),
                  title: 'تم اپ',
                  subtitle: 'حالت فعلی: ${appTheme.modeLabel} — برای تغییر بزنید',
                  onTap: () => appTheme.cycle(),
                ),

                // :: منو
                _MenuItem(
                  icon: Icons.list_alt_rounded,
                  color: AppColors.accent,
                  tint: AppColors.accentTint(),
                  title: 'خدمات و تعرفه‌ها',
                  subtitle: 'مدیریت خدمات و قیمت‌های کارواش',
                  onTap: () => _open(const ServicesSetupPage(asManage: true)),
                ),
                _MenuItem(
                  icon: Icons.schedule_rounded,
                  color: AppColors.accent,
                  tint: AppColors.accentTint(),
                  title: 'زمان‌های کاری',
                  subtitle: 'روزها و ساعات کاری کارواش',
                  onTap: () => _open(const WorkingHoursPage(asManage: true)),
                ),
                _MenuItem(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.accent,
                  tint: AppColors.accentTint(),
                  title: 'کیف پول',
                  subtitle: 'موجودی و تراکنش‌ها',
                  onTap: () => _open(const WalletPage()),
                ),
                _MenuItem(
                  icon: Icons.edit_rounded,
                  color: AppColors.accent,
                  tint: AppColors.accentTint(),
                  title: 'ویرایش اطلاعات کارواش',
                  subtitle: 'نام، تلفن، مجوز و آدرس',
                  onTap: () => _open(const CarwashEditPage()),
                ),
                const SizedBox(height: 20),

                // :: خروج
                AppCard(
                  onTap: _confirmLogout,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.logout_rounded, color: AppColors.red, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'خروج از حساب',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.red,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.chevron_left_rounded,
                          color: AppColors.ink3, size: 22),
                    ],
                  ),
                ),
              ],
            ),
          );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          Icon(Icons.chevron_left_rounded,
              color: AppColors.ink3, size: 22),
        ],
      ),
    );
  }
}

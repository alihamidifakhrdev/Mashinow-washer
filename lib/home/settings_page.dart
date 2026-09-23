import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/theme_reveal.dart';
import '../core/ui.dart';
import '../onboarding/hours_page.dart';
import '../onboarding/services_page.dart';
import 'carwash_edit_page.dart';
import 'wallet_page.dart';

/// تب «تنظیمات» (قبلاً بیشتر) — پروفایل کارواش، سوییچ تم تیره،
/// خدمات/زمان‌ها/کیف پول، ویرایش اطلاعات و خروج از حساب
class SettingsPage extends StatefulWidget {
  SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

    final bool confirmed = await showIOSConfirm(
      context: context,
      title: 'خروج از حساب',
      message: 'می‌خواهید از حساب کارواش خود خارج شوید؟',
      confirmText: 'خروج',
      destructive: true,
    );

    if (confirmed) {
      await session.logout();
    }
  }

  /// تم مؤثر فعلی (حتی وقتی روی «سیستم» است)
  bool _effectiveDark(BuildContext context) {
    final bool platformDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return appTheme.mode == ThemeMode.dark ||
        (appTheme.mode == ThemeMode.system && platformDark);
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 150),
              children: <Widget>[
                Text(
                  'تنظیمات',
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),

                // :: کارت پروفایل کارواش (لهجه آبی برند)
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.blueTint(),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.local_car_wash_rounded,
                            color: AppColors.blue, size: 30),
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

                // :: تم تیره — سوییچ با انیمیشن «افشای دایره‌ای» از خودش
                _ThemeSwitchCard(effectiveDark: _effectiveDark(context)),

                // :: منو — یکی‌درمیان سبز و آبی برند
                _MenuItem(
                  icon: Icons.list_alt_rounded,
                  color: AppColors.success,
                  tint: AppColors.successTint(),
                  title: 'خدمات و تعرفه‌ها',
                  subtitle: 'مدیریت خدمات و قیمت‌های کارواش',
                  onTap: () => _open(const ServicesSetupPage(asManage: true)),
                ),
                _MenuItem(
                  icon: Icons.schedule_rounded,
                  color: AppColors.blue,
                  tint: AppColors.blueTint(),
                  title: 'زمان‌های کاری',
                  subtitle: 'روزها و ساعات کاری کارواش',
                  onTap: () => _open(const WorkingHoursPage(asManage: true)),
                ),
                _MenuItem(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success,
                  tint: AppColors.successTint(),
                  title: 'کیف پول',
                  subtitle: 'موجودی و تراکنش‌ها',
                  onTap: () => _open(const WalletPage()),
                ),
                _MenuItem(
                  icon: Icons.edit_rounded,
                  color: AppColors.blue,
                  tint: AppColors.blueTint(),
                  title: 'ویرایش اطلاعات کارواش',
                  subtitle: 'نام، تلفن و آدرس',
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

/// کارت سوییچ تم تیره — سوییچ iOS + انیمیشن افشای دایره‌ای از محل خودش
class _ThemeSwitchCard extends StatelessWidget {
  final bool effectiveDark;

  const _ThemeSwitchCard({required this.effectiveDark});

  @override
  Widget build(BuildContext context) {
    final bool isSystem = appTheme.mode == ThemeMode.system;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveDark
                      ? AppColors.accentTint()
                      : AppColors.blueTint(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  effectiveDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: effectiveDark ? AppColors.accent : AppColors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'تم تیره',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSystem
                          ? 'در حال حاضر: هماهنگ با سیستم'
                          : effectiveDark
                              ? 'در حال حاضر: تیره'
                              : 'در حال حاضر: روشن',
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
              // سوییچ داخل Builder تا مختصات «خودش» برای شروع انیمیشن
              // در دسترس باشد (دایره از مرکز همین سوییچ باز می‌شود)
              Builder(
                builder: (BuildContext switchContext) => CupertinoSwitch(
                  value: effectiveDark,
                  activeColor: AppColors.accent,
                  onChanged: (bool value) => ThemeReveal.play(
                    anchor: switchContext,
                    apply: () => appTheme
                        .setMode(value ? ThemeMode.dark : ThemeMode.light),
                  ),
                ),
              ),
            ],
          ),
          if (!isSystem)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (BuildContext btnContext) => TextButton.icon(
                    onPressed: () => ThemeReveal.play(
                      anchor: btnContext,
                      apply: () => appTheme.setMode(ThemeMode.system),
                    ),
                    icon: Icon(Icons.auto_awesome_rounded,
                        size: 15, color: AppColors.blue),
                    label: Text(
                      'هماهنگ با سیستم',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
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

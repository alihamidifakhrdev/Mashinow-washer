import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'add_customer_page.dart';
import 'dashboard_page.dart';
import 'orders_page.dart';
import 'settings_page.dart';
import 'tools_page.dart';

/// پوسته اصلی پنل — نوار ناوبری شناور (بدون استروک و بدون باکس روی تب فعال؛
/// فقط آیکون و متن تب فعال رنگی می‌شود) + دکمه مربعی «مشتری حضوری» داک‌شده
/// وسط نوار — ۴ تب دقیقاً به‌صورت وسط‌چین و مساوی دور دکمه تقسیم می‌شوند.
///
/// نکته تم: بدنه داخل ListenableBuilder روی appTheme است و صفحات بدون const
/// ساخته می‌شوند تا با تغییر سوییچ تم، همان لحظه همه‌جا نو شوند.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const double _barHeight = 66;
  static const double _barMargin = 12;
  static const double _fabSize = 58;
  static const double _fabLift = 24; // میزان بیرون‌زدگی دکمه از بالای نوار

  @override
  Widget build(BuildContext context) {
    final EdgeInsets view = MediaQuery.of(context).viewPadding;
    final double bottomInset = view.bottom;

    return ListenableBuilder(
      listenable: appTheme,
      builder: (BuildContext shellContext, Widget? _) {
        return Scaffold(
          backgroundColor: AppColors.canvas,
          // محتوا زیر نوار وضعیت گوشی نرود — SafeArea فقط دور صفحات؛
          // نوار شناور خودش جای خودش را با inset تنظیم می‌کند.
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: IndexedStack(
                    index: _index,
                    children: <Widget>[
                      DashboardPage(
                        onGoToOrders: () =>
                            setState(() => _index = 1),
                      ),
                      // بدون const: با تغییر تم باید از نو رنگ بگیرند
                      OrdersPage(),
                      ToolsPage(),
                      SettingsPage(),
                    ],
                  ),
                ),
              ),

              // :: نوار ناوبری شناور — بلور نرم، بدون استروک و بدون سایه تند
              Positioned(
                left: 16,
                right: 16,
                bottom: _barMargin + bottomInset,
                child: _BlurNavBar(
                  height: _barHeight,
                  index: _index,
                  onTap: (int i) => setState(() => _index = i),
                ),
              ),

              // :: دکمه «مشتری حضوری» — مربعی، گوشه‌های نرم، سایه ملایم؛
              // داک‌شده وسط نوار (کمی بالاتر از سطح نوار)
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    _barMargin + bottomInset + _barHeight - _fabLift,
                child: Center(
                  child: _DockedFab(
                    size: _fabSize,
                    onTap: () {
                      Navigator.of(shellContext).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const AddCustomerPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// نوار شناور با افکت شیشه‌ای ملایم (BackdropFilter سبک)
class _BlurNavBar extends StatelessWidget {
  final double height;
  final int index;
  final ValueChanged<int> onTap;

  const _BlurNavBar({
    required this.height,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0A1128).withOpacity(
                AppColors.isDark ? 0.16 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          // بلور نرم و ملایم (قبلاً ۱۸ بود و در چشم بود)
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              // سطح نیمه‌شفاف پررنگ‌تر تا بلور زیرش ملایم دیده شود
              color: AppColors.card.withOpacity(0.94),
              borderRadius: BorderRadius.circular(26),
              // بدون استروک — خواسته‌ی کاربر
            ),
            child: Row(
              children: <Widget>[
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'داشبورد',
                  selected: index == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.event_note_rounded,
                  label: 'نوبت‌ها',
                  selected: index == 1,
                  onTap: () => onTap(1),
                ),
                // جای دکمه داک‌شده وسط — تب‌ها دو طرفش مساوی تقسیم می‌شوند
                const SizedBox(width: 72),
                _NavItem(
                  icon: Icons.home_repair_service_rounded,
                  label: 'ابزارها',
                  selected: index == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'تنظیمات',
                  selected: index == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // بدون باکس/زمینه — فقط رنگ آیکون و متن فعال تغییر می‌کند
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 1.0,
                end: selected ? 1.12 : 1.0,
              ),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double scale, Widget? child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                icon,
                size: 23,
                color: selected ? AppColors.accent : AppColors.ink3,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.accentDeep : AppColors.ink3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// دکمه «مشتری حضوری» — مربعی با گوشه‌های نرم و سایه‌ی نرم و ملایم
class _DockedFab extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _DockedFab({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          // سبز — رنگِ متمایز «مشتری حضوری»؛ بقیه‌ی اپ آبی برند است
          color: AppColors.success,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              // سایه نرم و ملایم
              color: AppColors.success.withOpacity(0.26),
              blurRadius: 14,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: const Color(0xFF0A1128)
                  .withOpacity(AppColors.isDark ? 0.30 : 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: -3,
            ),
          ],
        ),
        child: const Icon(
          Icons.person_add_alt_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }
}

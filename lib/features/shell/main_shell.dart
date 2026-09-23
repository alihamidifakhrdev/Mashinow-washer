import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/features/bookings/bookings_page.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_page.dart';
import 'package:mashinow_washer/features/profile/profile_page.dart';
import 'package:mashinow_washer/features/services/services_page.dart';

class MainShellTab {
  final String routePath;
  final Widget page;

  const MainShellTab({required this.routePath, required this.page});
}

/// Main app shell with a bottom navigation bar (Snapp-driver style) and a
/// central FAB for creating walk-in (guest) bookings.
class MainShellPage extends ConsumerStatefulWidget {
  final String? initialTab;

  const MainShellPage({super.key, this.initialTab});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  late int _index;

  final List<MainShellTab> _tabs = [
    MainShellTab(routePath: 'dashboard', page: const DashboardPage()),
    MainShellTab(routePath: 'bookings', page: BookingsPage()),
    MainShellTab(routePath: 'services', page: ServicesPage()),
    MainShellTab(routePath: 'profile', page: ProfilePage()),
  ];

  @override
  void initState() {
    super.initState();
    _index = _indexOfTab(widget.initialTab);
  }

  int _indexOfTab(String? tab) {
    switch (tab) {
      case 'bookings':
        return 1;
      case 'services':
        return 2;
      case 'profile':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _tabs.map((tab) => tab.page).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'guest_booking_fab',
        onPressed: () => context.go('/main/guest-booking'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        elevation: 8,
        color: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _buildTabItem(0, Icons.home_rounded, 'داشبورد'),
            _buildTabItem(1, Icons.event_note_rounded, 'رزروها'),
            const Expanded(child: SizedBox.shrink()),
            _buildTabItem(2, Icons.design_services_rounded, 'سرویس‌ها'),
            _buildTabItem(3, Icons.person_rounded, 'حساب'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final colors = context.colors;
    final selected = _index == index;

    return Expanded(
      flex: 2,
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? colors.primary : colors.outline,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

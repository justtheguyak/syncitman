import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reminders/presentation/reminders_screen.dart';
import '../../tasks/presentation/tasks_notifier.dart';
import '../../tasks/presentation/tasks_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TasksScreen(),
    RemindersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingTasksCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: pendingCount > 0
                  ? Badge(
                      label: Text('$pendingCount'),
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.check_circle_outline_rounded),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              activeIcon: pendingCount > 0
                  ? Badge(
                      label: Text('$pendingCount'),
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.check_circle_rounded),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: 'Tasks',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Reminders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Us',
            ),
          ],
        ),
      ),
    );
  }
}

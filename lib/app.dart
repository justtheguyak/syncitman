import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/updates/presentation/mandatory_update_screen.dart';
import 'features/updates/presentation/update_notifier.dart';

class CoupleSyncApp extends ConsumerWidget {
  const CoupleSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);
    final updateState = ref.watch(updateNotifierProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Full screen mandatory update screen
        if (updateState.hasMandatoryUpdate) {
          return MandatoryUpdateScreen(updateInfo: updateState.updateInfo!);
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

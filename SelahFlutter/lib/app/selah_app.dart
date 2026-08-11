import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/selah_theme.dart';
import 'router.dart';

class SelahApp extends ConsumerWidget {
  const SelahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Selah',
      debugShowCheckedModeBanner: false,
      theme: SelahTheme.light(),
      darkTheme: SelahTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}

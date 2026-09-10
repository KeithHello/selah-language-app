import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'selah_app.dart';

Future<void> launch() async {
  runApp(const ProviderScope(child: SelahApp()));
}

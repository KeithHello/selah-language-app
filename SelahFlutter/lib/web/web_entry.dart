import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/learning_gateway.dart';
import 'data/supabase_learning_gateway.dart';
import 'domain/learning_models.dart';
import 'learning_controller.dart';
import 'admin/admin_controller.dart';
import 'platform/browser_platform.dart';
import 'ui/web_learning_app.dart';

Future<void> launch() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    LearningGateway gateway = UnconfiguredGateway();
    if (url.isNotEmpty && key.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || !_publicKey(key)) {
        throw const FormatException('在线服务配置无效，请使用 HTTPS 和公开的 Supabase 客户端密钥。');
      }
      await Supabase.initialize(url: url, publishableKey: key);
      gateway = SupabaseLearningGateway(Supabase.instance.client);
    }
    final seedJson = objectMap(
      jsonDecode(
        await rootBundle.loadString('assets/content/seed-sentences.json'),
      ),
    );
    final seeds = mapList(
      seedJson['sentences'],
      max: 100,
    ).map(LearnSentence.seed).toList();
    final audio = objectMap(
      jsonDecode(await rootBundle.loadString('assets/content/seed-audio.json')),
    );
    final controller = LearningController(
      gateway: gateway,
      platform: BrowserLearningPlatform(),
      seeds: seeds,
      bundledAudio: audio,
      adminController: AdminController(gateway: gateway),
    );
    await controller.initialize();
    runApp(WebLearningApp(controller: controller));
  } catch (_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xfffbf8f4),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Selah 暫時無法啟動。\n請重新整理頁面；如果仍未恢復，請檢查本機儲存權限與應用程式設定。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, height: 1.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _publicKey(String key) {
  if (key.startsWith('sb_publishable_')) return true;
  try {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    return objectMap(
          jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          ),
        )['role'] ==
        'anon';
  } catch (_) {
    return false;
  }
}

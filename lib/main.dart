import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/chat_db.dart';
import 'services/hf_service.dart';
import 'services/llm_service.dart';
import 'services/settings_service.dart';
import 'screens/chat_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: V.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final settings = SettingsService();
  await settings.init();

  final db = ChatDb();
  await db.init();

  runApp(App(settings: settings, db: db));
}

class App extends StatelessWidget {
  final SettingsService settings;
  final ChatDb db;
  const App({super.key, required this.settings, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalLLM',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: ChatScreen(
        llm: LlmService(),
        settings: settings,
        hf: HfService(),
        db: db,
      ),
    );
  }
}

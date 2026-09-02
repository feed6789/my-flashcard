import 'package:flashcard_app/features/flashcard/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/features/flashcard/presentation/pages/flashcard_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Initializing Supabase...');
    await SupabaseConfig.initialize();
    print('✅ Supabase initialized successfully!');
  } catch (e) {
    print('❌ Failed to initialize Supabase: $e');
  }
  
  try {
    print('🚀 Initializing Local Database...');
    LocalDatabase.initialize();
    final check = await LocalDatabase().checkDatabase();
    print('✅ Local Database initialized: $check');
  } catch (e) {
    print('⚠️ Local Database warning: $e');
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'Flashcard App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      home: const FlashcardListPage(),
    );
  }
}
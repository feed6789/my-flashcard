import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/core/providers/theme_provider.dart';
import 'package:flashcard_app/features/flashcard/presentation/pages/flashcard_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    print('✅ Local Database initialized successfully!');
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
    final themeColor = ref.watch(themeColorProvider);
    
    return MaterialApp(
      title: 'Flashcard App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(themeColor),
      darkTheme: AppTheme.darkTheme(themeColor),
      themeMode: themeMode,
      home: const FlashcardListPage(),
    );
  }
}
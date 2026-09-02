import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Thay thế bằng thông tin của bạn
  static const String url = 'https://faitsgsqijxfeybqewqx.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhaXRzZ3NxaWp4ZmV5YnFld3F4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwOTYwNjUsImV4cCI6MjEwMzY3MjA2NX0.iWaoxlqw_U7i7c9MvzM27Er0mrJzed2zyDw8gf5syjI';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}
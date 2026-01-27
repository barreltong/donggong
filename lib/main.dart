import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'view/app.dart';
import 'core/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Initialize Core (DB, State)
  await AppState.instance.init();

  runApp(const DonggongApp());
}

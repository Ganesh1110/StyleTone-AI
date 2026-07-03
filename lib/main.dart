import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/theme_service.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  cameras = await availableCameras();

  // Check if onboarding has been seen
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('onboarding_seen') ?? false;

  // Load saved theme before app starts
  await ThemeService.loadTheme();

  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeService.notifier,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'StyleTone AI',
          theme: theme,
          home: cameras != null && cameras!.isNotEmpty
              ? (seenOnboarding
                  ? HomeScreen(cameras: cameras!)
                  : OnboardingScreen(cameras: cameras!))
              : const Scaffold(
                  body: Center(
                    child: Text('No cameras available on this device.'),
                  ),
                ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

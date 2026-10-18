import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/iridiscope_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const IridiScopeApp());
}

class IridiScopeApp extends StatelessWidget {
  const IridiScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(
      seedColor: Colors.cyanAccent,
      brightness: Brightness.dark,
    );
    return ChangeNotifierProvider(
      create: (_) => IridiScopeService(),
      child: MaterialApp(
        title: 'IridiScope Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: base.copyWith(
            surface: const Color(0xff0b1018),
            surfaceContainerHighest: const Color(0xff151d29),
          ),
          scaffoldBackgroundColor: const Color(0xff070a10),
          cardTheme: const CardThemeData(
            color: Color(0xff111722),
            margin: EdgeInsets.zero,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xff0b1018),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          dividerColor: const Color(0x1fffffff),
          sliderTheme: const SliderThemeData(
            trackHeight: 2,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

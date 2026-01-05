import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web3refi/web3refi.dart';

import 'screens/home_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/tokens_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/messaging_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════════════════

/// Your WalletConnect Cloud Project ID
/// Get yours free at: https://cloud.walletconnect.com
const String walletConnectProjectId = 'YOUR_PROJECT_ID_HERE';

/// Supported chains for this example app
final List<Chain> supportedChains = [
  Chains.polygon,
  Chains.ethereum,
  Chains.arbitrum,
  Chains.base,
  Chains.optimism,
  // Testnets for development
  Chains.polygonMumbai,
  Chains.sepolia,
];

// ════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0a0a0a),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize web3refi
  await _initializeWeb3Refi();

  runApp(const Web3RefiExampleApp());
}

Future<void> _initializeWeb3Refi() async {
  try {
    await Web3Refi.initialize(
      config: Web3RefiConfig(
        projectId: walletConnectProjectId,
        chains: supportedChains,
        defaultChain: Chains.polygon,
        enableLogging: true, // Enable for development
        appMetadata: const AppMetadata(
          name: 'web3refi Example',
          description: 'Demonstrating the Universal Web3 SDK for Flutter',
          url: 'https://web3refi.dev',
          icons: ['https://web3refi.dev/icon.png'],
          redirect: 'web3refiexample://',
        ),
      ),
    );
    debugPrint('✅ web3refi initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize web3refi: $e');
  }
}

// ════════════════════════════════════════════════════════════════════════════
// APP
// ════════════════════════════════════════════════════════════════════════════

class Web3RefiExampleApp extends StatelessWidget {
  const Web3RefiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Web3Refi.instance,
      child: MaterialApp(
        title: 'web3refi Example',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const MainNavigator(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const primaryColor = Color(0xFF6366F1); // Indigo
    const backgroundColor = Color(0xFF0a0a0a);
    const surfaceColor = Color(0xFF1a1a1a);
    const cardColor = Color(0xFF262626);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: Color(0xFF22D3EE), // Cyan accent
        surface: surfaceColor,
        background: backgroundColor,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),
      cardColor: cardColor,
      dividerColor: Colors.white10,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white70,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN NAVIGATOR
// ════════════════════════════════════════════════════════════════════════════

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TokensScreen(),
    TransferScreen(),
    MessagingScreen(),
    WalletScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Tokens',
    ),
    NavigationDestination(
      icon: Icon(Icons.send_outlined),
      selectedIcon: Icon(Icons.send),
      label: 'Send',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat),
      label: 'Messages',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: _destinations,
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).primaryColor.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

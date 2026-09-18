import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mock_backend.dart';
import 'services/clover_api_service.dart';
import 'state/app_state.dart';
import 'screens/lender_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/borrower_screen.dart';
import 'widgets/disclaimer_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Toggle: set _useMock = false (and baseUrl) to connect to the live FastAPI
// backend. No screen widget changes are needed — only this one flag.
// ─────────────────────────────────────────────────────────────────────────────
const bool _useMock = true;
// When flipping to live: change _useMock to false and pass baseUrl to CloverHttpService.
// ignore: constant_identifier_names
const String _kBaseUrl = String.fromEnvironment('CLOVER_API_URL', defaultValue: 'http://localhost:8000');

void main() {
  final CloverApiService service =
      _useMock ? MockBackend() : _buildHttpService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(service),
      child: CloverApp(service: service),
    ),
  );
}

CloverApiService _buildHttpService() {
  // Import only when not using mock — avoids dart:io on web in mock-only builds.
  // When flipping to live: add `import 'services/clover_http_service.dart';`
  // and replace MockBackend() above with CloverHttpService(baseUrl: _kBaseUrl).
  throw UnimplementedError(
    'Set _useMock = true or import CloverHttpService(baseUrl: $_kBaseUrl)',
  );
}

class CloverApp extends StatelessWidget {
  final CloverApiService service;
  const CloverApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clover — Alternative Credit Signal',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: CloverShell(service: service),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F1117),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF1A1D2E),
        onSurface: Color(0xFFE5E7EB),
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFD1D5DB), fontFamily: 'Inter'),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF12141F),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF12141F),
        selectedItemColor: Color(0xFF6366F1),
        unselectedItemColor: Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontFamily: 'Inter'),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontFamily: 'Inter'),
      ),
    );
  }
}

class CloverShell extends StatefulWidget {
  final CloverApiService service;
  const CloverShell({super.key, required this.service});

  @override
  State<CloverShell> createState() => _CloverShellState();
}

class _CloverShellState extends State<CloverShell> {
  int _tabIndex = 0;

  // Tab order as specified in the task:
  // 0 = Lender, 1 = Consent, 2 = Portfolio, 3 = Borrower
  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_outlined),
      activeIcon: Icon(Icons.account_balance),
      label: 'Lender',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.verified_user_outlined),
      activeIcon: Icon(Icons.verified_user),
      label: 'Consent',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Portfolio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Borrower',
    ),
  ];

  // Screen titles kept for reference; displayed in AppBar via tab label only.
  // (removed as unused field — each screen has its own heading)

  @override
  Widget build(BuildContext context) {
    // The disclaimer text is pulled from the mock (or live) data.
    // For startup we show the standard fixed text; once a result is loaded
    // the exact API disclaimer is displayed via the analyzeResult.
    const disclaimer =
        'Research prototype on synthetic data. Not a lending decision system. '
        'Decision-support signal only — final lending decision rests with the lender.';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Clover'),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'PROTOTYPE',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: const Text(
                'PS-F02',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Persistent disclaimer banner — visible on every screen
          const DisclaimerBanner(text: disclaimer),
          // Page body
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                const LenderScreen(),
                const ConsentScreen(),
                PortfolioScreen(service: widget.service),
                const BorrowerScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: _navItems,
      ),
    );
  }
}

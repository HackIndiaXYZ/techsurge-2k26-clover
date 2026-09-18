import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mock_backend.dart';
import 'services/credify_api_service.dart';
import 'services/credify_http_service.dart';
import 'state/app_state.dart';
import 'screens/lender_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/borrower_screen.dart';
import 'widgets/disclaimer_banner.dart';

// Live FastAPI backend by default. Run with --dart-define=CREDIFY_USE_MOCK=true
// to use the in-memory MockBackend instead, and --dart-define=CREDIFY_API_URL=...
// to point at a server other than http://localhost:8000.
const bool _useMock = bool.fromEnvironment('CREDIFY_USE_MOCK');
const String _kBaseUrl = String.fromEnvironment('CREDIFY_API_URL', defaultValue: 'http://localhost:8000');

void main() {
  final CredifyApiService service =
      _useMock ? MockBackend() : CredifyHttpService(baseUrl: _kBaseUrl);

  runApp(CredifyApp(service: service));
}

class CredifyApp extends StatelessWidget {
  final CredifyApiService service;
  const CredifyApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(service),
      child: MaterialApp(
        title: 'Credify — Alternative Credit Signal',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: CredifyShell(service: service),
      ),
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

class CredifyShell extends StatefulWidget {
  final CredifyApiService service;
  const CredifyShell({super.key, required this.service});

  @override
  State<CredifyShell> createState() => _CredifyShellState();
}

class _CredifyShellState extends State<CredifyShell> {
  int _tabIndex = 0;

  // Tab order:
  // 0 = Consent, 1 = Lender, 2 = Borrower, 3 = Portfolio
  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.verified_user_outlined),
      activeIcon: Icon(Icons.verified_user),
      label: 'Consent',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_outlined),
      activeIcon: Icon(Icons.account_balance),
      label: 'Lender',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Borrower',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Portfolio',
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
            const Text('Credify'),
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
                const ConsentScreen(),
                const LenderScreen(),
                const BorrowerScreen(),
                PortfolioScreen(service: widget.service),
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

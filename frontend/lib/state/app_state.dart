import 'package:flutter/foundation.dart';
import '../models/analyze_response.dart';
import '../services/clover_api_service.dart';

enum LenderStep { idle, bureauChecked, clovering, done }

class AppState extends ChangeNotifier {
  final CloverApiService service;

  AppState(this.service);

  // ── Selected profile ─────────────────────────────────────────────────────
  String _selectedProfileId = 'lakshmi_vendor_001';
  String get selectedProfileId => _selectedProfileId;

  List<String> get availableProfileIds => service.getAvailableProfileIds();

  void selectProfile(String id) {
    _selectedProfileId = id;
    // Reset flow so the new profile goes through bureau check again
    _lenderStep = LenderStep.idle;
    _analyzeResult = null;
    _analyzeError = null;
    _consentApproved = false;
    notifyListeners();
  }

  // ── Consent state ─────────────────────────────────────────────────────────
  bool _consentApproved = false;
  bool _consentLoading = false;
  bool get consentApproved => _consentApproved;
  bool get consentLoading => _consentLoading;

  Future<void> approveConsent() async {
    _consentLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1200));
    _consentApproved = true;
    _consentLoading = false;
    _lenderStep = LenderStep.idle;
    _analyzeResult = null;
    _analyzeError = null;
    notifyListeners();
  }

  void revokeConsent() {
    _consentApproved = false;
    _lenderStep = LenderStep.idle;
    _analyzeResult = null;
    _analyzeError = null;
    notifyListeners();
  }

  // ── Lender screen step machine ─────────────────────────────────────────
  LenderStep _lenderStep = LenderStep.idle;
  LenderStep get lenderStep => _lenderStep;

  void runBureauCheck() {
    _lenderStep = LenderStep.bureauChecked;
    notifyListeners();
  }

  // ── Analyze result ────────────────────────────────────────────────────
  AnalyzeResponse? _analyzeResult;
  bool _analyzeLoading = false;
  String? _analyzeError;

  AnalyzeResponse? get analyzeResult => _analyzeResult;
  bool get analyzeLoading => _analyzeLoading;
  String? get analyzeError => _analyzeError;

  Future<void> runCloverAnalysis() async {
    _lenderStep = LenderStep.clovering;
    _analyzeLoading = true;
    _analyzeError = null;
    notifyListeners();

    try {
      final result = await service.analyzeProfile(_selectedProfileId);
      _analyzeResult = result;
      _lenderStep = LenderStep.done;
    } catch (e) {
      _analyzeError = e.toString();
      _lenderStep = LenderStep.bureauChecked;
    } finally {
      _analyzeLoading = false;
      notifyListeners();
    }
  }

  void resetLenderFlow() {
    _lenderStep = LenderStep.idle;
    _analyzeResult = null;
    _analyzeError = null;
    notifyListeners();
  }
}

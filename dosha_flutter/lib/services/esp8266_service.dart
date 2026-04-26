import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';

// ── IR threshold: finger present when IR > this value ────────────────────────
const int _irFingerThreshold = 10000;

// ── How many readings to collect before showing result (2s interval × 30 = 60s)
const int _bufferTarget = 30;

class VitalsData {
  final double hr;
  final double spo2;
  final double temp;
  final int ir;

  VitalsData({
    required this.hr,
    required this.spo2,
    required this.temp,
    required this.ir,
  });

  factory VitalsData.fromJson(Map<String, dynamic> json) {
    return VitalsData(
      hr:   (json['hr']   as num).toDouble(),
      spo2: (json['spo2'] as num).toDouble(),
      temp: (json['temp'] as num).toDouble(),
      ir:   json['ir']   as int,
    );
  }
}

/// A snapshot saved after each completed measurement.
class SessionRecord {
  final VitalsData vitals;
  final DateTime timestamp;
  SessionRecord({required this.vitals, required this.timestamp});
}

class Esp8266Service extends ChangeNotifier {
  String _ipAddress = "192.168.1.100";
  Timer? _timer;

  // ── State ─────────────────────────────────────────────────────────────────
  bool   _isPolling        = false;
  String _error            = "";

  // Finger & measurement
  bool   _isFingerPresent  = false;
  bool   _isMeasuring      = false;   // true while collecting 60 s buffer
  int    _bufferCount      = 0;       // readings collected so far

  // Buffers for averaging
  final List<double> _hrBuf   = [];
  final List<double> _spo2Buf = [];
  final List<double> _tempBuf = [];

  // Stable averaged result shown on UI (null = not ready yet)
  VitalsData? _stableVitals;

  // Session history — up to 10 most recent completed readings
  final List<SessionRecord> _sessionHistory = [];

  // Simulation
  bool   _isSimulationMode = false;
  double _simHr   = 75.0;
  double _simSpo2 = 98.0;
  double _simTemp = 36.5;

  // ── Getters ───────────────────────────────────────────────────────────────
  String      get ipAddress       => _ipAddress;
  bool        get isPolling       => _isPolling;
  String      get error           => _error;
  bool        get isFingerPresent => _isFingerPresent;
  bool        get isMeasuring     => _isMeasuring;
  /// 0.0 → 1.0 progress through the 60-second window
  double      get measureProgress => _bufferCount / _bufferTarget;
  int         get secondsElapsed  => _bufferCount * 2;
  int         get secondsLeft     => (_bufferTarget - _bufferCount) * 2;
  VitalsData? get latestVitals    => _stableVitals;
  List<SessionRecord> get sessionHistory => List.unmodifiable(_sessionHistory);

  bool   get isSimulationMode => _isSimulationMode;
  double get simHr   => _simHr;
  double get simSpo2 => _simSpo2;
  double get simTemp => _simTemp;

  // ── IP ────────────────────────────────────────────────────────────────────
  void setIpAddress(String ip) {
    _ipAddress = ip;
    notifyListeners();
  }

  // ── History ───────────────────────────────────────────────────────────────
  void addToHistory(VitalsData v) {
    _sessionHistory.add(SessionRecord(vitals: v, timestamp: DateTime.now()));
    if (_sessionHistory.length > 10) _sessionHistory.removeAt(0);
    notifyListeners();
  }

  void clearHistory() {
    _sessionHistory.clear();
    notifyListeners();
  }

  // ── Simulation mode ───────────────────────────────────────────────────────
  void toggleSimulationMode(bool value) {
    _isSimulationMode = value;
    if (_isSimulationMode) {
      if (_isPolling) stopPolling();
      _resetBuffer();
      _isFingerPresent = true;   // simulation always has "finger"
      _isMeasuring     = false;
      _stableVitals    = VitalsData(
          hr: _simHr, spo2: _simSpo2, temp: _simTemp, ir: 60000);
    } else {
      _stableVitals    = null;
      _isFingerPresent = false;
      _isMeasuring     = false;
    }
    notifyListeners();
  }

  void updateSimVitals(double hr, double spo2, double temp) {
    _simHr   = hr;
    _simSpo2 = spo2;
    _simTemp = temp;
    if (_isSimulationMode) {
      _stableVitals = VitalsData(hr: hr, spo2: spo2, temp: temp, ir: 60000);
      notifyListeners();
    }
  }

  // ── Live polling ──────────────────────────────────────────────────────────
  void startPolling() {
    if (_isPolling) return;
    _isSimulationMode = false;
    _isPolling        = true;
    _error            = "";
    _resetBuffer();
    _stableVitals     = null;
    _isFingerPresent  = false;
    notifyListeners();
    _timer = Timer.periodic(
        const Duration(seconds: 2), (_) async => _fetchAndProcess());
  }

  void stopPolling() {
    _timer?.cancel();
    _isPolling       = false;
    _isMeasuring     = false;
    _isFingerPresent = false;
    _stableVitals    = null;
    _resetBuffer();
    notifyListeners();
  }

  // ── Core fetch + processing ───────────────────────────────────────────────
  Future<void> _fetchAndProcess() async {
    if (_isSimulationMode) return;

    VitalsData? raw;
    try {
      final res = await http
          .get(Uri.parse('http://$_ipAddress/data'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        raw    = VitalsData.fromJson(json.decode(res.body));
        _error = "";
      } else {
        _error = "Server error: ${res.statusCode}";
      }
    } catch (_) {
      _error = "Connection failed. Check IP & network.";
    }

    if (raw == null) {
      notifyListeners();
      return;
    }

    // ── Finger detection ────────────────────────────────────────────────────
    final fingerNow = raw.ir > _irFingerThreshold;

    if (!fingerNow) {
      // Finger removed → reset everything
      if (_isFingerPresent || _isMeasuring || _stableVitals != null) {
        _isFingerPresent = false;
        _isMeasuring     = false;
        _stableVitals    = null;
        _resetBuffer();
        notifyListeners();
      }
      return;
    }

    // Finger is present
    _isFingerPresent = true;

    if (!_isMeasuring && _stableVitals == null) {
      // Start fresh measurement window
      _isMeasuring = true;
      _resetBuffer();
    }

    if (_isMeasuring) {
      // Accumulate into buffer
      _hrBuf.add(raw.hr);
      _spo2Buf.add(raw.spo2);
      _tempBuf.add(raw.temp);
      _bufferCount++;

      if (_bufferCount >= _bufferTarget) {
        // 60 seconds reached → compute averages
        final avgHr   = _hrBuf.reduce((a, b) => a + b)   / _hrBuf.length;
        final avgSpo2 = _spo2Buf.reduce((a, b) => a + b) / _spo2Buf.length;
        final avgTemp = _tempBuf.reduce((a, b) => a + b) / _tempBuf.length;

        _stableVitals = VitalsData(
            hr: avgHr, spo2: avgSpo2, temp: avgTemp, ir: raw.ir);
        addToHistory(_stableVitals!);
        _isMeasuring  = false;
        _resetBuffer();
      }
    }

    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _resetBuffer() {
    _hrBuf.clear();
    _spo2Buf.clear();
    _tempBuf.clear();
    _bufferCount = 0;
  }

  // Allow manual re-measurement
  void remeasure() {
    if (!_isPolling || _isSimulationMode) return;
    _stableVitals = null;
    _isMeasuring  = false;
    _resetBuffer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

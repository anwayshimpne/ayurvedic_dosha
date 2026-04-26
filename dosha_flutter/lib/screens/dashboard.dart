import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/esp8266_service.dart';
import '../logic/dosha_calculator.dart';
import '../logic/knowledge_base.dart';
import 'settings.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _bg       = Color(0xFF0A0E1A);
const _card     = Color(0xFF141928);
const _cardHi   = Color(0xFF1C2438);
const _teal     = Color(0xFF00D4AA);
const _orange   = Color(0xFFFF6B35);
const _purple   = Color(0xFF7B61FF);
const _red      = Color(0xFFFF4D6D);
const _blue     = Color(0xFF4DA6FF);
const _muted    = Color(0xFFB0BEC5);

Color _doshaColor(String d) {
  switch (d) {
    case 'vata':  return _purple;
    case 'pitta': return _orange;
    case 'kapha': return _teal;
    default:      return _teal;
  }
}

String _doshaEmoji(String d) {
  switch (d) {
    case 'vata':  return '🌬️';
    case 'pitta': return '🔥';
    case 'kapha': return '🌊';
    default:      return '✨';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() { _wave.dispose(); super.dispose(); }

  // ── Root build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(context),
      body: Consumer<Esp8266Service>(
        builder: (ctx, svc, _) {
          final v = svc.latestVitals;
          DoshaPrediction? pred;
          Map<String, double>? pct;
          Map<String, dynamic>? kb;

          if (v != null) {
            pred = DoshaCalculator.predict(v.hr, v.spo2, v.temp);
            pct  = DoshaCalculator.calculateDoshaPercentages(v.hr, v.spo2, v.temp);
            kb   = KnowledgeBase.herbKnowledge[pred.dosha];
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _banner(),
                const SizedBox(height: 14),
                _toggleCard(svc),
                const SizedBox(height: 14),

                if (svc.isSimulationMode) ...[
                  _sliderCard(svc),
                  const SizedBox(height: 14),
                ] else ...[
                  _connectionCard(svc),
                  const SizedBox(height: 14),
                ],

                // ── Finger Detection Warning ──
                if (svc.isPolling && !svc.isSimulationMode && !svc.isFingerPresent) ...[
                  _glass(
                    borderColor: _red.withOpacity(0.5),
                    child: Column(
                      children: [
                        const Icon(Icons.fingerprint_rounded, color: _red, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'FINGER NOT DETECTED',
                          style: TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please place your finger firmly on the sensor pulse module.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Measurement Progress ──
                if (svc.isMeasuring) ...[
                  _glass(
                    borderColor: _teal.withOpacity(0.5),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Measuring Vitals...', style: TextStyle(color: _teal, fontWeight: FontWeight.bold)),
                            Text('${svc.secondsLeft}s left', style: const TextStyle(color: _muted, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: svc.measureProgress,
                            backgroundColor: Colors.white10,
                            color: _teal,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Keep your finger still for 60 seconds to get an accurate Dosha reading.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (v != null) ...[
                  _ecgCard(v.hr),
                  const SizedBox(height: 14),
                  _vitalsRow(v),
                  const SizedBox(height: 14),
                  if (pct != null && pred != null) ...[
                    _doshaCard(pct, pred.dosha),
                    const SizedBox(height: 14),
                    _predCard(pred),
                  ],
                  if (pred != null && kb != null) ...[
                    const SizedBox(height: 14),
                    _recoSection(pred, kb),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: svc.remeasure,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                    label: const Text('Re-measure', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ] else if (svc.isPolling && !svc.isMeasuring && svc.isFingerPresent) ...[
                  _waitCard(),
                ] else if (!svc.isPolling) ...[
                  _idleCard(),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<Esp8266Service>(
        builder: (ctx, svc, _) {
          if (svc.isSimulationMode) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => svc.isPolling ? svc.stopPolling() : svc.startPolling(),
            icon: Icon(svc.isPolling ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(svc.isPolling ? 'Stop' : 'Live Monitor'),
            backgroundColor: svc.isPolling ? _red : _teal,
            foregroundColor: Colors.black,
          );
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _appBar(BuildContext ctx) => AppBar(
    backgroundColor: _bg,
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _purple]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.spa_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Sukshma Buddhi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.settings_rounded, color: _muted),
        onPressed: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    ],
  );

  // ── Banner ────────────────────────────────────────────────────────────────
  Widget _banner() => _glass(
    borderColor: _teal.withOpacity(0.25),
    child: const Row(
      children: [
        Icon(Icons.monitor_heart_rounded, color: _teal, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ayurvedic Health Monitor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              SizedBox(height: 2),
              Text('Real-time dosha prediction via biosensor data',
                  style: TextStyle(fontSize: 12, color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Toggles ───────────────────────────────────────────────────────────────
  Widget _toggleCard(Esp8266Service svc) => _glass(
    child: Column(
      children: [
        _toggleRow('🎮  Simulation Mode', 'Demo without ESP8266',
            svc.isSimulationMode, _teal, svc.toggleSimulationMode),
        const Divider(color: Colors.white10, height: 20),
        _toggleRow('📡  Live Monitor', 'Fetch data from ESP8266',
            svc.isPolling && !svc.isSimulationMode, _blue, (v) {
          v ? svc.startPolling() : svc.stopPolling();
        }),
      ],
    ),
  );

  Widget _toggleRow(String title, String sub, bool val, Color color,
      ValueChanged<bool> cb) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        color: Colors.white, fontSize: 13)),
                Text(sub, style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          Switch(
            value: val,
            activeColor: color,
            inactiveTrackColor: Colors.white12,
            onChanged: cb,
          ),
        ],
      );

  // ── Simulation sliders ────────────────────────────────────────────────────
  Widget _sliderCard(Esp8266Service svc) => _glass(
    borderColor: _teal.withOpacity(0.35),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.tune_rounded, color: _teal, size: 18),
          SizedBox(width: 8),
          Text('Adjust Vitals',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _teal)),
        ]),
        const SizedBox(height: 14),
        _sliderRow('Heart Rate', svc.simHr, 40, 140, 'bpm', _red,
            (v) => svc.updateSimVitals(v, svc.simSpo2, svc.simTemp)),
        const SizedBox(height: 8),
        _sliderRow('SpO₂', svc.simSpo2, 80, 100, '%', _blue,
            (v) => svc.updateSimVitals(svc.simHr, v, svc.simTemp)),
        const SizedBox(height: 8),
        _sliderRow('Temperature', svc.simTemp, 34.0, 40.0, '°C', _orange,
            (v) => svc.updateSimVitals(svc.simHr, svc.simSpo2, v)),
      ],
    ),
  );

  Widget _sliderRow(String label, double val, double min, double max,
      String unit, Color color, ValueChanged<double> cb) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text('${val.toStringAsFixed(1)} $unit',
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(value: val, min: min, max: max, onChanged: cb),
          ),
        ],
      );

  // ── ECG waveform ──────────────────────────────────────────────────────────
  Widget _ecgCard(double hr) {
    final ms = ((60.0 / math.max(40, hr)) * 1000).toInt();
    _wave.duration = Duration(milliseconds: ms);
    if (!_wave.isAnimating) _wave.repeat();

    return _glass(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: _red, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Live Pulse Wave',
                style: TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            Text('${hr.toStringAsFixed(0)} bpm',
                style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: AnimatedBuilder(
              animation: _wave,
              builder: (_, __) => CustomPaint(
                painter: _ECGPainter(_wave.value, hr),
                size: const Size(double.infinity, 70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vitals row ────────────────────────────────────────────────────────────
  Widget _vitalsRow(VitalsData v) => Row(
    children: [
      Expanded(child: _vitalCard('Heart Rate', v.hr, 'bpm', _red,
          Icons.favorite_rounded, v.hr < 50 || v.hr > 120)),
      const SizedBox(width: 10),
      Expanded(child: _vitalCard('SpO₂', v.spo2, '%', _blue,
          Icons.water_drop_rounded, v.spo2 < 92)),
      const SizedBox(width: 10),
      Expanded(child: _vitalCard('Temp', v.temp, '°C', _orange,
          Icons.thermostat_rounded, v.temp > 38.0, dec: 1)),
    ],
  );

  Widget _vitalCard(String title, double val, String unit, Color color,
      IconData icon, bool alert, {int dec = 0}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardHi,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: alert ? _red.withOpacity(0.6) : color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08),
                blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(color: _muted, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${val.toStringAsFixed(dec)} $unit',
                style: TextStyle(color: color, fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            if (alert) ...[
              const SizedBox(height: 4),
              const Icon(Icons.warning_amber_rounded, color: _red, size: 14),
            ],
          ],
        ),
      );

  // ── Dosha analysis ────────────────────────────────────────────────────────
  Widget _doshaCard(Map<String, double> pct, String dom) => _glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.analytics_rounded, color: _teal, size: 18),
          SizedBox(width: 8),
          Text('Dosha Analysis',
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 16, color: Colors.white)),
        ]),
        const SizedBox(height: 18),
        _doshaBar('Vata 🌬️', pct['vata']!, _purple, dom == 'vata'),
        const SizedBox(height: 14),
        _doshaBar('Pitta 🔥', pct['pitta']!, _orange, dom == 'pitta'),
        const SizedBox(height: 14),
        _doshaBar('Kapha 🌊', pct['kapha']!, _teal, dom == 'kapha'),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _doshaColor(dom).withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _doshaColor(dom).withOpacity(0.5)),
            ),
            child: Text(
              'DOMINANT: ${dom.toUpperCase()}',
              style: TextStyle(
                  color: _doshaColor(dom),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 13),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _doshaBar(String label, double pct, Color color, bool dom) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: dom ? Colors.white : _muted,
                      fontWeight:
                          dom ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
              Text('${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (_, c) => Stack(
              children: [
                Container(
                    height: dom ? 10 : 7,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: dom ? 10 : 7,
                  width: c.maxWidth * (pct / 100),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withOpacity(0.6), color]),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: dom
                        ? [BoxShadow(
                            color: color.withOpacity(0.5), blurRadius: 8)]
                        : [],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── Prediction card ───────────────────────────────────────────────────────
  Widget _predCard(DoshaPrediction pred) {
    final c = _doshaColor(pred.dosha);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [c.withOpacity(0.7), c.withOpacity(0.35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: c.withOpacity(0.3), blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Text(_doshaEmoji(pred.dosha),
              style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 4),
          const Text('PREDICTED DOSHA',
              style: TextStyle(color: Colors.white70,
                  letterSpacing: 2, fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(pred.dosha.toUpperCase(),
              style: const TextStyle(color: Colors.white,
                  fontSize: 36, fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _predSub('Confidence', pred.confidence.toUpperCase()),
              Container(width: 1, height: 30, color: Colors.white30),
              _predSub('Strength',
                  pred.recommendationStrength.toUpperCase()),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            DoshaCalculator.getCautionText(pred.dosha, pred.confidence),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white60, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _predSub(String t, String v) => Column(
    children: [
      Text(t,
          style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 4),
      Text(v,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
    ],
  );

  // ── Recommendations ───────────────────────────────────────────────────────
  Widget _recoSection(DoshaPrediction pred, Map<String, dynamic> kb) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommendations',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _listSection('🌿  Primary Herbs',
              kb['primary_herbs'] as List<String>, _teal),
          const SizedBox(height: 12),
          _listSection('🍲  Diet Support',
              kb['diet_support'] as List<String>, _orange),
          const SizedBox(height: 12),
          _listSection('🧘  Lifestyle',
              kb['lifestyle_support'] as List<String>, _purple),
        ],
      );

  Widget _listSection(String title, List<String> items, Color accent) =>
      _glass(
        borderColor: accent.withOpacity(0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: accent)),
            const Divider(color: Colors.white10, height: 18),
            ...items.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: accent, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e,
                        style: const TextStyle(
                            color: _muted, height: 1.4, fontSize: 13)),
                  ),
                ],
              ),
            )),
          ],
        ),
      );

  // ── Connection / wait / idle ──────────────────────────────────────────────
  Widget _connectionCard(Esp8266Service svc) => _glass(
    borderColor:
        svc.isPolling ? _teal.withOpacity(0.4) : Colors.white12,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (svc.isPolling ? _teal : Colors.grey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            svc.isPolling ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: svc.isPolling ? _teal : Colors.grey, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                svc.isPolling ? 'Connected to ESP8266' : 'Not Connected',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: svc.isPolling ? _teal : Colors.grey)),
              Text('IP: ${svc.ipAddress}',
                  style:
                      const TextStyle(fontSize: 12, color: _muted)),
              if (svc.error.isNotEmpty)
                Text(svc.error,
                    style: const TextStyle(color: _red, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _waitCard() => _glass(
    child: const Column(
      children: [
        CircularProgressIndicator(color: _teal, strokeWidth: 2),
        SizedBox(height: 14),
        Text('Waiting for ESP8266 data…',
            style: TextStyle(color: _muted)),
      ],
    ),
  );

  Widget _idleCard() => _glass(
    child: Column(
      children: [
        const Icon(Icons.sensors_off_rounded, color: _muted, size: 40),
        const SizedBox(height: 12),
        const Text(
          'Enable Simulation Mode or toggle Live Monitor\nto see vitals.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.5),
        ),
      ],
    ),
  );

  // ── Glass card helper ─────────────────────────────────────────────────────
  Widget _glass({
    required Widget child,
    Color? borderColor,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor ?? Colors.white10),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 12,
                offset: Offset(0, 4))
          ],
        ),
        child: child,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  ECG painter
// ═════════════════════════════════════════════════════════════════════════════
class _ECGPainter extends CustomPainter {
  final double t;
  final double hr;
  _ECGPainter(this.t, this.hr);

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = _red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    const wl = 120.0;
    final off = -(t * wl);
    final cy = size.height / 2;

    for (double x = 0; x <= size.width; x++) {
      final rx = (x - off) % wl;
      double y = cy;

      if (rx > 20 && rx < 30) {
        y -= math.sin((rx - 20) / 10 * math.pi) * 8;
      } else if (rx > 40 && rx < 56) {
        if (rx < 44)      { y += (rx - 40) * 2; }
        else if (rx < 48) { y -= (rx - 44) * 18; }
        else if (rx < 52) { y += (52 - rx) * 18; }
        else              { y += (rx - 52) * 2; }
      } else if (rx > 65 && rx < 85) {
        y -= math.sin((rx - 65) / 20 * math.pi) * 10;
      }

      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _ECGPainter old) =>
      old.t != t || old.hr != hr;
}

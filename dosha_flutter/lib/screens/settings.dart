import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/esp8266_service.dart';

const _bg    = Color(0xFF0A0E1A);
const _card  = Color(0xFF141928);
const _teal  = Color(0xFF00D4AA);
const _muted = Color(0xFFB0BEC5);
const _red   = Color(0xFFFF4D6D);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipCtrl.text =
        Provider.of<Esp8266Service>(context, listen: false).ipAddress;
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section title ──────────────────────────────────────────────
            const Text('ESP8266 Configuration',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _teal)),
            const SizedBox(height: 6),
            const Text(
              'Enter the local IP address of your ESP8266 device.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 20),

            // ── IP input ───────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _teal.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _ipCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  labelStyle: TextStyle(color: _muted),
                  hintText: 'e.g. 192.168.1.100',
                  hintStyle: TextStyle(color: Colors.white24),
                  prefixIcon: Icon(Icons.router_rounded, color: _teal),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final ip = _ipCtrl.text.trim();
                  if (ip.isEmpty) return;
                  Provider.of<Esp8266Service>(context, listen: false)
                      .setIpAddress(ip);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('IP Address saved!'),
                      backgroundColor: _teal.withOpacity(0.9),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save_rounded, color: Colors.black),
                label: const Text('Save',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Info box ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: _red, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Make sure your phone and ESP8266 are on the same Wi-Fi network.',
                      style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

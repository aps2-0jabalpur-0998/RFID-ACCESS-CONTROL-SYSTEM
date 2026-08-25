import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuardianEyeApp());
}

class GuardianEyeApp extends StatelessWidget {
  const GuardianEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GuardianEye AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF04080D),
        fontFamily: 'Segoe UI',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF42E8FF),
          secondary: Color(0xFF53FF9D),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class GuardianAlert {
  final int id;
  final String type;
  final String rawMessage;
  final String speech;
  final String receivedAt;

  const GuardianAlert({
    required this.id,
    required this.type,
    required this.rawMessage,
    required this.speech,
    required this.receivedAt,
  });

  factory GuardianAlert.fromJson(Map<String, dynamic> json) {
    return GuardianAlert(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      type: '${json['type'] ?? 'ALERT'}',
      rawMessage: '${json['raw_message'] ?? ''}',
      speech: '${json['speech'] ?? ''}',
      receivedAt: '${json['received_at'] ?? ''}',
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const defaultServer =
      'https://dim-handle-packed-veterans.trycloudflare.com';

  final FlutterTts _tts = FlutterTts();
  late final AnimationController _faceController;

  Timer? _pollTimer;
  String _serverUrl = defaultServer;
  bool _connected = false;
  GuardianAlert? _latestAlert;
  int _lastSeenAlertId = 0;
  bool _showAlert = false;
  String _message = 'GuardianEye AI online. Awaiting security events.';

  @override
  void initState() {
    super.initState();
    _faceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadServer();
  }

  Future<void> _loadServer() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.trim().isNotEmpty) {
      _serverUrl = saved.trim();
    }
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollAlert();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollAlert();
    });
  }

  String get _baseUrl {
    var value = _serverUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<void> _pollAlert() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/alert'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid alert payload');
      }

      final alert = GuardianAlert.fromJson(decoded);

      if (!mounted) return;
      setState(() => _connected = true);

      // IMPORTANT: no alert is shown on refresh/startup.
      // Only an alert with a NEW id is displayed.
      if (alert.id > 0 && alert.id != _lastSeenAlertId) {
        _lastSeenAlertId = alert.id;
        await _handleNewAlert(alert);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _connected = false);
    }
  }

  Future<void> _handleNewAlert(GuardianAlert alert) async {
    if (!mounted) return;

    setState(() {
      _latestAlert = alert;
      _showAlert = true;
      _message = alert.speech.isNotEmpty ? alert.speech : alert.rawMessage;
    });

    await _speak(alert.speech.isNotEmpty ? alert.speech : alert.rawMessage);

    await Future<void>.delayed(const Duration(seconds: 6));
    if (!mounted) return;
    setState(() => _showAlert = false);
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(0.88);
      await _tts.speak(text);
    } catch (_) {
      // Voice failure must not break the alert UI.
    }
  }

  Future<void> _editServer() async {
    final controller = TextEditingController(text: _serverUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF08121C),
          title: const Text('Cloudflare Server'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://your-tunnel.trycloudflare.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', result);
    setState(() {
      _serverUrl = result;
      _connected = false;
      _lastSeenAlertId = 0;
    });
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _faceController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const _HudBackground(),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 28 : 16,
                    18,
                    wide ? 28 : 16,
                    28,
                  ),
                  child: Column(
                    children: [
                      _Header(
                        connected: _connected,
                        onSettings: _editServer,
                      ),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _buildCenter()),
                            const SizedBox(width: 18),
                            Expanded(flex: 4, child: _buildSide()),
                          ],
                        )
                      else ...[
                        _buildCenter(),
                        const SizedBox(height: 18),
                        _buildSide(),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (_showAlert && _latestAlert != null)
              _AlertOverlay(
                alert: _latestAlert!,
                onDismiss: () => setState(() => _showAlert = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter() {
    final alert = _latestAlert;
    final alertMode = _showAlert || alert != null && alert.type == 'INTRUDER';

    return _HudPanel(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _faceController,
            builder: (context, child) {
              final angle = math.sin(_faceController.value * math.pi) * 0.09;
              return Transform.rotate(angle: angle, child: child);
            },
            child: JarvisFace(alert: alertMode),
          ),
          const SizedBox(height: 18),
          Text(
            _showAlert ? 'LIVE SECURITY ALERT' : 'JARVIS COMMAND CORE',
            style: TextStyle(
              color: _showAlert
                  ? const Color(0xFFFF4B61)
                  : const Color(0xFF7F9DA8),
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE9FBFF),
              fontSize: 17,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSide() {
    return Column(
      children: [
        _HudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('SYSTEM STATUS'),
              const SizedBox(height: 12),
              _StatusRow(
                label: 'CLOUDFLARE LINK',
                value: _connected ? 'ONLINE' : 'OFFLINE',
                good: _connected,
              ),
              _StatusRow(
                label: 'ALERT ENGINE',
                value: 'ARMED',
                good: true,
              ),
              _StatusRow(
                label: 'ALERT MODE',
                value: 'NEW EVENTS ONLY',
                good: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _HudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('LATEST ALERT'),
              const SizedBox(height: 12),
              if (_latestAlert == null)
                const Text(
                  'No alert received yet.',
                  style: TextStyle(color: Color(0xFF7F9DA8)),
                )
              else ...[
                Text(
                  _latestAlert!.type,
                  style: const TextStyle(
                    color: Color(0xFFFF4B61),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _latestAlert!.rawMessage,
                  style: const TextStyle(
                    color: Color(0xFFE9FBFF),
                    height: 1.35,
                  ),
                ),
                if (_latestAlert!.receivedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _latestAlert!.receivedAt,
                    style: const TextStyle(
                      color: Color(0xFF7F9DA8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _HudPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ModuleChip('INTRUDER'),
              _ModuleChip('ANIMAL AI'),
              _ModuleChip('VEHICLE AI'),
              _ModuleChip('GPS'),
              _ModuleChip('DRONE'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final bool connected;
  final VoidCallback onSettings;

  const _Header({required this.connected, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'GUARDIANEYE AI',
            style: TextStyle(
              color: Color(0xFF42E8FF),
              letterSpacing: 3.2,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: connected
                ? const Color(0x0F53FF9D)
                : const Color(0x0FFF4B61),
            border: Border.all(
              color: connected
                  ? const Color(0x5953FF9D)
                  : const Color(0x59FF4B61),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            connected ? '● LIVE' : '● OFFLINE',
            style: TextStyle(
              color: connected
                  ? const Color(0xFF53FF9D)
                  : const Color(0xFFFF4B61),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.tune, color: Color(0xFF42E8FF)),
          tooltip: 'Cloudflare server',
        ),
      ],
    );
  }
}

class _HudPanel extends StatelessWidget {
  final Widget child;
  const _HudPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE008121C),
        border: Border.all(color: const Color(0x4642E8FF)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D42E8FF),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF7F9DA8),
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool good;

  const _StatusRow({required this.label, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFB8D0D7), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: good ? const Color(0xFF53FF9D) : const Color(0xFFFF4B61),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleChip extends StatelessWidget {
  final String text;
  const _ModuleChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x3542E8FF)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0x0A42E8FF),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF42E8FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class JarvisFace extends StatelessWidget {
  final bool alert;
  const JarvisFace({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final accent = alert ? const Color(0xFFFF4B61) : const Color(0xFF42E8FF);
    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(.55)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(.13),
                  blurRadius: 36,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          Container(
            width: 215,
            height: 215,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(.18)),
            ),
          ),
          Container(
            width: 185,
            height: 185,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(.10)),
            ),
          ),
          Positioned(
            top: 93,
            left: 70,
            child: _Eye(color: accent),
          ),
          Positioned(
            top: 93,
            right: 70,
            child: _Eye(color: accent),
          ),
          Positioned(
            bottom: 67,
            child: Container(
              width: 70,
              height: 13,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: accent, width: 2)),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(.4), blurRadius: 14),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _FaceTicksPainter(color: accent)),
          ),
        ],
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  final Color color;
  const _Eye({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: color.withOpacity(.8), blurRadius: 18)],
      ),
    );
  }
}

class _FaceTicksPainter extends CustomPainter {
  final Color color;
  const _FaceTicksPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(.45)
      ..strokeWidth = 1.2;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 7;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi * 2 / 24;
      final p1 = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      final p2 = Offset(c.dx + math.cos(a) * (r - (i % 3 == 0 ? 9 : 5)), c.dy + math.sin(a) * (r - (i % 3 == 0 ? 9 : 5)));
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceTicksPainter oldDelegate) => oldDelegate.color != color;
}

class _AlertOverlay extends StatelessWidget {
  final GuardianAlert alert;
  final VoidCallback onDismiss;

  const _AlertOverlay({required this.alert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: const Color(0xE60B0206),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 560,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xF20B1118),
                border: Border.all(color: const Color(0xFFFF4B61), width: 1.5),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x55FF4B61), blurRadius: 45),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 58, color: Color(0xFFFF4B61)),
                  const SizedBox(height: 12),
                  const Text(
                    'GUARDIANEYE AI ALERT',
                    style: TextStyle(
                      color: Color(0xFFFF4B61),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    alert.type.replaceAll('_', ' '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE9FBFF),
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alert.rawMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB8D0D7), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: onDismiss,
                    child: const Text('DISMISS'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudBackground extends StatelessWidget {
  const _HudBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _GridPainter()),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0842E8FF)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

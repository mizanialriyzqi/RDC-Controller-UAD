import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const MyHomePage(title: '😎 Kelompok 1 RDC Costum Controller Transbot 🎮'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Offset leftJoystick = Offset.zero;
  double joystickRadius = 80;

  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isConnected = false;
  String targetDeviceAddress = "00:11:22:33:44:55";

  double grappleX = 0.0;
  double grappleY = 0.0;

  @override
  void initState() {
    super.initState();
    // Tidak auto connect lagi, user harus tekan tombol
  }

  Future<void> _connectBluetooth() async {
    setState(() => isConnecting = true);
    try {
      connection = await BluetoothConnection.toAddress(targetDeviceAddress);
      debugPrint('Connected to the device');
      setState(() => isConnected = true);
    } catch (e) {
      debugPrint('Cannot connect: $e');
      setState(() => isConnected = false);
    } finally {
      setState(() => isConnecting = false);
    }
  }

  Future<void> _disconnectBluetooth() async {
    await connection?.close();
    connection = null;
    setState(() => isConnected = false);
  }

  void _sendData() {
    if (connection != null && connection!.isConnected) {
      double speedX = leftJoystick.dx / joystickRadius;
      double speedY = -leftJoystick.dy / joystickRadius;

      String data =
          "L:${speedX.toStringAsFixed(2)},${speedY.toStringAsFixed(2)};"
          "R:${grappleX.toStringAsFixed(2)},${grappleY.toStringAsFixed(2)}\n";

      connection!.output.add(Uint8List.fromList(data.codeUnits));
      connection!.output.allSent;
    }
  }

  void _updateGrapple(String dir, bool isPressed) {
    setState(() {
      switch (dir) {
        case 'up':
          grappleY = isPressed ? 1.0 : 0.0;
          break;
        case 'down':
          grappleY = isPressed ? -1.0 : 0.0;
          break;
        case 'grab':
          grappleX = isPressed ? 1.0 : 0.0;
          break;
        case 'ungrab':
          grappleX = isPressed ? -1.0 : 0.0;
          break;
      }
      _sendData();
    });
  }

  @override
  Widget build(BuildContext context) {
    double speedX = leftJoystick.dx / joystickRadius;
    double speedY = -leftJoystick.dy / joystickRadius;
    double speed = sqrt(speedX * speedX + speedY * speedY);

    String direction = '';
    if (speedY > 0.3) direction += 'MAJU ';
    if (speedY < -0.3) direction += 'MUNDUR ';
    if (speedX < -0.3) direction += 'KIRI ';
    if (speedX > 0.3) direction += 'KANAN ';
    if (direction.isEmpty) direction = 'LURUS';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // LEFT JOYSTICK PANEL
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomJoystick(
                  joystickRadius: joystickRadius,
                  joystickPosition: leftJoystick,
                  onChanged: (offset) {
                    setState(() => leftJoystick = offset);
                    _sendData();
                  },
                ),
                const SizedBox(height: 15),
                _buildStatusPanel(speed, direction),
              ],
            ),

            // CENTER CONNECT BUTTON
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isConnecting
                      ? null
                      : () {
                          if (isConnected) {
                            _disconnectBluetooth();
                          } else {
                            _connectBluetooth();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.redAccent : Colors.green,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isConnecting
                        ? 'Connecting...'
                        : isConnected
                            ? 'Disconnect'
                            : 'Connect',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            // RIGHT GRAPPLE PANEL
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGrappleButton('up', Icons.keyboard_arrow_up),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGrappleButton('grab', Icons.pan_tool),
                    const SizedBox(width: 20),
                    _buildGrappleButton('ungrab', Icons.back_hand),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGrappleButton('down', Icons.keyboard_arrow_down),
                const SizedBox(height: 15),
                _buildGrappleStatus(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(double speed, String direction) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Text("Speed: ${speed.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 16, color: Colors.white)),
          const SizedBox(height: 5),
          Text("Arah: $direction",
              style: const TextStyle(fontSize: 16, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildGrappleStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        "Grapple\nX:${grappleX.toStringAsFixed(2)}, Y:${grappleY.toStringAsFixed(2)}",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildGrappleButton(String dir, IconData icon) {
    return GestureDetector(
      onTapDown: (_) => _updateGrapple(dir, true),
      onTapUp: (_) => _updateGrapple(dir, false),
      onTapCancel: () => _updateGrapple(dir, false),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.orangeAccent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(2, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

// CUSTOM JOYSTICK
class CustomJoystick extends StatelessWidget {
  final Offset joystickPosition;
  final double joystickRadius;
  final ValueChanged<Offset> onChanged;

  const CustomJoystick({
    super.key,
    required this.joystickPosition,
    required this.joystickRadius,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (details) => onChanged(Offset.zero),
      child: CustomPaint(
        size: Size(joystickRadius * 2, joystickRadius * 2),
        painter: JoystickPainter(joystickPosition, joystickRadius),
      ),
    );
  }

  void _update(Offset localPosition) {
    Offset center = Offset(joystickRadius, joystickRadius);
    Offset offset = localPosition - center;
    if (offset.distance > joystickRadius) {
      offset = Offset(
        offset.dx / offset.distance * joystickRadius,
        offset.dy / offset.distance * joystickRadius,
      );
    }
    onChanged(offset);
  }
}

class JoystickPainter extends CustomPainter {
  final Offset position;
  final double radius;

  JoystickPainter(this.position, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paintBg = Paint()
      ..shader = RadialGradient(
        colors: [Colors.grey.shade800, Colors.grey.shade600],
      ).createShader(
          Rect.fromCircle(center: Offset(radius, radius), radius: radius))
      ..style = PaintingStyle.fill;

    Paint paintHandle = Paint()
      ..shader = RadialGradient(
        colors: [Colors.blueAccent.shade200, Colors.blue.shade900],
      ).createShader(Rect.fromCircle(
          center: Offset(radius + position.dx, radius + position.dy),
          radius: radius / 2))
      ..style = PaintingStyle.fill;

    Offset center = Offset(radius, radius);
    canvas.drawCircle(center, radius, paintBg);
    canvas.drawCircle(center + position, radius / 2, paintHandle);
  }

  @override
  bool shouldRepaint(covariant JoystickPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

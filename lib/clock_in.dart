import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api.dart';
import 'design.dart';

/// Remembers a location refusal after the clock-in page has closed, so the
/// next denial can offer Settings instead of only leaving the screen.
bool _locationDeclinedOnce = false;

class ClockInPage extends StatefulWidget {
  final Api api;

  /// `in` or `out`. Both capture a front-camera selfie with location.
  final String action;
  const ClockInPage({super.key, required this.api, this.action = 'in'});
  @override
  State<ClockInPage> createState() => _ClockInPageState();
}

class _ClockInPageState extends State<ClockInPage> {
  CameraController? camera;
  XFile? selfie;
  Json? location;
  Object? error;
  bool busy = false, locating = true, success = false;
  Json? record;

  bool get out => widget.action == 'out';
  String get verb => out ? 'clock out' : 'clock in';

  @override
  void initState() {
    super.initState();
    begin();
  }

  Future<void> begin() async {
    final locationReady = askLocation();
    final cameraReady = openCamera();
    final gate = await locationReady;
    await cameraReady;
    if (!mounted) return;
    if (gate != _LocationGate.allowed) {
      final preview = camera;
      camera = null;
      await preview?.dispose();
      if (!mounted) return;
      if (gate == _LocationGate.settings) {
        await _locationSettings(context);
      }
      if (mounted) Navigator.pop(context);
      return;
    }
    await locate();
  }

  Future<_LocationGate> askLocation() async {
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return _LocationGate.settings;
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
    }
    final granted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (!granted) {
      final again =
          _locationDeclinedOnce ||
          permission == LocationPermission.deniedForever;
      _locationDeclinedOnce = true;
      return again ? _LocationGate.settings : _LocationGate.leave;
    }
    _locationDeclinedOnce = false;
    if (!servicesOn) return _LocationGate.settings;
    return _LocationGate.allowed;
  }

  Future<void> _locationSettings(BuildContext context) async {
    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined, color: primary, size: 32),
        title: const Text('Location needed'),
        content: const Text(
          'We need your location to clock in. Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (open == true) {
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (servicesOn) {
        await Geolocator.openAppSettings();
      } else {
        await Geolocator.openLocationSettings();
      }
    }
  }

  @override
  void dispose() {
    camera?.dispose();
    super.dispose();
  }

  Future<void> openCamera() async {
    setState(() => error = null);
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final item in cameras) {
        if (item.lensDirection == CameraLensDirection.front) {
          front = item;
          break;
        }
      }
      if (front == null) {
        throw ApiFailure('A front camera is needed to clock in.');
      }
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => camera = controller);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      final gps = await captureLocation();
      final checked = await widget.api.checkLocation(gps);
      if (!mounted) return;
      setState(() {
        location = {...checked, ...gps};
        locating = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          locating = false;
        });
      }
    }
  }

  Future<void> shoot() async {
    final controller = camera;
    if (controller == null || !controller.value.isInitialized || busy) return;
    setState(() => busy = true);
    try {
      final shot = await controller.takePicture();
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        camera = null;
        selfie = shot;
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  Future<void> retake() async {
    setState(() {
      selfie = null;
      success = false;
      record = null;
    });
    await openCamera();
  }

  bool get canConfirm {
    if (selfie == null || location == null || busy) return false;
    return location!['inside'] == true || widget.api.offline || widget.api.live;
  }

  Future<void> confirm() async {
    final shot = selfie;
    final gps = location;
    if (shot == null || gps == null || !canConfirm) return;
    setState(() => busy = true);
    try {
      final fresh = await captureLocation();
      final saved = await widget.api.mutate(
        out ? '/attendance/check-out' : '/attendance/check-in',
        {'photo': shot.path, ...fresh},
      );
      if (mounted) {
        setState(() {
          record = saved;
          success = true;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (success) return _done();
    if (selfie != null) return _confirm();
    return _camera();
  }

  Widget _camera() {
    final controller = camera;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (ready)
              Positioned.fill(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.14159),
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      out ? 'Clock out selfie' : 'Clock in selfie',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: Column(
                children: [
                  Text(
                    locating
                        ? 'Finding your location…'
                        : location != null
                        ? 'Location ready. Take your selfie.'
                        : 'Allow location, then take your selfie.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFD0D0)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: ready && !busy ? shoot : null,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
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

  Widget _confirm() {
    final inside = location?['inside'] == true;
    final office = location?['office'];
    final officeName = office is Map
        ? office['name']?.toString() ?? 'Office'
        : 'Office';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: ink),
                ),
                Expanded(
                  child: Text(
                    out ? 'Confirm clock out' : 'Confirm clock in',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.file(File(selfie!.path), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            if (locating)
              const Center(child: CircularProgressIndicator())
            else if (location != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location!['geofence'] == false
                            ? 'Location recorded'
                            : inside
                            ? 'Inside your office radius'
                            : 'Outside your office radius',
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      detail('Office', officeName),
                      if (location!['distance'] != null)
                        detail('Distance', '${location!['distance']} m'),
                      detail(
                        'GPS accuracy',
                        '${(location!['accuracy'] as num?)?.round() ?? '-'} m',
                      ),
                    ],
                  ),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 12),
              notice(error.toString()),
            ],
            const SizedBox(height: 16),
            ActionButton(
              out ? 'Confirm clock out' : 'Confirm clock in',
              busy: busy,
              icon: Icons.check,
              onPressed: canConfirm ? confirm : null,
            ),
            TextButton(
              onPressed: busy ? null : retake,
              child: const Text('Retake selfie'),
            ),
            if (location == null)
              TextButton(
                onPressed: busy ? null : locate,
                child: const Text('Retry location'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _done() => Scaffold(
    backgroundColor: const Color(0xFFF4F7F8),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.file(File(selfie!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            out ? 'Great work today.' : 'Have a great day.',
            style: const TextStyle(
              color: ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your $verb and selfie are saved.',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              children: [
                detail('Clock in', clockText(record!['clock_in'])),
                if (out) detail('Clock out', clockText(record!['clock_out'])),
                detail(
                  'Working hours',
                  durationText((record!['seconds'] as num?) ?? 0),
                ),
              ],
            ),
          ),
          ActionButton(
            'Back to my day',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ),
  );
}

enum _LocationGate { allowed, leave, settings }

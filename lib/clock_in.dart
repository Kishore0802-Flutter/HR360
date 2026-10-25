import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api.dart';
import 'design.dart';

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
  bool busy = false;
  bool locating = true;
  bool success = false;
  Json? record;

  // Permissions state
  bool checkingPermissions = true;
  bool cameraGranted = false;
  bool locationGranted = false;
  bool locationServicesOn = false;
  bool permanentlyDenied = false;
  String? permissionError;

  // Live clock timer for viewfinder overlay
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool get out => widget.action == 'out';
  String get verb => out ? 'clock out' : 'clock in';
  String get actionTitle => out ? 'Clock Out' : 'Clock In';

  bool get hasAllPermissions =>
      cameraGranted && locationGranted && locationServicesOn;

  @override
  void initState() {
    super.initState();
    _startTimer();
    checkAllPermissions();
  }

  void _startTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    camera?.dispose();
    super.dispose();
  }

  /// Initial permission check before opening camera/location.
  Future<void> checkAllPermissions() async {
    setState(() {
      checkingPermissions = true;
      permissionError = null;
    });

    bool camOk = false;
    bool locOk = false;
    bool locServices = false;
    bool blocked = false;

    // Check camera permission
    try {
      final camStatus = await Permission.camera.status;
      camOk = camStatus.isGranted;
      if (camStatus.isPermanentlyDenied) blocked = true;
    } catch (_) {
      camOk = true; // Fallback in unit tests/simulator
    }

    // Check location permission & service
    try {
      locServices = await Geolocator.isLocationServiceEnabled();
      final locStatus = await Geolocator.checkPermission();
      locOk = locStatus == LocationPermission.whileInUse ||
          locStatus == LocationPermission.always;
      if (locStatus == LocationPermission.deniedForever) blocked = true;
    } catch (_) {
      locOk = true;
      locServices = true;
    }

    if (!mounted) return;

    setState(() {
      cameraGranted = camOk;
      locationGranted = locOk;
      locationServicesOn = locServices;
      permanentlyDenied = blocked;
      checkingPermissions = false;
    });

    if (camOk && locOk && locServices) {
      await initializeCapture();
    }
  }

  /// Interactive permission request triggered from the gate view.
  Future<void> requestPermissions() async {
    setState(() {
      checkingPermissions = true;
      permissionError = null;
    });

    bool camOk = cameraGranted;
    bool locOk = locationGranted;
    bool locServices = locationServicesOn;
    bool blocked = false;

    // 1. Camera permission
    if (!camOk) {
      try {
        final res = await Permission.camera.request();
        camOk = res.isGranted;
        if (res.isPermanentlyDenied) blocked = true;
      } catch (_) {
        camOk = true;
      }
    }

    // 2. Location services check
    try {
      locServices = await Geolocator.isLocationServiceEnabled();
      if (!locServices) {
        await Geolocator.openLocationSettings();
        locServices = await Geolocator.isLocationServiceEnabled();
      }
    } catch (_) {
      locServices = true;
    }

    // 3. Location permission
    if (locServices && !locOk) {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        locOk = perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always;
        if (perm == LocationPermission.deniedForever) blocked = true;
      } catch (_) {
        locOk = true;
      }
    }

    if (!mounted) return;

    final allReady = camOk && locOk && locServices;
    setState(() {
      cameraGranted = camOk;
      locationGranted = locOk;
      locationServicesOn = locServices;
      permanentlyDenied = blocked;
      checkingPermissions = false;
      if (!allReady) {
        permissionError =
            'Both Camera and Location permissions are required to enter the clock-in screen.';
      }
    });

    if (allReady) {
      await initializeCapture();
    }
  }

  Future<void> initializeCapture() async {
    await Future.wait([
      openCamera(),
      locate(),
    ]);
  }

  /// Strictly front camera (selfie) only. No switching to back camera.
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
      // Fallback for simulators without front designation
      if (front == null) {
        for (final item in cameras) {
          if (item.lensDirection != CameraLensDirection.back) {
            front = item;
            break;
          }
        }
      }
      if (front == null && cameras.isNotEmpty) {
        front = cameras.first;
      }
      if (front == null) {
        throw ApiFailure('A front camera is required for selfie clock-in.');
      }
      final controller = CameraController(
        front,
        ResolutionPreset.high,
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
      final gps = await captureLocation(rules: widget.api.attendanceRules);
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

  /// Removes the captured selfie, deletes temporary file, and restarts front camera.
  Future<void> removeSelfie() async {
    final shot = selfie;
    if (shot != null) {
      try {
        final f = File(shot.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    setState(() {
      selfie = null;
      success = false;
      record = null;
      error = null;
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
      final fresh = await captureLocation(rules: widget.api.attendanceRules);
      final saved = await widget.api.mutate(
        out ? '/attendance/check-out' : '/attendance/check-in',
        {
          'photo': shot.path,
          'latitude': fresh['latitude'],
          'longitude': fresh['longitude'],
          'accuracy': fresh['accuracy'],
          'deviceTime': fresh['captured_at'] ??
              DateTime.now().toUtc().toIso8601String(),
        },
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
    if (!hasAllPermissions) {
      return _permissionGateView();
    }
    if (success) return _doneView();
    if (selfie != null) return _confirmView();
    return _cameraView();
  }

  // ---------------------------------------------------------------------------
  // 1. PERMISSION GATE VIEW (Blocking user until both permissions are active)
  // ---------------------------------------------------------------------------

  Widget _permissionGateView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF38BDF8),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$actionTitle Permissions',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'HR#360 strictly requires both Camera and Location permissions to verify identity and workplace attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _permissionTile(
                icon: Icons.camera_front_rounded,
                title: 'Front Camera (Selfie)',
                subtitle:
                    'Used only for taking your attendance selfie. Back camera is disabled.',
                granted: cameraGranted,
              ),
              const SizedBox(height: 12),
              _permissionTile(
                icon: Icons.location_on_rounded,
                title: 'Device Location (GPS)',
                subtitle:
                    'Resolves your current address and verifies you are at your office site.',
                granted: locationGranted && locationServicesOn,
              ),
              if (permissionError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22EF4444),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x66EF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFF87171),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          permissionError!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (checkingPermissions)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  ),
                )
              else ...[
                FilledButton.icon(
                  onPressed: requestPermissions,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text(
                    'Grant Required Permissions',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (permanentlyDenied || !locationServicesOn) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open App Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel & Return',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFF334155),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: granted
                  ? const Color(0x2210B981)
                  : const Color(0x2264748B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: granted
                  ? const Color(0xFF34D399)
                  : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: granted
                            ? const Color(0x2210B981)
                            : const Color(0x22F59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        granted ? 'Ready' : 'Required',
                        style: TextStyle(
                          color: granted
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. CAMERA VIEWFINDER (Front camera only, face guide, live GPS placename)
  // ---------------------------------------------------------------------------

  Widget _cameraView() {
    final controller = camera;
    final ready = controller != null && controller.value.isInitialized;
    final locationName = location?['location_name']?.toString() ?? '';
    final accuracy = (location?['accuracy'] as num?)?.round();
    final timeStr = _formatTime(_now);
    final dateStr = _formatDate(_now);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Mirrored Front Camera Viewport
            if (ready)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),

            // 2. Face Alignment Oval Guide
            if (ready)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FaceGuidePainter(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),

            // 3. Top Header Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Selfie & GPS Verification',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selfie lock chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_front_rounded,
                          color: Color(0xFF38BDF8),
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Front Camera',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Floating Live Time Badge
            Positioned(
              top: 74,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '$timeStr · $dateStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // 5. Bottom Live Location & Shutter Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live Location Card with reverse geocoding placename
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xDD0F172A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF34D399),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locating
                                    ? 'Acquiring location…'
                                    : locationName.isNotEmpty
                                    ? locationName
                                    : 'Location recorded',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                locating
                                    ? 'Fetching GPS & address…'
                                    : accuracy != null
                                    ? 'GPS Accuracy: ±${accuracy}m · Ready'
                                    : 'Coordinates captured',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (locating)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF38BDF8),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                            tooltip: 'Refresh GPS',
                            onPressed: locate,
                          ),
                      ],
                    ),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFB4AB),
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Shutter Button
                  GestureDetector(
                    onTap: ready && !busy ? shoot : null,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF38BDF8),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF0F172A),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap to capture selfie',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
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

  // ---------------------------------------------------------------------------
  // 3. CONFIRMATION VIEW (Preview, Remove Selfie, Location Card, Confirm)
  // ---------------------------------------------------------------------------

  Widget _confirmView() {
    final inside = location?['inside'] == true;
    final office = location?['office'];
    final officeName = office is Map
        ? office['name']?.toString() ?? 'Office'
        : 'Office';
    final locationName = location?['location_name']?.toString() ?? '';
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lon = (location?['longitude'] as num?)?.toDouble();
    final accuracy = (location?['accuracy'] as num?)?.round();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ink),
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        title: Text(
          out ? 'Confirm Clock Out' : 'Confirm Clock In',
          style: const TextStyle(
            color: ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Selfie photo card
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.file(
                      File(selfie!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF34D399),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Selfie Captured',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Remove Selfie Action Button (Prominent retake/delete action)
            OutlinedButton.icon(
              onPressed: busy ? null : removeSelfie,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text(
                'Remove Selfie / Retake',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE11D48),
                side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.5),
                backgroundColor: const Color(0xFFFFF1F2),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Reverse Geocoded Location & Verification Card
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C1B3A4B),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD7EFE4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF1B8F6E),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location Verified',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                locationName.isNotEmpty
                                    ? locationName
                                    : officeName,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (lat != null && lon != null)
                      detail(
                        'Coordinates',
                        '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                      ),
                    if (accuracy != null)
                      detail('GPS Accuracy', '±$accuracy meters'),
                    detail('Time of Capture', _formatTime(_now)),
                    detail(
                      'Office Radius',
                      inside ? 'Within radius' : 'Office Check-In',
                    ),
                  ],
                ),
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 12),
              notice(error.toString()),
            ],

            const SizedBox(height: 18),

            // Confirm Button
            ActionButton(
              out ? 'Confirm Clock Out' : 'Confirm Check In',
              busy: busy,
              icon: Icons.check_circle_rounded,
              onPressed: canConfirm ? confirm : null,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. DONE / SUCCESS VIEW
  // ---------------------------------------------------------------------------

  Widget _doneView() {
    final locationName = location?['location_name']?.toString() ?? '';
    final checkInTime = record?['clock_in'] != null
        ? clockText(record!['clock_in'])
        : _formatTime(_now);
    final checkOutTime = record?['clock_out'] != null
        ? clockText(record!['clock_out'])
        : _formatTime(_now);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7EFE4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1B8F6E), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B8F6E).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF1B8F6E),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              out ? 'Clocked Out Successfully' : 'Clocked In Successfully',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              out
                  ? 'Great work today! Your day summary has been recorded.'
                  : 'Have a productive day! Your attendance is verified.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (selfie != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 140,
                    height: 180,
                    child: Image.file(
                      File(selfie!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                children: [
                  detail(out ? 'Clock Out Time' : 'Clock In Time',
                      out ? checkOutTime : checkInTime),
                  if (locationName.isNotEmpty)
                    detail('Location', locationName),
                  detail('Date', _formatDate(_now)),
                  if (out && record?['seconds'] != null)
                    detail(
                      'Total Working Hours',
                      durationText((record!['seconds'] as num?) ?? 0),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ActionButton(
              'Back to Dashboard',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final second = d.second.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute:$second $ampm';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = days[d.weekday - 1];
    return '$weekday, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// Custom painter for face alignment guide oval
class _FaceGuidePainter extends CustomPainter {
  final Color color;
  _FaceGuidePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.72,
      height: size.height * 0.48,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}

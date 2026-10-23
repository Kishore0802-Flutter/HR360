import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'design.dart';
import 'nav.dart';

const _green = Color(0xFF1B8F6E);
const _navy = Color(0xFF1B3A4B);
const _field = Color(0xFFF4F7F9);

class SplashPage extends StatefulWidget {
  final VoidCallback onContinue;
  const SplashPage({super.key, required this.onContinue});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final CurvedAnimation arc = CurvedAnimation(
    parent: enter,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );
  late final CurvedAnimation logo = CurvedAnimation(
    parent: enter,
    curve: const Interval(0.15, 0.62, curve: Curves.easeOutBack),
  );
  late final CurvedAnimation title = CurvedAnimation(
    parent: enter,
    curve: const Interval(0.34, 0.74, curve: Curves.easeOut),
  );
  late final CurvedAnimation line = CurvedAnimation(
    parent: enter,
    curve: const Interval(0.48, 0.84, curve: Curves.easeOut),
  );
  late final CurvedAnimation art = CurvedAnimation(
    parent: enter,
    curve: const Interval(0.4, 0.95, curve: Curves.easeOut),
  );
  late final CurvedAnimation footer = CurvedAnimation(
    parent: enter,
    curve: const Interval(0.7, 1, curve: Curves.easeOut),
  );
  bool started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      enter.value = 1;
      return;
    }
    enter.forward();
    float.repeat(reverse: true);
  }

  @override
  void dispose() {
    arc.dispose();
    logo.dispose();
    title.dispose();
    line.dispose();
    art.dispose();
    footer.dispose();
    enter.dispose();
    float.dispose();
    super.dispose();
  }

  Widget _rise(CurvedAnimation motion, Widget child, {double dy = 16}) =>
      AnimatedBuilder(
        animation: motion,
        builder: (context, child) => Opacity(
          opacity: motion.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - motion.value) * dy),
            child: child,
          ),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B1446),
              Color(0xFF261A55),
              Color(0xFF1A2148),
              Color(0xFF12182C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: Listenable.merge([arc, logo]),
                builder: (context, child) => Opacity(
                  opacity: logo.value.clamp(0, 1),
                  child: Transform.scale(
                    scale: 0.72 + 0.28 * logo.value.clamp(0, 1),
                    child: _SplashMark(progress: arc.value),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _rise(
                title,
                const Text(
                  'HR#360',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _rise(
                line,
                const Text(
                  'A good day starts with you.',
                  style: TextStyle(color: Color(0xFFD5D3E8), fontSize: 15),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([art, float]),
                  builder: (context, child) => Opacity(
                    opacity: art.value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        (1 - art.value) * 20 + (float.value - 0.5) * 8,
                      ),
                      child: child,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 168,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66F08A72),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/dash_evening.png',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _rise(
                footer,
                const Text(
                  'PEOPLE FIRST. EVERY DAY.',
                  style: TextStyle(
                    color: Color(0xFFB7B4C9),
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                dy: 8,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SplashMark extends StatelessWidget {
  final double progress;
  const _SplashMark({required this.progress});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    height: 118,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _SplashArc(progress))),
        const Positioned(top: 52, child: _LogoCluster()),
      ],
    ),
  );
}

class _LogoCluster extends StatelessWidget {
  const _LogoCluster();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 74,
    height: 64,
    child: Stack(
      children: [
        Positioned(left: 2, top: 0, child: _LogoSquare(Color(0xFF8ED9C4), 32)),
        Positioned(right: 0, top: 6, child: _LogoSquare(Color(0xFFF08A72), 30)),
        Positioned(
          left: 20,
          bottom: 0,
          child: _LogoSquare(Color(0xFFA398E0), 30),
        ),
      ],
    ),
  );
}

class _LogoSquare extends StatelessWidget {
  final Color color;
  final double size;
  const _LogoSquare(this.color, this.size);
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

class _SplashArc extends CustomPainter {
  final double progress;
  const _SplashArc(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x55FFFFFF);
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height * 1.15);
    canvas.drawArc(rect, math.pi, math.pi * progress.clamp(0, 1), false, paint);
    const dots = [
      (0.08, Color(0xFF7DCAA4)),
      (0.28, Color(0xFF8ED9C4)),
      (0.72, Color(0xFFE7A090)),
      (0.92, Color(0xFFD98A78)),
    ];
    for (final dot in dots) {
      if (progress < dot.$1) continue;
      final angle = math.pi + dot.$1 * math.pi;
      final center = Offset(
        rect.center.dx + rect.width / 2 * math.cos(angle),
        rect.center.dy + rect.height / 2 * math.sin(angle),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 10, height: 10),
          const Radius.circular(3),
        ),
        Paint()..color = dot.$2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashArc oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Badge {
  final IconData icon;
  final Color color, wash;
  const _Badge(this.icon, this.color, this.wash);
}

class _Story {
  final String lead, accent, body, image;
  final Color background, color;
  final List<_Badge> icons;
  const _Story(
    this.lead,
    this.accent,
    this.body,
    this.image,
    this.background,
    this.color,
    this.icons,
  );
}

const _stories = [
  _Story(
    'Your Work Day,',
    'Simplified.',
    'Check in, track your time, and stay on top of your attendance with ease.',
    'assets/story_checkin.jpg',
    Color(0xFFF4F1FB),
    Color(0xFF6C4DFF),
    [
      _Badge(Icons.near_me_rounded, Color(0xFF6C4DFF), Color(0xFFEDE9FF)),
      _Badge(Icons.verified_rounded, Color(0xFF1B7F56), Color(0xFFE5F6EE)),
      _Badge(Icons.schedule_rounded, Color(0xFFE07A3D), Color(0xFFFFF1E6)),
      _Badge(Icons.fingerprint_rounded, Color(0xFF3D8BD4), Color(0xFFE7F3FC)),
    ],
  ),
  _Story(
    'Manage Requests',
    'On the Go.',
    'Apply for leave, raise requests and keep your manager in the loop.',
    'assets/story_requests.jpg',
    Color(0xFFFFF6F1),
    Color(0xFFF07A3A),
    [
      _Badge(
        Icons.calendar_month_rounded,
        Color(0xFF1B7F56),
        Color(0xFFE5F6EE),
      ),
      _Badge(Icons.beach_access_rounded, Color(0xFFF07A3A), Color(0xFFFFF1E8)),
      _Badge(Icons.edit_document, Color(0xFF6C4DFF), Color(0xFFEDE9FF)),
      _Badge(Icons.send_rounded, Color(0xFFE15B64), Color(0xFFFDECEC)),
    ],
  ),
  _Story(
    'Stay in',
    'Sync Always.',
    'Get updates, approvals and important notifications in one place.',
    'assets/story_sync.jpg',
    Color(0xFFF2F8F4),
    Color(0xFF1B7F56),
    [
      _Badge(
        Icons.notifications_active_rounded,
        Color(0xFFF07A3A),
        Color(0xFFFFF1E8),
      ),
      _Badge(Icons.task_alt_rounded, Color(0xFF1B7F56), Color(0xFFE5F6EE)),
      _Badge(Icons.forum_rounded, Color(0xFF6C4DFF), Color(0xFFEDE9FF)),
      _Badge(Icons.bolt_rounded, Color(0xFFE0A100), Color(0xFFFFF6E0)),
    ],
  ),
];

class StoryPage extends StatefulWidget {
  final VoidCallback onFinish;
  const StoryPage({super.key, required this.onFinish});
  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> with TickerProviderStateMixin {
  int index = 0;
  final pages = PageController();
  late final AnimationController float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      float.stop();
    } else if (!float.isAnimating) {
      float.repeat(reverse: true);
    }
  }

  Future<void> next() async {
    if (index >= _stories.length - 1) {
      widget.onFinish();
      return;
    }
    await pages.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    float.dispose();
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[index];
    final last = index == _stories.length - 1;
    return Scaffold(
      backgroundColor: story.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 12, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onFinish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF8B93A7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pages,
                itemCount: _stories.length,
                onPageChanged: (value) => setState(() => index = value),
                itemBuilder: (context, i) {
                  final page = _stories[i];
                  return ColoredBox(
                    color: page.background,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: '${page.lead}\n'),
                                    TextSpan(
                                      text: page.accent,
                                      style: TextStyle(color: page.color),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF1B2A4A),
                                  fontSize: 32,
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                page.body,
                                style: const TextStyle(
                                  color: Color(0xFF6E7C8A),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _StoryFrame(
                            story: page,
                            motion: float,
                            active: i == index,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Row(
                children: [
                  for (var i = 0; i < _stories.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == index
                            ? story.color
                            : story.color.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  const Spacer(),
                  if (last)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: story.color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: next,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    )
                  else
                    Material(
                      color: story.color,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: next,
                        child: const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
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
}

class _StoryFrame extends StatefulWidget {
  final _Story story;
  final Animation<double> motion;
  final bool active;
  const _StoryFrame({
    required this.story,
    required this.motion,
    required this.active,
  });
  @override
  State<_StoryFrame> createState() => _StoryFrameState();
}

class _StoryFrameState extends State<_StoryFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) fly.forward();
  }

  @override
  void didUpdateWidget(covariant _StoryFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) fly.forward(from: 0);
  }

  @override
  void dispose() {
    fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const spots = [
      Alignment(-0.78, -0.7),
      Alignment(0.8, -0.48),
      Alignment(0.72, 0.62),
      Alignment(-0.74, 0.58),
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([fly, widget.motion]),
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          child!,
          for (var i = 0; i < widget.story.icons.length; i++)
            _flying(widget.story.icons[i], spots[i], i),
        ],
      ),
      child: Container(
        width: 220,
        height: 276,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(widget.story.image, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _flying(_Badge badge, Alignment spot, int i) {
    final start = i * 0.1;
    final local = ((fly.value - start) / (1 - start)).clamp(0.0, 1.0);
    final travel = Curves.easeOutBack.transform(local);
    final place = Alignment.lerp(Alignment.center, spot, travel)!;
    final bob =
        math.sin((widget.motion.value + i * 0.25) * math.pi) * 7 * local;
    return Align(
      alignment: place,
      child: Opacity(
        opacity: local,
        child: Transform.translate(
          offset: Offset(0, bob),
          child: Transform.scale(
            scale: 0.45 + 0.55 * local,
            child: _FloatIcon(badge),
          ),
        ),
      ),
    );
  }
}

class _FloatIcon extends StatelessWidget {
  final _Badge badge;
  const _FloatIcon(this.badge);
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A1B2A4A),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: badge.wash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(badge.icon, color: badge.color, size: 20),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final Api api;
  const LoginPage({super.key, required this.api});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>(),
      id = TextEditingController(),
      password = TextEditingController();
  bool busy = false, show = false;
  String language = 'EN';
  Object? error;
  @override
  void dispose() {
    id.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.login(id.text.trim(), password.text);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration field(String hint, IconData icon, {Widget? suffix}) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: Color(0xFFE6EDF2)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB7C0CB), fontSize: 14),
      filled: true,
      fillColor: _field,
      prefixIcon: Icon(icon, color: const Color(0xFF8E99A8), size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _green, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 34,
                                      width: double.infinity,
                                      child: Image.asset(
                                        'assets/logo_mark.png',
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'From Joining to Growing',
                                      style: TextStyle(
                                        color: Color(0xFF8E99A8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                initialValue: language,
                                onSelected: (value) =>
                                    setState(() => language = value),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'EN',
                                    child: Text('English'),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFE4E9EF),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.language,
                                        size: 16,
                                        color: Color(0xFF5E6B7A),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        language,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _navy,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: Color(0xFF5E6B7A),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 6, right: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style: TextStyle(
                                          color: _navy,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Sign in to access your HRMS account and stay connected with your workplace.',
                                        style: TextStyle(
                                          color: Color(0xFF8E99A8),
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 142,
                                height: 156,
                                child: Image.asset(
                                  'assets/login_illustration.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: id,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            validator: (s) => s == null || s.trim().isEmpty
                                ? 'Enter your email'
                                : null,
                            decoration: field(
                              'ahmed@hr360.dev',
                              Icons.mail_outline,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: password,
                            obscureText: !show,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => submit(),
                            validator: (s) => s == null || s.isEmpty
                                ? 'Enter your password'
                                : null,
                            decoration: field(
                              'Enter your password',
                              Icons.lock_outline,
                              suffix: IconButton(
                                tooltip: show
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: () => setState(() => show = !show),
                                icon: Icon(
                                  show
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF8E99A8),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => openRoute(
                                      context,
                                      '/recovery',
                                      () => RecoveryPage(api: widget.api),
                                    ),
                              style: TextButton.styleFrom(
                                foregroundColor: _green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                error.toString(),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: primary.withValues(
                                alpha: 0.6,
                              ),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            onPressed: busy ? null : submit,
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Sign in',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(color: Color(0xFFE6EBEF)),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Color(0xFFB0B8C4),
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Color(0xFFE6EBEF)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              foregroundColor: _navy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              side: const BorderSide(color: Color(0xFFE3E8EE)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () => comingSoon(
                                    context,
                                    'Sign in with Biometrics',
                                    'Fingerprint and face sign-in will be available soon. Use your email and password for now.',
                                  ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  color: _green,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Sign in with Biometrics',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _LoginFooter(bottomInset: bottomInset),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  final double bottomInset;
  const _LoginFooter({required this.bottomInset});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 228 + bottomInset,
    width: double.infinity,
    child: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _FooterPainter())),
        Positioned(
          top: 8,
          left: 24,
          right: 24,
          child: Column(
            children: [
              const Icon(
                Icons.gpp_good_outlined,
                color: Color(0xFF1E6B56),
                size: 28,
              ),
              const SizedBox(height: 10),
              const Text(
                'Your data is secure',
                style: TextStyle(
                  color: Color(0xFF7C8794),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FooterPainter extends CustomPainter {
  const _FooterPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wave = Path()
      ..moveTo(0, h * 0.38)
      ..cubicTo(w * 0.12, h * 0.22, w * 0.22, h * 0.58, w * 0.4, h * 0.52)
      ..cubicTo(w * 0.55, h * 0.46, w * 0.46, h * 0.78, w * 0.28, h * 0.84)
      ..cubicTo(w * 0.12, h * 0.9, w * 0.08, h, 0, h)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xFFE4F6F0));
    final inner = Path()
      ..moveTo(0, h * 0.58)
      ..cubicTo(w * 0.08, h * 0.46, w * 0.18, h * 0.72, w * 0.3, h * 0.66)
      ..cubicTo(w * 0.38, h * 0.62, w * 0.22, h * 0.9, 0, h)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFF5FCFA));
    canvas.drawCircle(
      Offset(w * 1.02, h * 0.72),
      w * 0.22,
      Paint()..color = const Color(0xFFE98462),
    );
    canvas.drawCircle(
      Offset(w * 0.8, h * 0.98),
      w * 0.22,
      Paint()..color = const Color(0xFF7DCFC3),
    );
    canvas.drawCircle(
      Offset(w * 1.06, h * 1.02),
      w * 0.18,
      Paint()..color = const Color(0xFF3D7A68),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RecoveryPage extends StatefulWidget {
  final Api api;
  const RecoveryPage({super.key, required this.api});
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  bool reset = false, busy = false;
  String? result;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      final r = await widget.api.post(
        reset ? '/auth/reset-password' : '/auth/forgot-password',
        reset
            ? {'token': code.text.trim(), 'password': password.text}
            : {'email': email.text.trim()},
      );
      if (mounted) {
        setState(() => result = r['message']);
        if (reset) {
          message(context, r['message']);
          Navigator.pop(context);
        } else {
          setState(() => reset = true);
        }
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account recovery')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        heading(reset ? 'A fresh start.' : 'Let’s get you back in.'),
        if (result != null) notice(result!),
        if (!reset) ...[
          label('Work email'),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@company.com'),
          ),
        ] else ...[
          label('Reset code from email'),
          TextField(controller: code),
          label('New password'),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              helperText: 'At least 12 characters',
            ),
          ),
        ],
        const SizedBox(height: 24),
        ActionButton(
          reset ? 'Set new password' : 'Send reset code',
          busy: busy,
          onPressed: submit,
        ),
        TextButton(
          onPressed: () => setState(() => reset = !reset),
          child: Text(
            reset ? 'Request another code' : 'I already have a reset code',
          ),
        ),
      ],
    ),
  );
}

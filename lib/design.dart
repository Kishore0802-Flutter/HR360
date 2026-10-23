import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';

const ink = Color(0xFF25264D),
    primary = Color(0xFF1B7F56),
    mint = Color(0xFFBDECD9),
    coral = Color(0xFFF18370),
    paper = Color(0xFFF6F5F1),
    muted = Color(0xFF6B6D7D);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: primary,
    onPrimary: Colors.white,
    surface: paper,
  ),
  fontFamily: 'Manrope',
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'Manrope',
    bodyColor: ink,
    displayColor: ink,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    centerTitle: false,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFDFDFE8)),
    ),
    contentPadding: const EdgeInsets.all(16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);

class TileLoader extends StatefulWidget {
  final double size;
  const TileLoader({super.key, this.size = 64});
  @override
  State<TileLoader> createState() => _TileLoaderState();
}

class _TileLoaderState extends State<TileLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      c.stop();
    } else {
      c.repeat();
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: SizedBox(
      width: widget.size,
      height: widget.size + 12,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, child) => Stack(
          children: List.generate(4, (i) {
            final phase = (c.value - i * .09) % 1;
            final y = -math.sin(phase * math.pi * 2) * 5;
            return Positioned(
              left: (i % 2) * (widget.size / 2 + 2),
              top: (i ~/ 2) * (widget.size / 2 + 2) + 6,
              child: Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: widget.size / 2 - 3,
                  height: widget.size / 2 - 3,
                  decoration: BoxDecoration(
                    color: [mint, coral, const Color(0xFF8A8CB5), ink][i],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

class ShimmerBlock extends StatefulWidget {
  final double height;
  final double? width;
  const ShimmerBlock({super.key, this.height = 20, this.width});
  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      c.stop();
    } else {
      c.repeat();
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, child) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment(-3 + c.value * 6, 0),
          end: Alignment(-1 + c.value * 6, 0),
          colors: const [
            Color(0xFFE6E7E8),
            Color(0xFFF9F9FA),
            Color(0xFFE6E7E8),
          ],
        ),
      ),
    ),
  );
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: const [
      ShimmerBlock(width: 180),
      SizedBox(height: 22),
      ShimmerBlock(height: 245),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: ShimmerBlock(height: 125)),
          SizedBox(width: 12),
          Expanded(child: ShimmerBlock(height: 125)),
        ],
      ),
      SizedBox(height: 28),
      ShimmerBlock(width: 130),
      SizedBox(height: 16),
      ShimmerBlock(height: 180),
    ],
  );
}

class Reveal extends StatelessWidget {
  final Widget child;
  const Reveal({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 320,
    ),
    builder: (context, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
    ),
    child: child,
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  const ActionButton(
    this.text, {
    super.key,
    this.onPressed,
    this.busy = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const TileLoader(size: 24)
          else if (icon != null)
            Icon(icon, size: 20),
          if (busy || icon != null) const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final bg = status == 'Pending'
        ? const Color(0xFFFFF0DC)
        : status == 'Rejected'
        ? const Color(0xFFFCE4E0)
        : status == 'Cancelled'
        ? const Color(0xFFEAEAF0)
        : const Color(0xFFE5F4EC);
    final fg = status == 'Pending'
        ? const Color(0xFF8A581B)
        : status == 'Rejected'
        ? const Color(0xFFA63D35)
        : const Color(0xFF24684F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

Widget label(String t) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: Text(
    t,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
  ),
);
Widget heading(String t) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 18),
  child: Text(
    t,
    style: const TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
  ),
);
Widget detail(String a, String b) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(a, style: const TextStyle(fontSize: 12, color: muted)),
      ),
      const SizedBox(width: 14),
      Flexible(
        child: Text(
          b,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  ),
);
Widget notice(String t) => Panel(
  color: const Color(0xFFEBEAF2),
  padding: const EdgeInsets.all(14),
  child: Text(t, style: const TextStyle(fontSize: 12, height: 1.5)),
);
void message(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );

Future<void> comingSoon(BuildContext context, String title, String detail) =>
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.hourglass_top_rounded, color: primary, size: 32),
        title: Text(title),
        content: Text(detail),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('OK'),
          ),
        ],
      ),
    );
Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class FailureView extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const FailureView(this.error, this.retry, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          const SizedBox(height: 18),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ActionButton('Try again', onPressed: retry),
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  final String title, body;
  const EmptyView(this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 16),
    child: Column(
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 44),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class RequestTile extends StatelessWidget {
  final Json request;
  final VoidCallback onTap;
  final bool showEmployee;
  final bool approval;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const RequestTile(
    this.request, {
    super.key,
    required this.onTap,
    this.showEmployee = false,
    this.approval = false,
    this.onApprove,
    this.onReject,
  });
  @override
  Widget build(BuildContext context) {
    if (approval) return _approvalCard();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showEmployee
                            ? request['employee_name']
                            : '${request['kind']} request',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    StatusBadge(request['status']),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  request['type_name'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${shortDate(request['start'])}${request['end'] != request['start'] ? ' – ${shortDate(request['end'])}' : ''}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
                if (request['kind'] == 'Leave')
                  Text(
                    '${request['days']} working days',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _approvalCard() {
    final name = request['employee_name']?.toString() ?? '';
    final leave = request['kind'] == 'Leave';
    final sameDay = request['end'] == request['start'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PersonMark(name),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1B2A4A),
                        ),
                      ),
                    ),
                    Text(
                      _ago(request['updated'] ?? request['created']),
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 12,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFC5CAD3),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF8B93A7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${request['type_name']}${leave ? ' · ${request['days']} day${request['days'] == 1 ? '' : 's'}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 2),
                  child: Text(
                    '${shortDate(request['start'].toString())}${sameDay ? '' : ' – ${shortDate(request['end'].toString())}'}',
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (request['reason'] != null &&
                    request['reason'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request['reason'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF6E7C8A),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (onApprove != null || onReject != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFDECEC),
                            foregroundColor: const Color(0xFFE15B64),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE7F6EE),
                            foregroundColor: primary,
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onApprove,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text(
                            'Approve',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PersonMark extends StatelessWidget {
  final String name;
  const PersonMark(this.name, {super.key});
  @override
  Widget build(BuildContext context) {
    const tones = [
      (Color(0xFFE7F6EE), Color(0xFF1B7F56)),
      (Color(0xFFF3F0FF), Color(0xFF7C6BF2)),
      (Color(0xFFFFF6E8), Color(0xFFC48A00)),
      (Color(0xFFEAF2FF), Color(0xFF3D6FD6)),
    ];
    final tone = tones[name.hashCode.abs() % tones.length];
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final letters = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.substring(0, parts.first.length < 2 ? 1 : 2).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: tone.$1,
      child: Text(
        letters,
        style: TextStyle(
          color: tone.$2,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

String _ago(dynamic value) {
  final time = DateTime.tryParse(value?.toString() ?? '');
  if (time == null) return '';
  final elapsed = DateTime.now().toUtc().difference(time.toUtc());
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return shortDate(value.toString());
}

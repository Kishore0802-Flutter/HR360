import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppModule { hrms, tasks }

const tasksAccent = Color(0xFFBE5E38);

extension AppModuleStyle on AppModule {
  Color get accent => this == AppModule.hrms ? const Color(0xFF1B7F56) : tasksAccent;
  Color get soft => this == AppModule.hrms
      ? const Color(0xFFE7F6EE)
      : const Color(0xFFFDF6F0);
  Color get border => this == AppModule.hrms
      ? const Color(0xFFC7EBD7)
      : const Color(0xFFE8D3C5);
  List<Color> get gradient => this == AppModule.hrms
      ? const [Color(0xFF0C3831), Color(0xFF1B7F56)]
      : const [Color(0xFFBE5E38), Color(0xFFD97706)];
  String get title => this == AppModule.hrms ? 'HRMS' : 'Tasks';
  String get subtitle =>
      this == AppModule.hrms ? 'People & Attendance' : 'Work & Issues';
  IconData get icon =>
      this == AppModule.hrms ? Icons.groups_rounded : Icons.checklist_rounded;
}

/// Modern segmented module dock: clean rounded container with elevated active card
class ModuleSwitch extends StatelessWidget {
  final AppModule module;
  final ValueChanged<AppModule> onChanged;
  const ModuleSwitch({
    super.key,
    required this.module,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = module == AppModule.tasks;
    final activeBg = tasks ? const Color(0xFFBE5E38) : const Color(0xFF0C3831);
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: tasks ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final item in AppModule.values)
                Expanded(
                  child: _Half(
                    module: item,
                    selected: item == module,
                    onTap: () {
                      if (item != module) onChanged(item);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  final AppModule module;
  final bool selected;
  final VoidCallback onTap;
  const _Half({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${module.title} workspace',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  module.icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF334155),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      module.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? const Color(0xD9FFFFFF)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swaps workspaces with a circular colour reveal that grows from the dock.
class ModuleReveal extends StatelessWidget {
  final AppModule module;
  final Widget child;
  const ModuleReveal({super.key, required this.module, required this.child});

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(module);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: Curves.easeInOutCubic,
      transitionBuilder: (widget, animation) {
        if (widget.key != current) return widget;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: _CircleReveal(
                  progress: animation.value,
                  origin: module == AppModule.tasks
                      ? const Alignment(0.55, -0.78)
                      : const Alignment(-0.55, -0.78),
                ),
                child: child,
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: (1 - animation.value).clamp(0.0, 1.0) * 0.35,
                  child: ClipPath(
                    clipper: _CircleReveal(
                      progress: animation.value,
                      origin: module == AppModule.tasks
                          ? const Alignment(0.55, -0.78)
                          : const Alignment(-0.55, -0.78),
                    ),
                    child: ColoredBox(color: module.accent),
                  ),
                ),
              ),
            ],
          ),
          child: widget,
        );
      },
      child: KeyedSubtree(key: current, child: child),
    );
  }
}

class _CircleReveal extends CustomClipper<Path> {
  final double progress;
  final Alignment origin;
  _CircleReveal({required this.progress, required this.origin});

  @override
  Path getClip(Size size) {
    final center = origin.alongSize(size);
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - center).distance).reduce(math.max);
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: far * progress));
  }

  @override
  bool shouldReclip(_CircleReveal old) =>
      old.progress != progress || old.origin != origin;
}

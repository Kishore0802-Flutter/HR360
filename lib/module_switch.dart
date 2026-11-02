import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AppModule { hrms, tasks }

const tasksAccent = Color(0xFFC2570C);

extension AppModuleStyle on AppModule {
  Color get accent => this == AppModule.hrms ? const Color(0xFF0C3831) : tasksAccent;
  Color get soft => this == AppModule.hrms
      ? const Color(0xFFE2E8F0)
      : const Color(0xFFFCE9DA);
  List<Color> get gradient => this == AppModule.hrms
      ? const [Color(0xFF0C3831), Color(0xFF0F473E)]
      : const [Color(0xFFC2570C), Color(0xFFEB8A3C)];
  String get title => this == AppModule.hrms ? 'HRMS' : 'Tasks';
  String get subtitle =>
      this == AppModule.hrms ? 'People & Attendance' : 'Work & Issues';
  IconData get icon =>
      this == AppModule.hrms ? Icons.groups_rounded : Icons.check_box_outlined;
}

/// Full-width workspace dock: two halves with a sliding gradient thumb.
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
    return Container(
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2A4A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: tasks ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: module.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: module.accent.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
    final fg = selected ? Colors.white : const Color(0xFF0F172A);
    return Semantics(
      button: true,
      selected: selected,
      label: '${module.title} workspace',
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                module.icon,
                size: 21,
                color: selected ? Colors.white : const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(color: fg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        module.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
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

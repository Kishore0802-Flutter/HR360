import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design.dart';

enum AppModule { hrms, tasks }

const tasksAccent = Color(0xFFC2570C);

extension AppModuleStyle on AppModule {
  Color get accent => this == AppModule.hrms ? primary : tasksAccent;
  Color get soft => this == AppModule.hrms
      ? const Color(0xFFDFF6EA)
      : const Color(0xFFFCE9DA);
  List<Color> get gradient => this == AppModule.hrms
      ? const [Color(0xFF1B7F56), Color(0xFF34A97C)]
      : const [Color(0xFFC2570C), Color(0xFFEB8A3C)];
  String get title => this == AppModule.hrms ? 'HRMS' : 'Tasks';
  String get subtitle =>
      this == AppModule.hrms ? 'People & attendance' : 'Work & issues';
  IconData get icon =>
      this == AppModule.hrms ? Icons.groups_2_outlined : Icons.task_alt_rounded;
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
      height: 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1B2A4A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            alignment: tasks ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: LinearGradient(
                    colors: module.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: module.accent.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
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
    final fg = selected ? Colors.white : ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${module.title} workspace',
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : module.soft,
                ),
                child: Icon(
                  module.icon,
                  size: 18,
                  color: selected ? Colors.white : module.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(color: fg, fontFamily: 'Manrope'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        module.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : muted,
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

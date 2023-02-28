import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  runApp(const ProviderScope(
    child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: MediaQueryData(), child: FUI())),
  ));
}

class FUI extends HookConsumerWidget {
  const FUI({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(zoomProvider);
    return Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: 7 * zoom * zoom, sigmaY: 5 * zoom * zoom),
            child: Image.asset(
              'assets/bg.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
        const Align(alignment: Alignment.center, child: Planet()),
        const Align(
          alignment: Alignment.topRight,
          child: Blurp(),
        )
      ],
    );
  }
}

final isPlayingProvider = StateProvider((ref) => false);

final zoomProvider = StateProvider((ref) => 0.0);

class Blurp extends HookConsumerWidget {
  const Blurp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Hello World'),
                  const SizedBox(width: 8),
                  GestureDetector(
                      onTap: () => ref.read(isPlayingProvider.notifier).state =
                          !isPlaying,
                      child: Text(isPlaying ? 'Pause' : 'Play')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Planet extends HookConsumerWidget {
  const Planet({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(shaderProvider('assets/planet.frag'));
    final shader = useShader(program.asData?.value);
    final animationController = useAnimationController(
        lowerBound: 0,
        upperBound: pi * 2,
        duration: const Duration(seconds: 15));
    ref.listen(isPlayingProvider, (_, state) {
      if (state) {
        animationController.repeat();
      } else {
        animationController.stop();
      }
    });
    useEffect(() {
      if (ref.read(isPlayingProvider)) animationController.repeat();
      return null;
    }, const []);
    useAnimation(animationController);
    final mousePositionScreen = useState(Offset.zero);
    final isDragging = useState(false);
    final zoom = ref.watch(zoomProvider);
    return RepaintBoundary(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutExpo,
        scale: pow(zoom, 2) * 2 + 0.2,
        child: GestureDetector(
          onHorizontalDragStart: (details) => isDragging.value = true,
          onHorizontalDragEnd: (details) => isDragging.value = false,
          onHorizontalDragCancel: () => isDragging.value = false,
          onHorizontalDragUpdate: (event) {
            mousePositionScreen.value = event.localPosition;
          },
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final scrolled = zoom - event.scrollDelta.dy / 4000;
                ref.read(zoomProvider.notifier).state =
                    (scrolled.clamp(0.01, 1));
              }
            },
            child: MouseRegion(
              // cursor: SystemMouseCursors.none,
              onHover: (event) {
                mousePositionScreen.value = event.localPosition;
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ConsumerPainter(
                  size: const Size.square(double.infinity),
                  paint: ((canvas, size, ref) {
                    final dimension = size.shortestSide;
                    shader?.setFloat(0, dimension);
                    shader?.setFloat(
                        1,
                        size.longestSide == size.width
                            ? (size.width - size.height) / 2
                            : 0);
                    shader?.setFloat(
                        2,
                        size.longestSide == size.height
                            ? (size.height - size.width) / 2
                            : 0);
                    shader?.setFloat(3, animationController.value);
                    shader?.setFloat(4, 1 - zoom);
                    final planet = Paint()
                      ..color = const Color.fromRGBO(255, 0, 255, 1.0)
                      ..shader = shader
                      ..style = PaintingStyle.fill;
                    canvas.drawCircle(
                        size.center(Offset.zero), dimension / 2, planet);

                    final gizmo = Paint()
                      ..color = isDragging.value
                          ? Color.fromARGB(211, 182, 54, 54)
                          : Color.fromARGB(221, 30, 116, 185)
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2;
                    final gizmoHighlight = Paint()
                      ..color = isDragging.value
                          ? Color.fromARGB(176, 233, 170, 170)
                          : Color.fromARGB(183, 156, 204, 243)
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 1.1;

                    canvas.translate(size.width / 2, size.height / 2);

                    final mouse = mousePositionScreen.value
                        .translate(-size.width / 2, -size.height / 2);
                    final distance =
                        mouse.scale(1 / dimension, 1 / dimension).distance;

                    for (int i = 0; i < 6; i++) {
                      canvas.save();
                      final rotation = Matrix4.identity()
                        ..setEntry(3, 2,
                            (0.0001 + zoom * 0.0007) * (i / 3.0))
                        ..rotateZ(mouse.direction + pi)
                        ..rotateY(pow(distance, sqrt2) * pi)
                        ..translate(0.0, 0.0, -dimension / 2);
                      canvas.transform(rotation.storage);
                      canvas.drawCircle(
                          Offset.zero, dimension / 16, gizmo);
                      canvas.drawCircle(Offset.zero,
                          dimension / 16, gizmoHighlight);
                      canvas.restore();
                    }
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension MapOptional<S> on S? {
  T? map<T>(T Function(S) mapper) => this == null ? null : mapper(this as S);
}

final shaderProvider = FutureProvider.family(
    (ref, String asset) => FragmentProgram.fromAsset(asset));

FragmentShader? useShader(FragmentProgram? program) => useMemoized(
    program != null ? program.fragmentShader : () => null, [program]);

class DelegatePainter extends CustomPainter {
  final Function(Canvas canvas, Size size) delegate;
  const DelegatePainter(this.delegate);

  @override
  void paint(Canvas canvas, Size size) {
    delegate(canvas, size);
  }

  @override
  bool shouldRepaint(DelegatePainter oldDelegate) => true;
}

class ConsumerPainter extends ConsumerWidget {
  final Function(Canvas canvas, Size size, WidgetRef ref)? paint;
  final Function(Canvas canvas, Size size, WidgetRef ref)? foregroundPaint;
  final Size size;
  final bool isComplex;
  final bool willChange;
  final Widget? child;
  const ConsumerPainter(
      {super.key,
      this.paint,
      this.foregroundPaint,
      this.size = Size.zero,
      this.isComplex = false,
      this.willChange = false,
      this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomPaint(
      painter: paint != null
          ? DelegatePainter((canvas, size) => paint!(canvas, size, ref))
          : null,
      foregroundPainter: paint != null
          ? DelegatePainter((canvas, size) => paint!(canvas, size, ref))
          : null,
      size: size,
      isComplex: isComplex,
      willChange: willChange,
      child: child,
    );
  }
}

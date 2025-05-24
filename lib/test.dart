import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class PoolGameScreen extends StatefulWidget {
  const PoolGameScreen({super.key});

  @override
  PoolGameScreenState createState() => PoolGameScreenState();
}

class PoolGameScreenState extends State<PoolGameScreen> {
  List<Ball> balls = []; // Stores all balls on the table
  Ball? cueBall; // Special reference to the white cue ball
  Offset? aimStart; // Where aiming starts (touch position)
  Timer? _timer; // For game animation updates
  bool isPlayerTurn = true; // Tracks whose turn it is
  int playerScore = 0; // Player's score
  int opponentScore = 0; // Computer's score
  double tableWidth = 0; // Table dimensions
  double tableHeight = 0;
  final double tableBorderWidth = 30.0; // Wooden border size
  final double pocketRadius = 25.0; // Pocket size
  List<Offset> pockets = []; // Positions of all 6 pockets
  List<Offset> trajectoryPoints = []; // For showing shot prediction
  bool gameInitialized = false; // Tracks if game is ready
  int maxTrajectoryPoints = 20;
  bool showTrackingLine = false;
  bool hasMoved = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  void _initializeGame() {
    final size = MediaQuery.of(context).size;
    tableWidth = size.width - tableBorderWidth * 2;
    tableHeight = size.height - tableBorderWidth * 2;

    pockets = [
      Offset(tableBorderWidth, tableBorderWidth),//top 1st
      Offset(size.width / 14, tableBorderWidth*11),//top 2nd
      Offset(size.width - tableBorderWidth, tableBorderWidth),//3rd top
      Offset(tableBorderWidth, size.height - tableBorderWidth*07),//bottom 1st
      Offset(size.width*0.92, size.height - tableBorderWidth*16),//bottom 2nd
      Offset(size.width*0.99 - tableBorderWidth, size.height - tableBorderWidth*07),//bottom 3rd
    ];

    _initializeBalls();
    setState(() {
      gameInitialized = true;
    });
  }

  void _initializeBalls() {
    balls.clear();

    // Initialize cue ball
    cueBall = Ball(
      position: Offset(
        tableBorderWidth * 4 + 50,
        tableHeight / 2 + tableBorderWidth,
      ),
      color: Colors.white,
      isCue: true,
      number: 0,
    );
    balls.add(cueBall!);

    // Generate and shuffle IDs from 1 to 15
    List<int> ids = List.generate(15, (index) => index + 1);
    ids.shuffle();

    // Triangle setup
    double startX = tableWidth / 3.5 + tableBorderWidth;
    double startY = 50 + tableBorderWidth;
    double radius = 15;
    int cols = 5;
    int idIndex = 0;

    for (int col = 0; col < cols; col++) {
      for (int row = 0; row <= col; row++) {
        if (idIndex >= ids.length) break; // Stop if all IDs are used

        balls.add(
          Ball(
            position: Offset(
              startX + (col * (radius * 2)) - (row * radius),
              startY + row * (radius * 1.8),
            ),
            color: _getBallColor(ids[idIndex]),
            number: ids[idIndex],
          ),
        );
        idIndex++;
      }
    }
  }

  Color _getBallColor(int number) {
    if (number == 8) return Colors.black;
    if (number > 8) number -= 8;
    return Colors.primaries[number % Colors.primaries.length];
  }

  void _calculateTrajectory(Offset end) {
    if (cueBall == null) return;

    setState(() {
      trajectoryPoints.clear();

      // Create a simulated cue ball for prediction
      Ball simulatedCueBall = Ball(
        position: cueBall!.position,
        velocity: Offset.zero,
        color: Colors.transparent,
        isCue: true,
        number: 0,
      );

      final direction = (simulatedCueBall.position - end);
      final force = direction.normalized * min(direction.distance / 100, 1.0) * 5;
      simulatedCueBall.velocity = force;

      // Simulate movement
      for (int i = 0; i < maxTrajectoryPoints; i++) {
        trajectoryPoints.add(simulatedCueBall.position);

        // Update position
        simulatedCueBall.position += simulatedCueBall.velocity;
        simulatedCueBall.velocity *= 0.92; // Friction

        // Handle wall collisions
        if (simulatedCueBall.position.dx < tableBorderWidth + simulatedCueBall.radius) {
          simulatedCueBall.position = Offset(
            tableBorderWidth + simulatedCueBall.radius,
            simulatedCueBall.position.dy,
          );
          simulatedCueBall.velocity = Offset(
            -simulatedCueBall.velocity.dx,
            simulatedCueBall.velocity.dy,
          );
        }
        // Similar checks for other walls...

        // Check for ball collisions
        for (var ball in balls) {
          if (!ball.isCue &&
              (simulatedCueBall.position - ball.position).distance <
                  simulatedCueBall.radius + ball.radius) {
            return; // Stop trajectory at first collision
          }
        }
      }
    });
  }

  void _startMovement() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        bool allStopped = true;

        for (var ball in balls) {
          if (ball.velocity != Offset.zero) {
            allStopped = false;
            ball.position += ball.velocity;
            ball.velocity *= 0.92; // Increased friction

            if (ball.velocity.distance < 0.05) {
              ball.velocity = Offset.zero;
            }
          }
        }

        _handleCollisions();
        _checkPockets();

        if (allStopped && balls.every((b) => b.velocity == Offset.zero)) {
          timer.cancel();
          isPlayerTurn = !isPlayerTurn;
          cueBall ??= balls.firstWhereOrNull((b) => b.isCue);
        }
      });
    });
  }

  void _handleCollisions() {
    // Wall collisions
    for (var ball in balls) {
      if (ball.position.dx < tableBorderWidth + ball.radius) {
        ball.position = Offset(
          tableBorderWidth + ball.radius,
          ball.position.dy,
        );
        ball.velocity = Offset(-ball.velocity.dx, ball.velocity.dy);
      }
      if (ball.position.dx > tableWidth + tableBorderWidth - ball.radius) {
        ball.position = Offset(
          tableWidth + tableBorderWidth - ball.radius,
          ball.position.dy,
        );
        ball.velocity = Offset(-ball.velocity.dx, ball.velocity.dy);
      }
      if (ball.position.dy < tableBorderWidth + ball.radius) {
        ball.position = Offset(
          ball.position.dx,
          tableBorderWidth + ball.radius,
        );
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy);
      }
      if (ball.position.dy > tableHeight + tableBorderWidth - ball.radius) {
        ball.position = Offset(
          ball.position.dx,
          tableHeight + tableBorderWidth - ball.radius,
        );
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy);
      }
    }

    // Ball collisions
    for (int i = 0; i < balls.length; i++) {
      for (int j = i + 1; j < balls.length; j++) {
        Ball a = balls[i];
        Ball b = balls[j];

        final dx = b.position.dx - a.position.dx;
        final dy = b.position.dy - a.position.dy;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = a.radius + b.radius;

        if (dist < minDist) {
          final nx = dx / dist;
          final ny = dy / dist;
          final vx = b.velocity.dx - a.velocity.dx;
          final vy = b.velocity.dy - a.velocity.dy;
          final relativeVelocity = (vx * nx + vy * ny);

          if (relativeVelocity > 0) continue;

          final impulse = 0.7 * relativeVelocity / 2.0; // Reduced impulse
          a.velocity = Offset(
            a.velocity.dx - impulse * nx,
            a.velocity.dy - impulse * ny,
          );
          b.velocity = Offset(
            b.velocity.dx + impulse * nx,
            b.velocity.dy + impulse * ny,
          );

          final overlap = (minDist - dist) / 2.0;
          a.position = Offset(
            a.position.dx - overlap * nx,
            a.position.dy - overlap * ny,
          );
          b.position = Offset(
            b.position.dx + overlap * nx,
            b.position.dy + overlap * ny,
          );
        }
      }
    }
  }

  void _checkPockets() {
    List<Ball> toRemove = [];

    for (var ball in balls) {
      print('yaha hai:$ball');
      for (var pocket in pockets) {
        if ((ball.position - pocket).distance < pocketRadius) {
          toRemove.add(ball);

          if (ball.isCue) {
            _resetCueBall();
          } else {
            if (isPlayerTurn) {
              playerScore += ball.number == 8 ? 10 : 1;
            } else {
              opponentScore += ball.number == 8 ? 10 : 1;
            }
          }
          break;
        }
      }
    }

    if (toRemove.isNotEmpty) {
      setState(() {
        balls.removeWhere((ball) => toRemove.contains(ball) && !ball.isCue);
      });
    }
  }

  void _resetCueBall() {
    if (cueBall == null) {
      cueBall = Ball(
        position: Offset(
          tableBorderWidth + 100,
          tableHeight / 2 + tableBorderWidth,
        ),
        color: Colors.white,
        isCue: true,
        number: 0,
      );
      balls.add(cueBall!);
    } else {
      cueBall!.position = Offset(
        tableBorderWidth + 100,
        tableHeight / 2 + tableBorderWidth,
      );
      cueBall!.velocity = Offset.zero;
    }
  }

  void _hitCueBall(Offset end) {
    if (!isPlayerTurn || cueBall == null) return;

    final direction = (cueBall!.position - end);
    final distance = direction.distance;
    final power = min(distance / 100, 1.0);
    final force = direction.normalized * power * 5; // Reduced force

    cueBall!.velocity = force;
    _startMovement();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!gameInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (cueBall == null) {
      return const Scaffold(
        body: Center(child: Text("Game error: No cue ball")),
      );
    }

    bool canShoot =
        isPlayerTurn && balls.every((b) => b.velocity == Offset.zero);

    return Scaffold(
      body: Center(
        child: Container(
          height: 650,
          decoration: BoxDecoration(color: Colors.brown[800]),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.brown[400],
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(tableBorderWidth *0.5),
            child: Stack(
              children: [
                // Table surface
                Positioned(
                  left: tableBorderWidth,
                  top: tableBorderWidth,
                  right: tableBorderWidth,
                  bottom: tableBorderWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                // Pockets
                ...pockets.map(
                  (pocket) => Positioned(
                    left: pocket.dx - pocketRadius,
                    top: pocket.dy - pocketRadius,
                    child: Container(
                      width: pocketRadius * 1,
                      height: pocketRadius * 1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Balls
                ...balls.map(
                  (ball) => Positioned(
                    left: ball.position.dx - ball.radius,
                    top: ball.position.dy - ball.radius,
                    child: Container(
                      width: ball.radius * 2,
                      height: ball.radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ball.color,
                        border: Border.all(color: Colors.black),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 5,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child:
                          ball.number > 0
                              ? Center(
                                child: Text(
                                  ball.number.toString(),
                                  style: TextStyle(
                                    color:
                                        ball.color.computeLuminance() > 0.5
                                            ? Colors.black
                                            : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              : null,
                    ),
                  ),
                ),
                // Trajectory prediction line
                // In your Stack widget, make sure this is always visible when aiming:
                if (aimStart != null && canShoot && trajectoryPoints.isNotEmpty)
                  CustomPaint(
                    painter: TrajectoryPainter(trajectoryPoints),
                    size: Size.infinite,
                  ),
                // Aiming line
                if (aimStart != null && canShoot)
                  CustomPaint(
                    painter: CueLinePainter(
                      start: cueBall!.position,
                      end: aimStart!,
                      power: (cueBall!.position - aimStart!).distance,
                    ),
                    size: Size.infinite,
                  ),
                // Score display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Player: $playerScore',
                      style: TextStyle(
                        color: isPlayerTurn ? Colors.yellow : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Opponent: $opponentScore',
                      style: TextStyle(
                        color: !isPlayerTurn ? Colors.yellow : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Controls
                // Replace the existing GestureDetector in your build method with this:
                if (canShoot && cueBall != null)
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: (details) {
                        // Check if touch is near cue ball
                        if ((details.localPosition - cueBall!.position).distance <= cueBall!.radius * 2) {
                          setState(() {
                            aimStart = details.localPosition;
                            _calculateTrajectory(details.localPosition);
                          });
                        }
                      },
                      onPanUpdate: (details) {
                        if (aimStart != null) {
                          setState(() {
                            aimStart = details.localPosition;
                            _calculateTrajectory(details.localPosition);
                          });
                        }
                      },
                      onPanEnd: (_) {
                        if (aimStart != null) {
                          _hitCueBall(aimStart!);
                          setState(() {
                            aimStart = null;
                            trajectoryPoints.clear();
                          });
                        }
                      },
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Ball {
  Offset position;
  Offset velocity;
  final Color color;
  final bool isCue;
  final double radius;
  final int number;

  Ball({
    required this.position,
    this.velocity = Offset.zero,
    required this.color,
    this.isCue = false,
    this.radius = 15,
    required this.number,
  });
}

class CueLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double power;

  CueLinePainter({required this.start, required this.end, required this.power});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final powerPaint =
        Paint()
          ..color = Colors.red.withValues(alpha: 0.5)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;

    final powerLength = min(power, 100);
    final powerEnd = start + (end - start).normalized * powerLength.toDouble();
    canvas.drawLine(start, powerEnd, powerPaint);
    canvas.drawLine(start, end, linePaint);
  }

  @override
  bool shouldRepaint(CueLinePainter oldDelegate) => true;
}

class TrajectoryPainter extends CustomPainter {
  final List<Offset> points;

  TrajectoryPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (i % 2 == 0) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    if (points.length > 1) {
      final last = points.last;
      final secondLast = points[points.length - 2];
      final angle = atan2(last.dy - secondLast.dy, last.dx - secondLast.dx);

      canvas.save();
      canvas.translate(last.dx, last.dy);
      canvas.rotate(angle);

      final arrowPaint =
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2
            ..style = PaintingStyle.fill;

      final path =
          Path()
            ..moveTo(0, 0)
            ..lineTo(-10, -5)
            ..lineTo(-10, 5)
            ..close();

      canvas.drawPath(path, arrowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) =>
      oldDelegate.points != points;
}

extension OffsetExtension on Offset {
  Offset get normalized => distance > 0 ? this / distance : Offset.zero;
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

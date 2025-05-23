import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class PoolGameScreen extends StatefulWidget {
  const PoolGameScreen({super.key});

  @override
  PoolGameScreenState createState() => PoolGameScreenState();
}

class PoolGameScreenState extends State<PoolGameScreen> {
  List<Ball> balls = [];
  Offset? aimStart;
  Timer? _timer;
  bool isPlayerTurn = true;
  int playerScore = 0;
  int opponentScore = 0;
  double tableWidth = 0;
  double tableHeight = 0;
  final double tableBorderWidth = 30.0;
  final double pocketRadius = 25.0;
  List<Offset> pockets = [];
  List<Offset> trajectoryPoints = [];
  int maxTrajectoryPoints = 20;

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

    // Initialize pocket positions
    pockets = [
      Offset(tableBorderWidth, tableBorderWidth),
      Offset(size.width / 2, tableBorderWidth),
      Offset(size.width - tableBorderWidth, tableBorderWidth),
      Offset(tableBorderWidth, size.height - tableBorderWidth),
      Offset(size.width / 2, size.height - tableBorderWidth),
      Offset(size.width - tableBorderWidth, size.height - tableBorderWidth),
    ];

    _initializeBalls();
  }

  void _initializeBalls() {
    balls.clear();

    // Cue ball
    balls.add(
      Ball(
        position: Offset(
          tableBorderWidth + 100,
          tableHeight / 2 + tableBorderWidth,
        ),
        color: Colors.white,
        isCue: true,
        number: 0,
      ),
    );

    // 15 balls arranged in triangle
    double startX = tableWidth - 150 + tableBorderWidth;
    double startY = tableHeight / 2 + tableBorderWidth;
    double radius = 15;
    int rows = 5;
    int id = 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col <= row; col++) {
        balls.add(
          Ball(
            position: Offset(
              startX + row * (radius * 1.8),
              startY + col * (radius * 2) - row * radius,
            ),
            color: _getBallColor(id),
            number: id,
          ),
        );
        id++;
        if (id > 15) break;
      }
    }
  }

  Color _getBallColor(int number) {
    if (number == 8) return Colors.black;
    if (number > 8) number -= 8;

    return Colors.primaries[number % Colors.primaries.length];
  }

  void _calculateTrajectory(Offset end) {
    trajectoryPoints.clear();

    // Make a copy of the current game state for simulation
    List<Ball> simulatedBalls =
        balls
            .map(
              (ball) => Ball(
                position: ball.position,
                velocity: ball.velocity,
                color: ball.color,
                isCue: ball.isCue,
                number: ball.number,
                radius: ball.radius,
              ),
            )
            .toList();

    // Find the cue ball in our simulation
    Ball cueBall = simulatedBalls.firstWhere((b) => b.isCue);

    // Apply the same force we would in the real game
    final direction = (cueBall.position - end);
    final distance = direction.distance;
    final power = min(distance / 100, 1.0);
    final force = direction.normalized * power * 15;
    cueBall.velocity = force;

    // Simulate physics for a short time
    for (int i = 0; i < maxTrajectoryPoints; i++) {
      // Store current position
      trajectoryPoints.add(cueBall.position);

      // Simulate movement
      for (var ball in simulatedBalls) {
        ball.position += ball.velocity;
        ball.velocity *= 0.98; // friction

        // Simple wall collisions
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

      // Simple ball collisions (just for trajectory)
      for (int i = 0; i < simulatedBalls.length; i++) {
        for (int j = i + 1; j < simulatedBalls.length; j++) {
          Ball a = simulatedBalls[i];
          Ball b = simulatedBalls[j];

          final dx = b.position.dx - a.position.dx;
          final dy = b.position.dy - a.position.dy;
          final dist = sqrt(dx * dx + dy * dy);
          final minDist = a.radius + b.radius;

          if (dist < minDist) {
            final nx = dx / dist;
            final ny = dy / dist;

            // Simple bounce
            a.velocity = Offset(
              a.velocity.dx - nx * 1.5,
              a.velocity.dy - ny * 1.5,
            );
            b.velocity = Offset(
              b.velocity.dx + nx * 1.5,
              b.velocity.dy + ny * 1.5,
            );

            // Stop tracking after first collision for performance
            if (a.isCue || b.isCue) {
              return;
            }
          }
        }
      }
    }
  }

  void _startMovement() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        bool allStopped = true;

        for (var ball in balls) {
          if (ball.velocity != Offset.zero) {
            allStopped = false;
            ball.position += ball.velocity;

            // Apply friction
            ball.velocity *= 0.98;

            if (ball.velocity.distance < 0.1) {
              ball.velocity = Offset.zero;
            }
          }
        }

        _handleCollisions();
        _checkPockets();

        if (allStopped && balls.every((b) => b.velocity == Offset.zero)) {
          timer.cancel();
          isPlayerTurn = !isPlayerTurn;
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
          // Calculate collision normal
          final nx = dx / dist;
          final ny = dy / dist;

          // Calculate relative velocity
          final vx = b.velocity.dx - a.velocity.dx;
          final vy = b.velocity.dy - a.velocity.dy;
          final relativeVelocity = (vx * nx + vy * ny);

          // Only collide if moving toward each other
          if (relativeVelocity > 0) continue;

          // Calculate impulse scalar
          final impulse = 2.0 * relativeVelocity / 2.0;

          // Apply impulse
          a.velocity = Offset(
            a.velocity.dx - impulse * nx,
            a.velocity.dy - impulse * ny,
          );
          b.velocity = Offset(
            b.velocity.dx + impulse * nx,
            b.velocity.dy + impulse * ny,
          );

          // Separate balls to avoid sticking
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
      for (var pocket in pockets) {
        if ((ball.position - pocket).distance < pocketRadius) {
          toRemove.add(ball);

          if (ball.isCue) {
            // Cue ball pocketed - foul
            _resetCueBall();
          } else {
            // Score points
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
    final cueBall = balls.firstWhere((b) => b.isCue);
    cueBall.position = Offset(
      tableBorderWidth + 100,
      tableHeight / 2 + tableBorderWidth,
    );
    cueBall.velocity = Offset.zero;
  }

  void _hitCueBall(Offset end) {
    if (!isPlayerTurn) return;

    final cueBall = balls.firstWhere((b) => b.isCue);
    final direction = (cueBall.position - end);
    final distance = direction.distance;
    final power = min(distance / 100, 1.0); // Limit max power
    final force = direction.normalized * power * 15;

    cueBall.velocity = force;
    _startMovement();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tableWidth == 0) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Ball cueBall = balls.firstWhere((b) => b.isCue);
    bool canShoot =
        isPlayerTurn && balls.every((b) => b.velocity == Offset.zero);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Colors.brown[800]),
        child: Stack(
          children: [
            // Table border (wooden rails)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.brown[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(tableBorderWidth / 2),
              ),
            ),

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
                  width: pocketRadius * 2,
                  height: pocketRadius * 2,
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
            if (aimStart != null && canShoot)
              CustomPaint(
                painter: TrajectoryPainter(trajectoryPoints),
                size: Size.infinite,
              ),

            // Aiming line
            if (aimStart != null && canShoot)
              CustomPaint(
                painter: CueLinePainter(
                  start: cueBall.position,
                  end: aimStart!,
                  power: (cueBall.position - aimStart!).distance,
                ),
                size: Size.infinite,
              ),

            // Score display
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    'Player: $playerScore',
                    style: TextStyle(
                      color: isPlayerTurn ? Colors.yellow : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Opponent: $opponentScore',
                    style: TextStyle(
                      color: !isPlayerTurn ? Colors.yellow : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            if (canShoot)
              GestureDetector(
                onPanStart: (details) {
                  aimStart = details.localPosition;
                  _calculateTrajectory(details.localPosition);
                },
                onPanUpdate: (details) {
                  setState(() {
                    aimStart = details.localPosition;
                    _calculateTrajectory(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  if (aimStart != null) {
                    _hitCueBall(aimStart!);
                    aimStart = null;
                    trajectoryPoints.clear();
                  }
                },
                behavior: HitTestBehavior.translucent,
              ),
          ],
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

    // Draw power indicator (red part)
    final powerLength = min(power, 100);
    final powerEnd = start + (end - start).normalized * powerLength.toDouble();
    canvas.drawLine(start, powerEnd, powerPaint);

    // Draw aiming line (white part)
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

    // Draw dashed line
    for (int i = 0; i < points.length - 1; i++) {
      if (i % 2 == 0) {
        // Make it dashed
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    // Draw arrow at the end
    if (points.length > 1) {
      final last = points.last;
      final secondLast = points[points.length - 2];
      final angle = atan2(last.dy - secondLast.dy, last.dx - secondLast.dx);

      // Draw arrow head
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

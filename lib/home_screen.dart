// import 'package:flutter/material.dart';
//
// class BallTriangleScreen extends StatelessWidget {
//   final double ballSize = 20.0;
//   final double spacing = 2.0;
//
//   const BallTriangleScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.green[800],
//       body: Stack(
//         alignment: Alignment.center,
//         children: [
//           _buildBall(0, 3, Colors.red),
//           _buildBall(1, 2, Colors.blue),
//           _buildBall(1, 4, Colors.orange),
//           _buildBall(2, 1, Colors.purple),
//           _buildBall(2, 3, Colors.black), // the 8 ball
//           _buildBall(2, 5, Colors.brown),
//           _buildBall(3, 0, Colors.pink),
//           _buildBall(3, 2, Colors.yellow),
//           _buildBall(3, 4, Colors.cyan),
//           _buildBall(3, 6, Colors.teal),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBall(int row, int col, Color color) {
//     return Positioned(
//       top: row * (ballSize + spacing),
//       left: col * (ballSize / 2 + spacing),
//       child: Container(
//         width: ballSize,
//         height: ballSize,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: color,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black45,
//               offset: Offset(2, 2),
//               blurRadius: 4,
//             ),
//           ],
//         ),
//         alignment: Alignment.center,
//         child: Text('●', style: TextStyle(color: Colors.white, fontSize: 10)),
//       ),
//     );
//   }
// }



import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/services.dart';

class EightBallPoolGame extends Forge2DGame
    with TapDetector, KeyboardEvents, HasCollisionDetection {
  bool _isAiming = false;
  Vector2? _aimStartPosition;
  late final SpriteComponent _cueStick;
  final double _ballRadius = 0.5;
  final double _maxForce = 100;
  bool _allBallsStopped = true;

  EightBallPoolGame() : super(gravity: Vector2.zero(), zoom: 20) {
    camera.viewport = FixedResolutionViewport(resolution: Vector2(40, 80));
  }

  @override
  Color backgroundColor() => const Color(0xFF0a5c36);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _createCueStick();
    _initializeGame();
  }

  void _initializeGame() {
    _createTable();
    _rackBalls();
    _createCueBall();
  }

  void _createTable() {
    final worldSize = size;
    final tableWidth = worldSize.x * 0.9;
    final tableHeight = worldSize.y * 0.8;
    final tablePosition = worldSize / 2;

    final tableBodyDef = BodyDef(
      position: tablePosition,
      type: BodyType.static,
    );

    final tableBody = world.createBody(tableBodyDef);
    final tableShape = PolygonShape()
      ..setAsBox(
        tableWidth / 2,
        tableHeight / 2,
        Vector2.zero(),
        0,
      );

    tableBody.createFixture(FixtureDef(tableShape)
      ..restitution = 0.7
      ..friction = 0.2);

        _createCushions(tableBody, tableWidth, tableHeight);
    _createPockets(tableBody, tableWidth, tableHeight);
  }

  void _createCushions(Body tableBody, double width, double height) {
    final cushionThickness = 0.2;

    final positions = [
      Vector2(0, -height / 2 - cushionThickness / 2), // Top
      Vector2(0, height / 2 + cushionThickness / 2), // Bottom
      Vector2(-width / 2 - cushionThickness / 2, 0), // Left
      Vector2(width / 2 + cushionThickness / 2, 0), // Right
    ];

    final sizes = [
      Vector2(width / 2, cushionThickness / 2), // Top
      Vector2(width / 2, cushionThickness / 2), // Bottom
      Vector2(cushionThickness / 2, height / 2), // Left
      Vector2(cushionThickness / 2, height / 2), // Right
    ];

    for (var i = 0; i < positions.length; i++) {
      final shape = PolygonShape()
        ..setAsBox(sizes[i].x, sizes[i].y, positions[i], 0);
      tableBody.createFixture(FixtureDef(shape)
        ..restitution = 0.9
        ..friction = 0.1);
    }
  }

  void _createPockets(Body tableBody, double width, double height) {
    final pocketRadius = 0.8;
    final positions = [
      Vector2(-width / 2, -height / 2),
      Vector2(0, -height / 2),
      Vector2(width / 2, -height / 2),
      Vector2(-width / 2, height / 2),
      Vector2(0, height / 2),
      Vector2(width / 2, height / 2),
    ];

    for (final position in positions) {
      final pocketShape = CircleShape()
        ..radius = pocketRadius
        ..position.setFrom(position);

      tableBody.createFixture(FixtureDef(pocketShape)
        ..isSensor = true
        ..userData = {'type': 'pocket'});
      }
      }

  void _rackBalls() {
    final rackPosition = Vector2(0, size.y * 0.3);

    _createBall(rackPosition, 8, Colors.black); // 8-ball center

    final rows = 5;
    var ballIndex = 1;
    final solidColors = [
      Colors.yellow,
      Colors.blue,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.brown,
    ];
    final stripedColors = [
      Colors.yellowAccent,
      Colors.blueAccent,
      Colors.redAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.greenAccent,
      Colors.brown.withValues(alpha: 0.5),
    ];

    for (var row = 0; row < rows; row++) {
      final ballsInRow = row + 1;
      for (var col = 0; col < ballsInRow; col++) {
        if (ballIndex == 8) {
          ballIndex++;
        }
        if (ballIndex > 15) return;

        final offsetX = (col - row / 2) * (_ballRadius * 2.1);
        final offsetY = row * (_ballRadius * 1.8);
        final position = rackPosition + Vector2(offsetX, offsetY);
        final isSolid = ballIndex <= 7;
        _createBall(
          position,
          ballIndex,
          isSolid
              ? solidColors[ballIndex - 1]
              : stripedColors[ballIndex - 9],
        );
        ballIndex++;
      }
    }
  }

  void _createBall(Vector2 position, int number, Color color) {
    final bodyDef = BodyDef(
      position: position,
      type: BodyType.dynamic,
      linearDamping: 0.2,
      angularDamping: 0.2,
    );

    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = _ballRadius;

    body.createFixture(FixtureDef(shape)
      ..density = 1.0
      ..restitution = 0.95
      ..friction = 0.1
      ..userData = {'type': 'ball', 'number': number, 'color': color});
  }

  void _createCueBall() {
    final position = Vector2(0, -size.y * 0.3);
    _createBall(position, 0, Colors.white);
  }

  Future<void> _createCueStick() async {
    final sprite = await Sprite.load('cue_stick.png'); // Asset required
    _cueStick = SpriteComponent(
      sprite: sprite,
      size: Vector2(10, 0.5),
      anchor: Anchor.centerLeft,
    );
    add(_cueStick);
    _cueStick.angle = 0;
    _updateCueStickPosition();
  }

  void _updateCueStickPosition() {
    // Find the cue ball (ball with number 0)
    final cueBallComponents = world.children.whereType<BodyComponent>().where(
          (bodyComponent) {
        for (final fixture in bodyComponent.body.fixtures) {
          final userData = fixture.userData as Map<String, dynamic>?;
          if (userData != null && userData['number'] == 0) {
            return true;
          }
        }
        return false;
      },
    );

    if (cueBallComponents.isNotEmpty) {
      final cueBallComponent = cueBallComponents.first;
      // Update cue stick position and angle
      _cueStick.position = cueBallComponent.body.position;
      if (_aimStartPosition != null) {
        _cueStick.angle =
            (cueBallComponent.body.position - _aimStartPosition!).angleTo(Vector2(1, 0));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_allBallsStopped) {
      _allBallsStopped = true; // Assume all balls are stopped until proven otherwise

      // Iterate through all bodies in the world
      for (final body in world.children.whereType<BodyComponent>()) {
        final bodyInstance = body.body;

        // Check if this is a ball
        final isBall = bodyInstance.fixtures.any((f) {
          final userData = f.userData as Map<String, dynamic>?;
          return userData != null && userData['type'] == 'ball';
        });

        // If it's a ball and still moving, set _allBallsStopped to false
        if (isBall &&
            (bodyInstance.linearVelocity.length2 >= 0.01 ||
                bodyInstance.angularVelocity.abs() >= 0.01)) {
          _allBallsStopped = false;
          break; // No need to check further
        }
      }

      if (_allBallsStopped) {
        _updateCueStickPosition();
      }
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (!_allBallsStopped) return;

    try {
      final cueBallComponent = world.children.whereType<BodyComponent>().firstWhere(
            (bodyComponent) {
          final body = bodyComponent.body;
          for (final fixture in body.fixtures) {
            final userData = fixture.userData as Map<String, dynamic>?;
            if (userData != null && userData['number'] == 0) {
              return true;
            }
          }
          return false;
        },
      );

      _isAiming = true;
      _aimStartPosition = info.eventPosition.global;
      _updateCueStickPosition();
    } catch (e) {
      // Cue ball not found, handle accordingly
      print('Cue ball not found');
    }
  }

  @override
  void onTapUp(TapUpInfo info) {
    if (!_isAiming || !_allBallsStopped) return;

    try {
      final cueBallComponent = world.children.whereType<BodyComponent>().firstWhere(
            (bodyComponent) {
          final body = bodyComponent.body;
          for (final fixture in body.fixtures) {
            final userData = fixture.userData as Map<String, dynamic>?;
            if (userData != null && userData['number'] == 0) {
              return true;
            }
          }
          return false;
        },
      );

      if (_aimStartPosition != null) {
        final endPosition = info.eventPosition.global;
        final direction = (cueBallComponent.body.position - endPosition).normalized();
        final distance = (endPosition - _aimStartPosition!).length;
        final force = direction * distance.clamp(0, _maxForce);

        cueBallComponent.body.applyLinearImpulse(force);
        _allBallsStopped = false;
      }
    } catch (e) {
      print('Cue ball not found: $e');
    } finally {
      _isAiming = false;
      _aimStartPosition = null;
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.space)) {
      try {
        final cueBallComponent = world.children.whereType<BodyComponent>().firstWhere(
              (bodyComponent) {
            final body = bodyComponent.body;
            for (final fixture in body.fixtures) {
              final userData = fixture.userData as Map<String, dynamic>?;
              if (userData != null && userData['number'] == 0) {
                return true;
              }
            }
            return false;
          },
        );

        if (_aimStartPosition != null) {
          final direction = (cueBallComponent.body.position - _aimStartPosition!).normalized();
          cueBallComponent.body.applyLinearImpulse(direction * _maxForce * 1.5);
          _allBallsStopped = false;
          return KeyEventResult.handled;
        }
      } catch (e) {
        print('Cue ball not found: $e');
      }
    }
    return KeyEventResult.ignored;
  }

  void beginContact(Contact contact) {
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    // Helper functions with explicit null checks
    bool isPocket(Fixture fixture) {
      final userData = fixture.userData;
      return userData is Map && userData['type'] == 'pocket';
    }

    bool isBall(Fixture fixture) {
      final userData = fixture.userData;
      return userData is Map && userData['type'] == 'ball';
    }

    // Check all possible combinations
    if (isPocket(fixtureA) && isBall(fixtureB)) {
      _handleBallInPocket(fixtureB);
    } else if (isPocket(fixtureB) && isBall(fixtureA)) {
      _handleBallInPocket(fixtureA);
    }
  }

  void _handleBallInPocket(Fixture ballFixture) {
    final userData = ballFixture.userData;
    if (userData is! Map) return;

    final ballNumber = userData['number'];
    Future.delayed(Duration.zero, () {
      if (ballFixture.body.isActive) {  // Additional safety check
        world.destroyBody(ballFixture.body);
        if (ballNumber == 0) {
          _createCueBall();
        }
      }
    });
  }

}


import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

class PoolBall extends BodyComponent {
  final int ballNumber;
  final Color color;
  final double radius;

  PoolBall({
    required Offset position,
    required this.ballNumber,
    required this.color,
    this.radius = 0.5,
  });

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      position: position,
      type: BodyType.dynamic,
      linearDamping: 0.5,
      angularDamping: 0.5,
    );

    final shape = CircleShape()..radius = radius;
    final fixtureDef =
        FixtureDef(shape)
          ..restitution = 0.95
          ..friction = 0.3
          ..density = 1.0;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    // (Keep your render implementation here)
  }
}

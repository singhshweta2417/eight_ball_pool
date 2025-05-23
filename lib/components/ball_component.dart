import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class BallComponent extends BodyComponent {
  final int number;
  final Color color;
  final double radius;
  final Vector2 initialPosition;

  late final SpriteComponent sprite;

  BallComponent({
    required this.number,
    required this.color,
    required this.radius,
    required this.initialPosition,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create visual representation
    sprite = SpriteComponent(
      sprite: await Sprite.load('pool_ball_$number.png'),
      size: Vector2.all(2 * radius),
      anchor: Anchor.center,
    );
    add(sprite);
  }

  @override
  Body createBody() {
    // Physics body creation
    final bodyDef = BodyDef(
      position: initialPosition,
      type: BodyType.dynamic,
    );

    final shape = CircleShape()..radius = radius;

    final body = world.createBody(bodyDef);
    body.createFixture(FixtureDef(shape)
      ..density = 1.0
      ..restitution = 0.95
      ..userData = {'type': 'ball', 'number': number});

        return body;
    }
}
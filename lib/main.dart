import 'package:eight_ball_rummy/test.dart';
import 'package:eight_ball_rummy/view/auth/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      home:
      // Drawer3D()
      PoolGameScreen()
      //GameWidget(game: EightBallPoolGame())
      // BallTriangleScreen(),
    );
  }
}

import 'package:flutter/material.dart';

class NotificationsInfoPage extends StatelessWidget {
  const NotificationsInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Las notificaciones se programan automaticamente al iniciar la app.',
          ),
        ),
      ),
    );
  }
}

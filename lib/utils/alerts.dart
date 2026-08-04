import 'package:flutter/material.dart';

enum AlertType { success, error, warning, info }

void showAlert(BuildContext context, String message, AlertType type) {
  Color bg;
  IconData icon;

  switch (type) {
    case AlertType.success:
      bg = Colors.green.shade700;
      icon = Icons.check_circle;
      break;
    case AlertType.error:
      bg = Colors.red.shade700;
      icon = Icons.error;
      break;
    case AlertType.warning:
      bg = Colors.orange.shade700;
      icon = Icons.warning;
      break;
    case AlertType.info:
      bg = Colors.blue.shade700;
      icon = Icons.info;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}
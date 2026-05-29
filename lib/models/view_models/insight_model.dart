import 'package:flutter/material.dart';

@immutable
class InsightModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'warning' | 'info' | 'success'
  final IconData icon;

  const InsightModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
  });
}

import 'package:flutter/material.dart';
import '../utils/theme.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  const AppLoading({super.key, this.message});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(color: AppColors.primary),
    if (message != null) ...[const SizedBox(height: 16), Text(message!)],
  ]));
}

class AppEmpty extends StatelessWidget {
  final String emoji; final String title; final String? subtitle; final Widget? action;
  const AppEmpty({super.key, required this.emoji, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, textAlign: TextAlign.center)],
      if (action != null) ...[const SizedBox(height: 16), action!],
    ]),
  ));
}

class StatusBadge extends StatelessWidget {
  final String label; final Color color; final IconData? icon;
  const StatusBadge({super.key, required this.label, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, color: color, size: 13), const SizedBox(width: 4)],
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class InfoRow extends StatelessWidget {
  final IconData icon; final String text; final bool bold;
  const InfoRow({super.key, required this.icon, required this.text, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 15, color: AppColors.textGray), const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13,
          color: bold ? AppColors.textDark : AppColors.textGray,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]));
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 4, height: 20, color: AppColors.primary),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]));
}

class PriceRow extends StatelessWidget {
  final String label; final String value; final bool bold;
  const PriceRow({super.key, required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: bold ? AppColors.primary : AppColors.textDark)),
    ]));
}

class BroadcastBanner extends StatelessWidget {
  final String title;
  final String body;
  const BroadcastBanner({super.key, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.campaign_outlined, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(body, style: const TextStyle(fontSize: 13)),
      ])),
    ]),
  );
}

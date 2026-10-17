import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';

class CommandHeader extends StatelessWidget {
  const CommandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: RoadSafeColors.card,
        border: Border(bottom: BorderSide(color: RoadSafeColors.border)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF59E0B)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RoadSafe',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('Central Luzon / Bulacan',
                style: TextStyle(fontSize: 11, color: RoadSafeColors.muted)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: RoadSafeColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: RoadSafeColors.green.withValues(alpha: 0.2)),
          ),
          child: const Text('Prototype',
              style: TextStyle(
                  color: RoadSafeColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

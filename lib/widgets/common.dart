import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Hatched square used for plots / assets in Cropin Grow.
class PlotIcon extends StatelessWidget {
  const PlotIcon({super.key, this.size = 30, this.color = CropinColors.subText, this.filled = false});
  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PlotPainter(color, filled));
}

class _PlotPainter extends CustomPainter {
  _PlotPainter(this.color, this.filled);
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeJoin = StrokeJoin.round;
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.width * 0.12));
    if (filled) {
      canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.18));
    }
    canvas.drawRRect(r.deflate(p.strokeWidth / 2), p);
    canvas.save();
    canvas.clipRRect(r);
    final step = size.width / 3.2;
    for (var x = -size.width; x < size.width * 2; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) => old.color != color || old.filled != filled;
}

/// "C" (current) / "U" (upcoming) status dot.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 26});
  final String status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final current = status == 'current';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current ? CropinColors.green : CropinColors.chipGrey,
        shape: BoxShape.circle,
      ),
      child: Text(current ? 'C' : 'U',
          style: TextStyle(color: Colors.white, fontSize: size * 0.55)),
    );
  }
}

class AreaChip extends StatelessWidget {
  const AreaChip(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F6),
          border: Border.all(color: CropinColors.text, width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: CropinColors.text)),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: CropinColors.primary,
            disabledBackgroundColor: const Color(0xFFD5D8DB),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: onPressed,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: CropinColors.primary,
            side: const BorderSide(color: CropinColors.primary, width: 1.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
}

/// Bottom action bar with two buttons (Cancel / Submit, Save Draft / Submit).
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, -2)),
        ]),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(child: left),
            const SizedBox(width: 18),
            Expanded(child: right),
          ]),
        ),
      );
}

class SectionGap extends StatelessWidget {
  const SectionGap({super.key, this.height = 10});
  final double height;

  @override
  Widget build(BuildContext context) => Container(height: height, color: CropinColors.divider);
}

/// Small pill shown on things created by the voice agent.
class VoiceBadge extends StatelessWidget {
  const VoiceBadge({super.key, this.label = 'Voice'});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: CropinColors.voiceFilled.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.mic, size: 10, color: CropinColors.voiceFilled),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: CropinColors.voiceFilled, fontWeight: FontWeight.w600)),
        ]),
      );
}

String formatDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
}

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

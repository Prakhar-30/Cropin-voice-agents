import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screens.dart';
import 'common.dart';

BoxDecoration _card() => BoxDecoration(
      color: Colors.white,
      border: Border.all(color: CropinColors.border, width: 1.3),
      borderRadius: BorderRadius.circular(8),
    );

class FarmerCard extends StatelessWidget {
  const FarmerCard({super.key, required this.farmer});
  final Farmer farmer;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final assets = store.assetsOf(farmer.id).length;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => FarmerDetailScreen(farmerId: farmer.id))),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: _card(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF2F3F4),
            border: Border.all(color: const Color(0xFFDADDE0), width: 2),
          ),
          child: const Icon(Icons.person_outline, color: CropinColors.subText, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text('${farmer.name} (${farmer.code})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (farmer.createdByVoice) ...[const SizedBox(width: 6), const VoiceBadge()],
            ]),
            const SizedBox(height: 4),
            Text(farmer.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: CropinColors.subText)),
            const SizedBox(height: 3),
            Text('Assets ($assets) | Projects (${farmer.projectIds.length}) | Forms (0)',
                style: const TextStyle(fontSize: 13, color: CropinColors.subText)),
          ]),
        ),
      ]),
    ),
    );
  }
}

class AssetCard extends StatelessWidget {
  const AssetCard({super.key, required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final f = AppStore.instance.farmer(asset.farmerId);
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: asset.id))),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _card(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 3), child: PlotIcon(size: 21)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(asset.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (asset.createdByVoice) ...[const SizedBox(width: 6), const VoiceBadge()],
            ]),
            const SizedBox(height: 4),
            Text(
                asset.subVariety.isEmpty
                    ? '${asset.variety} (${asset.crop})'
                    : '${asset.variety} -  ${asset.subVariety}  (${asset.crop})',
                style: const TextStyle(fontSize: 14, color: CropinColors.text)),
            const SizedBox(height: 3),
            Text(f?.name ?? '', style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
            const SizedBox(height: 2),
            Text(asset.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
            const SizedBox(height: 10),
            Row(children: [
              AreaChip(asset.areaLabel),
              const SizedBox(width: 10),
              StatusDot(status: asset.status),
              const SizedBox(width: 10),
              if (asset.health == 'attention') ...[
                const Icon(Icons.warning_amber_rounded, size: 13, color: CropinColors.attention),
                const SizedBox(width: 3),
                const Flexible(
                  child: Text('Needs attention',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: CropinColors.attention)),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    ),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.distanceKm});
  final FieldTask task;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final a = store.asset(task.assetId);
    final f = store.farmer(task.farmerId);
    final now = DateTime.now();
    final overdue = task.isOverdue(now);
    final today = task.isDueToday(now);
    final done = task.status == 'completed';
    final color = done
        ? CropinColors.goodGreen
        : overdue
            ? CropinColors.attention
            : today
                ? CropinColors.voiceCheck
                : CropinColors.subText;
    final label = done
        ? 'Completed'
        : overdue
            ? 'Overdue'
            : today
                ? 'Due today'
                : 'Upcoming';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.assignment_outlined, color: color, size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${a?.name ?? ''} · ${a?.crop ?? ''}',
                style: const TextStyle(fontSize: 12, color: CropinColors.text)),
            Text('${f?.name ?? ''} · ${a?.locality ?? ''}',
                style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(formatDate(task.due),
                  style: const TextStyle(fontSize: 10, color: CropinColors.subText)),
              const Spacer(),
              if (distanceKm != null)
                Text('${distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 10, color: CropinColors.subText)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Header row with the primary "Add …" button and Sort / Filter actions.
class ListHeader extends StatelessWidget {
  const ListHeader({super.key, required this.buttonLabel, required this.onAdd, this.onFilter});
  final String buttonLabel;
  final VoidCallback onAdd;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
        child: Row(children: [
          if (buttonLabel.isNotEmpty)
            SizedBox(
              height: 39,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CropinColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onPressed: onAdd,
                child: Text(buttonLabel),
              ),
            ),
          const Spacer(),
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.unfold_more, color: CropinColors.text),
                  label: const Text('Sort',
                      style: TextStyle(color: CropinColors.primary, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: onFilter,
                  icon: const Icon(Icons.filter_alt_outlined, color: CropinColors.primary),
                  label: const Text('Filter',
                      style: TextStyle(color: CropinColors.primary, fontSize: 15)),
                ),
              ]),
            ),
          ),
        ]),
      );
}

/// Chips describing the active voice filter, with a clear action.
class ActiveFilterBar extends StatelessWidget {
  const ActiveFilterBar({super.key, required this.chips, required this.heard, required this.onClear});
  final List<String> chips;
  final String heard;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty && heard.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF3),
        border: Border.all(color: CropinColors.voiceFilled),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mic, size: 13, color: CropinColors.voiceFilled),
          const SizedBox(width: 6),
          Expanded(
            child: Text('"$heard"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ),
          InkWell(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Text('Clear',
                    style: TextStyle(color: CropinColors.primary, fontWeight: FontWeight.w600)),
              )),
        ]),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: CropinColors.voiceFilled),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(c, style: const TextStyle(fontSize: 11)),
              ),
          ]),
        ],
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../voice/nlu/search_parser.dart';
import '../widgets/common.dart';
import '../widgets/list_cards.dart';
import 'add_asset_screen.dart';
import 'add_farmer_screen.dart';
import 'briefing_screen.dart';
import 'nav_controller.dart';

class _ListTitle extends StatelessWidget {
  const _ListTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Row(children: [
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ),
          ],
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text('No results. Try another voice search or clear the filter.',
              textAlign: TextAlign.center, style: TextStyle(color: CropinColors.subText)),
        ),
      );
}

Widget _filterBar(SearchEntity e) {
  final q = NavController.instance.queries[e];
  if (q == null) return const SizedBox.shrink();
  return ActiveFilterBar(
    chips: q.describe(),
    heard: q.heard,
    onClear: () => NavController.instance.clear(e),
  );
}

class FarmersTab extends StatelessWidget {
  const FarmersTab({super.key, required this.text});
  final ValueNotifier<String> text;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, NavController.instance, text]),
      builder: (context, _) {
        final list = store.searchFarmers(NavController.instance.queries[SearchEntity.farmers], text.value);
        return ListView.builder(
          itemCount: list.length + 4,
          itemBuilder: (context, i) {
            if (i == 0) {
              return ListHeader(
                buttonLabel: 'Add Farmer',
                onAdd: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AddFarmerScreen())),
              );
            }
            if (i == 1) return _filterBar(SearchEntity.farmers);
            if (i == 2) return _ListTitle('Farmers (${list.length})');
            if (i == 3) return list.isEmpty ? const _Empty() : const SizedBox.shrink();
            return FarmerCard(farmer: list[i - 4]);
          },
        );
      },
    );
  }
}

class AssetsTab extends StatelessWidget {
  const AssetsTab({super.key, required this.text});
  final ValueNotifier<String> text;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, NavController.instance, text]),
      builder: (context, _) {
        final list = store.searchAssets(NavController.instance.queries[SearchEntity.assets], text.value);
        return ListView.builder(
          itemCount: list.length + 4,
          itemBuilder: (context, i) {
            if (i == 0) {
              return ListHeader(
                buttonLabel: 'Add Asset',
                onAdd: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AddAssetScreen())),
              );
            }
            if (i == 1) return _filterBar(SearchEntity.assets);
            if (i == 2) {
              return _ListTitle('Assets (${list.length})',
                  trailing: const Row(children: [
                    StatusDot(status: 'current', size: 18),
                    SizedBox(width: 4),
                    Text('Current', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 12),
                    StatusDot(status: 'upcoming', size: 18),
                    SizedBox(width: 4),
                    Text('Upcoming', style: TextStyle(fontSize: 13)),
                  ]));
            }
            if (i == 3) return list.isEmpty ? const _Empty() : const SizedBox.shrink();
            return AssetCard(asset: list[i - 4]);
          },
        );
      },
    );
  }
}

class TasksTab extends StatelessWidget {
  const TasksTab({super.key, required this.text});
  final ValueNotifier<String> text;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, NavController.instance, text]),
      builder: (context, _) {
        final list = store.searchTasks(NavController.instance.queries[SearchEntity.tasks], text.value);
        return ListView.builder(
          itemCount: list.length + 4,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Row(children: [
                  Expanded(
                    child: PrimaryButton(
                      label: "What's my day?",
                      icon: Icons.record_voice_over_outlined,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const BriefingScreen(autoSpeak: true))),
                    ),
                  ),
                ]),
              );
            }
            if (i == 1) return _filterBar(SearchEntity.tasks);
            if (i == 2) return _ListTitle('Tasks (${list.length})');
            if (i == 3) return list.isEmpty ? const _Empty() : const SizedBox.shrink();
            return TaskCard(task: list[i - 4]);
          },
        );
      },
    );
  }
}

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final voiceFarmers = store.farmers.where((f) => f.createdByVoice).length;
        final voiceAssets = store.assets.where((a) => a.createdByVoice).length;
        final voiceAlerts = store.alerts.where((a) => a.byVoice).length;
        final notes = store.photos.where((p) => p.note.isNotEmpty).length;
        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const _ListTitle('Voice agent activity'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              _Tile('Farmers', voiceFarmers),
              _Tile('Assets', voiceAssets),
              _Tile('Alerts', voiceAlerts),
              _Tile('Photo notes', notes),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionGap(height: 8),
          _ListTitle('Alerts (${store.alerts.length})'),
          for (final a in store.alerts)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: CropinColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notification_important_outlined,
                    color: a.severity == 'High'
                        ? CropinColors.attention
                        : a.severity == 'Medium'
                            ? CropinColors.voiceCheck
                            : CropinColors.goodGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text('${a.type} · ${a.severity}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      if (a.byVoice) ...[const SizedBox(width: 6), VoiceBadge(label: a.language.toUpperCase())],
                    ]),
                    Text(a.assetIds.map((id) => store.asset(id)?.name ?? id).join(', '),
                        style: const TextStyle(color: CropinColors.subText)),
                    if (a.note.isNotEmpty)
                      Text('"${a.note}"',
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11)),
                    Text('${formatDate(a.createdAt)} · ${formatTime(a.createdAt)}',
                        style: const TextStyle(fontSize: 10, color: CropinColors.hint)),
                  ]),
                ),
              ]),
            ),
          const SectionGap(height: 8),
          _ListTitle('Photos (${store.photos.length})'),
          if (store.photos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text('No photos yet. Use Take Photos and hold the shutter to add a voice note.',
                  style: TextStyle(color: CropinColors.subText)),
            ),
          for (final p in store.photos)
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: CropinColors.primary),
              title: Text(p.note.isEmpty ? '(no note)' : p.note,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                store.asset(p.assetId)?.name ?? '-',
                ...p.tags,
                formatTime(p.createdAt),
              ].join(' · ')),
            ),
        ]);
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: CropinColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text('$value',
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, color: CropinColors.voiceFilled)),
            Text(label, style: const TextStyle(fontSize: 10, color: CropinColors.subText)),
          ]),
        ),
      );
}

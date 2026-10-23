import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/list_cards.dart';
import '../widgets/top_bar.dart';
import 'add_asset_screen.dart';
import 'raise_alert_screen.dart';

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: CropinColors.subText))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]),
    );

/// Farmer profile opened by voice ("open farmer Mahesh Hegde") or by tapping
/// a farmer card.
class FarmerDetailScreen extends StatelessWidget {
  const FarmerDetailScreen({super.key, required this.farmerId});
  final String farmerId;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final f = store.farmer(farmerId);
        if (f == null) return const Scaffold(body: Center(child: Text('Farmer not found')));
        final plots = store.assetsOf(f.id);
        final tasks = store.tasks.where((t) => t.farmerId == f.id).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
        return Scaffold(
          appBar: cropinTitleBar(context, f.name),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row('Farmer code', f.code),
                _row('Mobile', '+91 ${f.phone}'),
                _row('Address', f.address),
                _row('Projects',
                    f.projectIds.map((id) => store.project(id)?.name ?? id).join(', ')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PrimaryButton(
                label: 'Add plot for ${f.name.split(' ').first}',
                icon: Icons.add_box_outlined,
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddAssetScreen(ownerId: f.id))),
              ),
            ),
            const SizedBox(height: 12),
            const SectionGap(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text('Plots (${plots.length})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final a in plots) AssetCard(asset: a),
            const SectionGap(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text('Tasks (${tasks.length})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final t in tasks) TaskCard(task: t),
          ]),
        );
      },
    );
  }
}

/// Plot details opened by voice ("open plot MH01 CA-1") or by tapping a plot.
class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key, required this.assetId});
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final a = store.asset(assetId);
        if (a == null) return const Scaffold(body: Center(child: Text('Plot not found')));
        final f = store.farmer(a.farmerId);
        return Scaffold(
          appBar: cropinTitleBar(context, a.name),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _row('Crop', '${a.variety}${a.subVariety.isEmpty ? '' : ' - ${a.subVariety}'} (${a.crop})'),
            _row('Belongs to', f == null ? '-' : '${f.name} (${f.code})'),
            _row('Project', store.project(a.projectId)?.name ?? '-'),
            _row('Area', a.areaLabel),
            _row('Soil', a.soil),
            _row('Irrigation', a.irrigation),
            _row('Location', a.address),
            _row('Crop health', a.health == 'attention' ? 'Needs attention' : 'Good'),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Assign to another farmer',
              icon: Icons.swap_horiz,
              onPressed: () => showAssignSheet(context, plotIds: [a.id]),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Raise alert on this plot',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RaiseAlertScreen(preselected: [a.id]))),
            ),
          ]),
        );
      },
    );
  }
}

/// Confirms "assign plot(s) to farmer". Voice fills plots and farmer; the user
/// can change either before confirming. Returns true when assigned.
Future<bool?> showAssignSheet(BuildContext context,
    {List<String> plotIds = const [], String? farmerId, String? heard}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AssignSheet(plotIds: plotIds, farmerId: farmerId, heard: heard),
  );
}

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.plotIds, this.farmerId, this.heard});
  final List<String> plotIds;
  final String? farmerId;
  final String? heard;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final store = AppStore.instance;
  late final Set<String> plots = {...widget.plotIds};
  late String? farmerId = widget.farmerId;

  @override
  Widget build(BuildContext context) {
    final candidates = [
      ...widget.plotIds.map(store.asset).whereType<Asset>(),
      ...store.assets.where((a) => !widget.plotIds.contains(a.id)),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(
            child: Text('Assign plot', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          if (widget.heard != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('"${widget.heard}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          VoiceSelectField<Farmer>(
            label: 'Assign to',
            required: true,
            value: store.farmer(farmerId),
            options: store.farmers,
            display: (f) => f.name,
            subtitle: (f) => '${f.code} · ${f.locality}',
            mark: widget.farmerId != null && farmerId == widget.farmerId
                ? VoiceMark.filled
                : VoiceMark.none,
            onChanged: (f) => setState(() => farmerId = f.id),
          ),
          Text('Plots (${plots.length} selected)',
              style: const TextStyle(fontSize: 13, color: CropinColors.subText)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView(shrinkWrap: true, children: [
              for (final a in candidates)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: plots.contains(a.id),
                  onChanged: (v) => setState(() => v == true ? plots.add(a.id) : plots.remove(a.id)),
                  title: Text('${a.name} · ${a.crop} · ${a.areaLabel}',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('Now: ${store.farmer(a.farmerId)?.name ?? '-'} · ${a.locality}',
                      style: const TextStyle(fontSize: 11)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: farmerId == null || plots.isEmpty
                ? 'Pick a farmer and plots'
                : 'Assign ${plots.length} plot${plots.length == 1 ? '' : 's'} to '
                    '${store.farmer(farmerId)!.name}',
            onPressed: farmerId == null || plots.isEmpty
                ? null
                : () {
                    store.assignAssets(plots.toList(), farmerId!);
                    Navigator.of(context).pop(true);
                  },
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../voice/nlu/search_parser.dart';
import '../widgets/common.dart';
import 'add_asset_screen.dart';
import 'add_farmer_screen.dart';
import 'briefing_screen.dart';
import 'nav_controller.dart';
import 'raise_alert_screen.dart';
import 'take_photos_screen.dart';
import 'voice_router.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool expanded = true;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        children: [
          const SizedBox(height: 18),
          Row(children: [
            _QuickAction(
                icon: Icons.person_add_alt_outlined,
                label: 'Add Farmer',
                onTap: () => _push(const AddFarmerScreen())),
            _QuickAction(
                icon: Icons.add_box_outlined,
                label: 'Add Asset',
                onTap: () => _push(const AddAssetScreen())),
            _QuickAction(
                icon: Icons.notification_add_outlined,
                label: 'Raise alert',
                onTap: () => _push(const RaiseAlertScreen())),
            _QuickAction(
                icon: Icons.add_a_photo_outlined,
                label: 'Take Photos',
                onTap: () => _push(const TakePhotosScreen())),
          ]),
          const SizedBox(height: 16),
          const SectionGap(height: 8),
          _VoiceCard(
            onAsk: () => VoiceRouter.listenAndRoute(context),
            onBriefing: () => _push(const BriefingScreen(autoSpeak: true)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Regional Analysis is outside this voice demo'))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: CropinColors.border, width: 1.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(children: [
                  Icon(Icons.travel_explore, color: CropinColors.primary, size: 30),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Regional Analysis',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w600, color: Color(0xFF1F4A3E))),
                  ),
                  Icon(Icons.chevron_right, color: CropinColors.subText, size: 30),
                ]),
              ),
            ),
          ),
          const SectionGap(height: 8),
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Row(children: [
                const Expanded(
                  child: Text('Farm Intelligence & Advisory',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                ),
                const Text('(5)', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500)),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 30),
              ]),
            ),
          ),
          if (expanded) ...[
            _AdvisoryCard(
              color: CropinColors.cropHealth,
              dark: CropinColors.cropHealthDark,
              icon: Icons.satellite_alt,
              title: 'Crop Health-germination',
              onTap: () {
                final q = SearchQuery()
                  ..entity = SearchEntity.assets
                  ..health = 'attention'
                  ..heard = 'Crop Health · Needs attention';
                NavController.instance.applySearch(q);
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _Metric(store.goodCount.toString().padLeft(2, '0'), 'Good', CropinColors.goodGreen),
                  const SizedBox(width: 26),
                  _Metric(store.attentionCount.toString().padLeft(2, '0'), 'Needs Attention',
                      CropinColors.attention),
                ]),
                const SizedBox(height: 6),
                const Text('Updated 0 Hour ago',
                    style: TextStyle(color: CropinColors.hint, fontSize: 13)),
              ]),
            ),
            _AdvisoryCard(
              color: CropinColors.yield,
              dark: CropinColors.yieldDark,
              icon: Icons.agriculture_outlined,
              title: 'Yield & Growth',
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Icon(Icons.arrow_circle_up, color: CropinColors.goodGreen, size: 22),
                  SizedBox(width: 4),
                  Text('234.3',
                      style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700, color: CropinColors.goodGreen)),
                  Text('%', style: TextStyle(fontSize: 18, color: CropinColors.goodGreen)),
                  Spacer(),
                  Text('00',
                      style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700, color: CropinColors.primary)),
                ]),
                Row(children: [
                  Expanded(child: Text('Forecasted Harvest\n(vs Re-estimated)', style: TextStyle(fontSize: 13))),
                  Text('Slow Growth Plots', style: TextStyle(fontSize: 13)),
                ]),
                Text('Updated 15 days ago', style: TextStyle(color: CropinColors.hint, fontSize: 13)),
              ]),
            ),
            for (final a in DemoData.advisories)
              _AdvisoryCard(
                color: switch (a.kind) {
                  'weather' => CropinColors.weather,
                  'indices' => CropinColors.indices,
                  _ => CropinColors.pest,
                },
                dark: switch (a.kind) {
                  'weather' => CropinColors.weatherDark,
                  'indices' => CropinColors.indicesDark,
                  _ => CropinColors.pestDark,
                },
                icon: switch (a.kind) {
                  'weather' => Icons.thermostat,
                  'indices' => Icons.satellite_alt_outlined,
                  _ => Icons.bug_report_outlined,
                },
                title: a.title,
                child: Text(a.text[store.language.code] ?? a.text['en']!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: CropinColors.text)),
              ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Icon(icon, size: 38, color: CropinColors.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 15, color: CropinColors.primary)),
            ]),
          ),
        ),
      );
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.onAsk, required this.onBriefing});
  final VoidCallback onAsk;
  final VoidCallback onBriefing;

  @override
  Widget build(BuildContext context) {
    final lang = AppStore.instance.language;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF24475A), Color(0xFF2F6B5E)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.graphic_eq, color: CropinColors.green, size: 26),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Voice Agents',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text('Offline · ${lang.nativeName}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text('Add farmers & plots, raise alerts, search and get your day — just speak.',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('ask-anything'),
              style: FilledButton.styleFrom(
                backgroundColor: CropinColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: onAsk,
              icon: const Icon(Icons.mic),
              label: const Text('Ask anything'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: onBriefing,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text("What's my day?"),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  const _AdvisoryCard({
    required this.color,
    required this.dark,
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });
  final Color color;
  final Color dark;
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 104,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                  ),
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: dark,
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600, color: CropinColors.primary)),
                        const SizedBox(height: 8),
                        child,
                      ],
                    ),
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.chevron_right, size: 30, color: CropinColors.primary),
                  ),
              ]),
            ),
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 14)),
      ]);
}

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../voice/nlu/search_parser.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';
import 'briefing_screen.dart';
import 'home_tab.dart';
import 'list_tabs.dart';
import 'nav_controller.dart';
import 'voice_router.dart';
import 'voice_settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final nav = NavController.instance;
  final controllers = List.generate(5, (_) => TextEditingController());
  final texts = List.generate(5, (_) => ValueNotifier<String>(''));

  static const _hints = [
    'Search Task', 'Search Farmers', 'Search Assets', 'Search Tasks', 'Search Reports',
  ];

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    for (final t in texts) {
      t.dispose();
    }
    super.dispose();
  }

  SearchEntity? _entityFor(int tab) => switch (tab) {
        NavController.farmers => SearchEntity.farmers,
        NavController.assets => SearchEntity.assets,
        NavController.tasks => SearchEntity.tasks,
        _ => null,
      };

  void _submit(int tab, String value) {
    if (tab == NavController.home) {
      // Home "Search Task": typed text goes to the Tasks list
      controllers[NavController.tasks].text = value;
      texts[NavController.tasks].value = value;
      nav.goTo(NavController.tasks);
      return;
    }
    texts[tab].value = value;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: nav,
      builder: (context, _) {
        final tab = nav.tab;
        return Scaffold(
          drawer: _drawer(context),
          appBar: CropinTopBar(
            key: ValueKey('topbar-$tab'),
            hint: _hints[tab],
            controller: controllers[tab],
            onSubmitted: (v) => _submit(tab, v),
            onMic: () => VoiceRouter.listenAndRoute(context,
                defaultEntity: _entityFor(tab),
                exampleKey: tab == NavController.home ? 'home' : 'search'),
            onBell: () => nav.goTo(NavController.reports),
          ),
          body: IndexedStack(index: tab, children: [
            const HomeTab(),
            FarmersTab(text: texts[NavController.farmers]),
            AssetsTab(text: texts[NavController.assets]),
            TasksTab(text: texts[NavController.tasks]),
            const ReportsTab(),
          ]),
          // One voice entry point on every tab (extended FAB, like the
          // persistent "Talk" button of Gemini / ChatGPT). Inside a section
          // it searches that section by default.
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('talk-to-cropin'),
            heroTag: 'talk',
            backgroundColor: CropinColors.green,
            foregroundColor: Colors.white,
            elevation: 4,
            onPressed: () => VoiceRouter.listenAndRoute(context, defaultEntity: _entityFor(tab)),
            icon: const Icon(Icons.mic),
            label: const Text('Talk to Cropin',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: _BottomNav(index: tab, onTap: nav.goTo),
        );
      },
    );
  }

  Drawer _drawer(BuildContext context) => Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: CropinColors.header),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Cropin Grow',
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Voice agents · ${AppStore.instance.language.nativeName}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_voice_outlined),
            title: const Text('Voice settings & language packs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const VoiceSettingsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text("What's my day"),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BriefingScreen(autoSpeak: true)));
            },
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Cropin Voice Agents',
            applicationVersion: '1.0.0',
            aboutBoxChildren: [
              Text('Offline voice agents for Cropin Grow: speak-to-fill forms, photo voice notes, '
                  'raise alert by voice and voice search / daily briefing in English, Hindi, '
                  'Kannada and Tamil. Demo data only.'),
            ],
          ),
        ]),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    Widget item(int i, String label, Widget Function(Color) icon) {
      final active = i == index;
      final color = active ? CropinColors.green : CropinColors.hint;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              icon(color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, -2)),
      ]),
      child: SafeArea(
        top: false,
        child: Row(children: [
          item(0, 'Home', (c) => Icon(index == 0 ? Icons.home : Icons.home_outlined, color: c, size: 28)),
          item(1, 'Farmers',
              (c) => Icon(index == 1 ? Icons.person : Icons.person_outline, color: c, size: 28)),
          item(2, 'Assets', (c) => PlotIcon(size: 25, color: c, filled: index == 2)),
          item(3, 'Tasks', (c) => Icon(Icons.assignment_outlined, color: c, size: 26)),
          item(4, 'Reports', (c) => Icon(Icons.insert_chart_outlined, color: c, size: 26)),
        ]),
      ),
    );
  }
}

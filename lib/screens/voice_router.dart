import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../voice/agent_strings.dart';
import '../voice/nlu/assign_parser.dart';
import '../voice/nlu/intent_router.dart';
import '../voice/nlu/nbest.dart';
import '../voice/nlu/search_parser.dart';
import '../widgets/voice_sheet.dart';
import 'add_asset_screen.dart';
import 'add_farmer_screen.dart';
import 'briefing_screen.dart';
import 'detail_screens.dart';
import 'nav_controller.dart';
import 'raise_alert_screen.dart';

/// The home / search-bar mic: one utterance is routed to the right agent.
class VoiceRouter {
  static SearchParser searchParser() {
    final store = AppStore.instance;
    return SearchParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);
  }

  /// Opens the voice sheet, then routes. [defaultEntity] is the list the mic
  /// sits on (Farmers / Assets / Tasks), used when the utterance is a search.
  static Future<void> listenAndRoute(BuildContext context,
      {SearchEntity? defaultEntity, String exampleKey = 'home'}) async {
    final text = await showVoiceSheet(
      context,
      title: 'Talk to Cropin',
      subtitle: switch (defaultEntity) {
        SearchEntity.farmers => 'Find or open a farmer, add a farmer — or ask anything',
        SearchEntity.assets => 'Find, add or assign plots, raise alerts — or ask anything',
        SearchEntity.tasks => "Ask what's due, overdue or done — or anything else",
        null => 'Tasks · farmers · plots · add · assign · raise alerts',
      },
    );
    if (text == null || !context.mounted) return;
    await route(context, text, defaultEntity: defaultEntity);
  }

  static Future<void> route(BuildContext context, String spoken, {SearchEntity? defaultEntity}) async {
    final store = AppStore.instance;
    final strings = AgentStrings(store.language);
    final (text, intent) = NBest.intent(SpeechService.instance.hypothesesFor(spoken));
    final nav = Navigator.of(context);

    switch (intent) {
      case AgentIntent.addFarmer:
        await nav.push(MaterialPageRoute(builder: (_) => AddFarmerScreen(initialUtterance: text)));
      case AgentIntent.addAsset:
        await nav.push(MaterialPageRoute(builder: (_) => AddAssetScreen(initialUtterance: text)));
      case AgentIntent.raiseAlert:
        await nav.push(MaterialPageRoute(builder: (_) => RaiseAlertScreen(initialUtterance: text)));
      case AgentIntent.assignPlot:
        await _assign(context, text);
      case AgentIntent.briefing:
        if (defaultEntity == SearchEntity.tasks) {
          _search(context, text, defaultEntity);
        } else {
          await nav.push(MaterialPageRoute(builder: (_) => const BriefingScreen(autoSpeak: true)));
        }
      case AgentIntent.search:
        _search(context, text, defaultEntity);
      case AgentIntent.unknown:
        if (defaultEntity != null) {
          _search(context, text, defaultEntity);
        } else {
          TtsService.instance.speak(strings.notUnderstood, store.language);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Heard "$text" — try e.g. "show my potato plots", '
                '"add farmer …", "raise pest alert on …", "what is pending today".'),
          ));
        }
    }
  }

  static void _search(BuildContext context, String text, SearchEntity? defaultEntity) {
    final store = AppStore.instance;
    final parser = searchParser();
    final (_, q) = NBest.pick(SpeechService.instance.hypothesesFor(text),
        (h) => parser.parse(h, defaultEntity: defaultEntity), NBest.searchScore);
    q.entity ??= defaultEntity ?? SearchEntity.assets;
    final nav = Navigator.of(context);
    NavController.instance.applySearch(q);
    final plotFilters = q.code != null || q.crop != null || q.area != null || q.location != null;

    // "Open farmer Mahesh Hegde" / "Mahesh Hegde" -> straight to the profile.
    if (q.farmerId != null && (q.entity == SearchEntity.farmers || !plotFilters) &&
        q.entity != SearchEntity.tasks) {
      nav.push(MaterialPageRoute(builder: (_) => FarmerDetailScreen(farmerId: q.farmerId!)));
      return;
    }
    final n = switch (q.entity!) {
      SearchEntity.farmers => store.searchFarmers(q, '').length,
      SearchEntity.assets => store.searchAssets(q, '').length,
      SearchEntity.tasks => store.searchTasks(q, '').length,
    };
    // A single matching plot opens directly ("open plot MH01 CA-1").
    if (q.entity == SearchEntity.assets && n == 1) {
      final a = store.searchAssets(q, '').first;
      nav.push(MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: a.id)));
    }
    TtsService.instance.speak(AgentStrings(store.language).searchResults(n), store.language);
  }

  /// "Assign plot CA-1 of Mahesh to Sunita Devi" -> confirmation sheet.
  static Future<void> _assign(BuildContext context, String text) async {
    final store = AppStore.instance;
    final parser = AssignParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);
    final (_, r) = NBest.pick(
        SpeechService.instance.hypothesesFor(text), parser.parse, (AssignParseResult r) => r.score);
    var plots = <String>[];
    if (r.code != null || r.crop != null || r.location != null || r.fromFarmerId != null) {
      plots = store.assets
          .where((a) =>
              (r.code == null ||
                  a.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').contains(r.code!)) &&
              (r.crop == null || a.crop == r.crop) &&
              (r.location == null || AppStore.inPlace(a.locality, r.location!)) &&
              (r.fromFarmerId == null || a.farmerId == r.fromFarmerId) &&
              a.farmerId != r.toFarmerId)
          .map((a) => a.id)
          .toList();
    }
    final ok = await showAssignSheet(context, plotIds: plots, farmerId: r.toFarmerId, heard: text);
    if (ok == true && context.mounted) {
      TtsService.instance.speak(AgentStrings(store.language).saved, store.language);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Plot assignment saved')));
    }
  }
}

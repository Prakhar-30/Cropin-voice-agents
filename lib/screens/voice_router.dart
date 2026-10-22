import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../services/tts_service.dart';
import '../voice/agent_strings.dart';
import '../voice/nlu/intent_router.dart';
import '../voice/nlu/search_parser.dart';
import '../widgets/voice_sheet.dart';
import 'add_asset_screen.dart';
import 'add_farmer_screen.dart';
import 'briefing_screen.dart';
import 'nav_controller.dart';
import 'raise_alert_screen.dart';
import 'take_photos_screen.dart';

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
      exampleKey: exampleKey,
      title: defaultEntity == null ? 'Ask Cropin' : 'Voice search',
      subtitle: defaultEntity == null
          ? 'Add farmer · Add asset · Raise alert · Photos · Search · My day'
          : 'Say what you are looking for',
    );
    if (text == null || !context.mounted) return;
    await route(context, text, defaultEntity: defaultEntity);
  }

  static Future<void> route(BuildContext context, String text, {SearchEntity? defaultEntity}) async {
    final store = AppStore.instance;
    final strings = AgentStrings(store.language);
    final intent = IntentRouter.detect(text);
    final nav = Navigator.of(context);

    switch (intent) {
      case AgentIntent.addFarmer:
        await nav.push(MaterialPageRoute(builder: (_) => AddFarmerScreen(initialUtterance: text)));
      case AgentIntent.addAsset:
        await nav.push(MaterialPageRoute(builder: (_) => AddAssetScreen(initialUtterance: text)));
      case AgentIntent.raiseAlert:
        await nav.push(MaterialPageRoute(builder: (_) => RaiseAlertScreen(initialUtterance: text)));
      case AgentIntent.takePhoto:
        await nav.push(MaterialPageRoute(builder: (_) => const TakePhotosScreen()));
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
            content: Text('Not sure what to do with "$text". Try one of the examples.'),
          ));
        }
    }
  }

  static void _search(BuildContext context, String text, SearchEntity? defaultEntity) {
    final store = AppStore.instance;
    final q = searchParser().parse(text, defaultEntity: defaultEntity);
    q.entity ??= defaultEntity ?? SearchEntity.assets;
    NavController.instance.applySearch(q);
    final n = switch (q.entity!) {
      SearchEntity.farmers => store.searchFarmers(q, '').length,
      SearchEntity.assets => store.searchAssets(q, '').length,
      SearchEntity.tasks => store.searchTasks(q, '').length,
    };
    TtsService.instance.speak(AgentStrings(store.language).searchResults(n), store.language);
  }
}

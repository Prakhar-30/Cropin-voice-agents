import 'package:flutter/foundation.dart';

import '../voice/nlu/search_parser.dart';

/// Bottom-navigation state plus the active voice filters per list.
class NavController extends ChangeNotifier {
  NavController._();
  static final NavController instance = NavController._();

  static const home = 0, farmers = 1, assets = 2, tasks = 3, reports = 4;

  int tab = home;
  final Map<SearchEntity, SearchQuery> queries = {};

  void goTo(int index) {
    tab = index;
    notifyListeners();
  }

  static int tabFor(SearchEntity e) => switch (e) {
        SearchEntity.farmers => farmers,
        SearchEntity.assets => assets,
        SearchEntity.tasks => tasks,
      };

  void applySearch(SearchQuery q) {
    final e = q.entity ?? SearchEntity.assets;
    q.entity = e;
    queries[e] = q;
    tab = tabFor(e);
    notifyListeners();
  }

  void clear(SearchEntity e) {
    queries.remove(e);
    notifyListeners();
  }
}

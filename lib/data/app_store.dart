import 'package:flutter/foundation.dart';

import '../services/location_service.dart';
import '../voice/agent_language.dart';
import '../voice/nlu/search_parser.dart';
import '../voice/nlu/slots.dart';
import 'demo_data.dart';
import 'models.dart';

/// In-memory, offline-first app state seeded with demo data.
class AppStore extends ChangeNotifier {
  AppStore._() {
    farmers = DemoData.farmers();
    assets = DemoData.assets();
    tasks = DemoData.tasks(assets);
    alerts = DemoData.alerts();
  }
  static final AppStore instance = AppStore._();

  late List<Farmer> farmers;
  late List<Asset> assets;
  late List<FieldTask> tasks;
  late List<FieldAlert> alerts;
  final List<PhotoRecord> photos = [];
  List<Project> get projects => DemoData.projects;

  AgentLanguage _language = AgentLanguage.english;
  AgentLanguage get language => _language;
  set language(AgentLanguage l) {
    _language = l;
    notifyListeners();
  }

  // ------------------------------------------------------------- lookups
  Farmer? farmer(String? id) => _firstOrNull(farmers, (f) => f.id == id);
  Asset? asset(String? id) => _firstOrNull(assets, (a) => a.id == id);
  Project? project(String? id) => _firstOrNull(projects, (p) => p.id == id);

  static T? _firstOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final i in items) {
      if (test(i)) return i;
    }
    return null;
  }

  List<Asset> assetsOf(String farmerId) => assets.where((a) => a.farmerId == farmerId).toList();

  int get goodCount => assets.where((a) => a.health == 'good').length;
  int get attentionCount => assets.where((a) => a.health == 'attention').length;

  // ------------------------------------------------------------- NLU refs
  List<EntityRef> get farmerRefs => [for (final f in farmers) EntityRef(f.id, f.name)];
  List<ProjectRef> get projectRefs =>
      [for (final p in projects) ProjectRef(p.id, p.name, crop: p.crop, season: p.season)];

  // ------------------------------------------------------------- mutations
  Farmer addFarmer({
    required String name,
    required String code,
    required String phone,
    required String projectId,
    bool byVoice = false,
  }) {
    final f = Farmer(
      id: 'f${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      code: code,
      phone: phone,
      address: DemoData.localities['BTM Layout']!.$1,
      locality: 'BTM Layout',
      projectIds: [projectId],
      createdByVoice: byVoice,
    );
    farmers.insert(0, f);
    notifyListeners();
    return f;
  }

  Asset addAsset({
    required String name,
    required String farmerId,
    required String projectId,
    required String soil,
    required String irrigation,
    required double area,
    required String unit,
    String? crop,
    GeoPoint? location,
    bool byVoice = false,
  }) {
    final f = farmer(farmerId)!;
    final p = project(projectId)!;
    final a = Asset(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      farmerId: farmerId,
      projectId: projectId,
      crop: crop ?? p.crop,
      variety: p.name,
      subVariety: '',
      address: f.address,
      locality: f.locality,
      area: area,
      unit: unit,
      soil: soil,
      irrigation: irrigation,
      location: location ?? LocationService.demoPoint,
      createdByVoice: byVoice,
    );
    assets.insert(0, a);
    if (!f.projectIds.contains(projectId)) f.projectIds.add(projectId);
    notifyListeners();
    return a;
  }

  FieldAlert raiseAlert({
    required List<String> assetIds,
    required String type,
    required String severity,
    required String note,
    bool byVoice = false,
  }) {
    final al = FieldAlert(
      id: 'al${DateTime.now().microsecondsSinceEpoch}',
      assetIds: assetIds,
      type: type,
      severity: severity,
      note: note,
      createdAt: DateTime.now(),
      byVoice: byVoice,
      language: language.code,
    );
    alerts.insert(0, al);
    for (final id in assetIds) {
      if (severity != 'Low') asset(id)?.health = 'attention';
    }
    notifyListeners();
    return al;
  }

  void addPhotos(List<PhotoRecord> list) {
    photos.insertAll(0, list);
    notifyListeners();
  }

  void touch() => notifyListeners();

  // ------------------------------------------------------------- search
  /// True when [locality] is [place] or lies inside it (city / state).
  static bool inPlace(String locality, String place) =>
      locality == place || (DemoData.localityGroups[place]?.contains(locality) ?? false);

  /// Plot codes compare without separators: "ca 1" matches "mh01/CA-1".
  static String _compact(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<Asset> searchAssets(SearchQuery? q, String text) {
    var list = assets.where((a) => _textMatch(text, [
          a.name, a.crop, a.variety, a.locality, a.address, farmer(a.farmerId)?.name ?? '',
        ]));
    if (q != null) {
      if (q.crop != null) list = list.where((a) => a.crop == q.crop);
      if (q.location != null) list = list.where((a) => inPlace(a.locality, q.location!));
      if (q.code != null) list = list.where((a) => _compact(a.name).contains(q.code!));
      if (q.health != null) list = list.where((a) => a.health == q.health);
      if (q.farmerId != null) list = list.where((a) => a.farmerId == q.farmerId);
      if (q.area != null) {
        final target = Asset.toAcres(q.area!, q.areaUnit ?? 'acre');
        list = list.where((a) => switch (q.comparator) {
              'gt' => a.areaInAcres > target + 0.001,
              'lt' => a.areaInAcres < target - 0.001,
              _ => (a.areaInAcres - target).abs() < 0.05,
            });
      }
    }
    return list.toList();
  }

  List<Farmer> searchFarmers(SearchQuery? q, String text) {
    var list = farmers.where((f) => _textMatch(text, [f.name, f.code, f.address, f.phone]));
    if (q != null) {
      if (q.location != null) list = list.where((f) => inPlace(f.locality, q.location!));
      if (q.farmerId != null) list = list.where((f) => f.id == q.farmerId);
      if (q.crop != null) {
        list = list.where((f) => assetsOf(f.id).any((a) => a.crop == q.crop));
      }
      if (q.health != null) {
        list = list.where((f) => assetsOf(f.id).any((a) => a.health == q.health));
      }
    }
    return list.toList();
  }

  List<FieldTask> searchTasks(SearchQuery? q, String text) {
    final now = DateTime.now();
    var list = tasks.where((t) => _textMatch(text, [
          t.type, asset(t.assetId)?.name ?? '', farmer(t.farmerId)?.name ?? '',
        ]));
    if (q != null) {
      if (q.taskStatus == 'overdue') list = list.where((t) => t.isOverdue(now));
      if (q.taskStatus == 'today') list = list.where((t) => t.isDueToday(now) || t.isOverdue(now));
      if (q.taskStatus == 'pending') list = list.where((t) => t.status == 'pending');
      if (q.taskStatus == 'completed') list = list.where((t) => t.status == 'completed');
      if (q.farmerId != null) list = list.where((t) => t.farmerId == q.farmerId);
      if (q.crop != null) list = list.where((t) => asset(t.assetId)?.crop == q.crop);
      if (q.location != null) {
        list = list.where((t) => inPlace(asset(t.assetId)?.locality ?? '', q.location!));
      }
    }
    final out = list.toList()..sort((a, b) => a.due.compareTo(b.due));
    return out;
  }

  static bool _textMatch(String text, List<String> fields) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return true;
    return fields.any((f) => f.toLowerCase().contains(t));
  }
}

import '../services/location_service.dart';

class Project {
  const Project(this.id, this.name, this.crop, this.season);
  final String id;
  final String name;
  final String crop;
  final String season;
}

class Farmer {
  Farmer({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.address,
    required this.locality,
    this.projectIds = const [],
    this.createdByVoice = false,
  });

  final String id;
  String name;
  String code;
  String phone;
  String address;
  String locality;
  List<String> projectIds;
  bool createdByVoice;
}

class Asset {
  Asset({
    required this.id,
    required this.name,
    required this.farmerId,
    required this.projectId,
    required this.crop,
    required this.variety,
    required this.subVariety,
    required this.address,
    required this.locality,
    required this.area,
    required this.unit,
    required this.soil,
    required this.irrigation,
    required this.location,
    this.health = 'good',
    this.status = 'current',
    this.createdByVoice = false,
  });

  final String id;
  String name;
  String farmerId;
  String projectId;
  String crop;
  String variety;
  String subVariety;
  String address;
  String locality;
  double area;
  String unit;
  String soil;
  String irrigation;
  GeoPoint location;

  /// 'good' | 'attention'
  String health;

  /// 'current' | 'upcoming'
  String status;
  bool createdByVoice;

  String get areaLabel =>
      '${area == area.roundToDouble() ? area.toInt() : area} $unit';

  /// Area converted to acres for filtering.
  double get areaInAcres => toAcres(area, unit);

  static double toAcres(double area, String unit) => switch (unit) {
        'hectare' => area * 2.471,
        'gunta' => area / 40,
        'cent' => area / 100,
        'bigha' => area * 0.62,
        _ => area,
      };
}

class FieldTask {
  FieldTask({
    required this.id,
    required this.type,
    required this.assetId,
    required this.farmerId,
    required this.due,
    this.status = 'pending',
  });

  final String id;
  final String type;
  final String assetId;
  final String farmerId;
  final DateTime due;

  /// 'pending' | 'completed'
  String status;

  bool isOverdue(DateTime now) =>
      status == 'pending' && due.isBefore(DateTime(now.year, now.month, now.day));

  bool isDueToday(DateTime now) =>
      status == 'pending' &&
      due.year == now.year &&
      due.month == now.month &&
      due.day == now.day;
}

class FieldAlert {
  FieldAlert({
    required this.id,
    required this.assetIds,
    required this.type,
    required this.severity,
    required this.note,
    required this.createdAt,
    this.byVoice = false,
    this.language = 'en',
  });

  final String id;
  final List<String> assetIds;
  final String type;
  final String severity;
  final String note;
  final DateTime createdAt;
  final bool byVoice;
  final String language;
}

class PhotoRecord {
  PhotoRecord({
    required this.id,
    required this.path,
    required this.createdAt,
    this.assetId,
    this.note = '',
    this.tags = const [],
  });

  final String id;
  final String path;
  final DateTime createdAt;
  String? assetId;
  String note;
  List<String> tags;
}

class Advisory {
  const Advisory(this.kind, this.title, this.text);

  /// 'weather' | 'indices' | 'pest'
  final String kind;
  final String title;

  /// language code -> text
  final Map<String, String> text;
}

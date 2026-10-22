/// Value filled by the voice agent, with how sure it is and what was heard.
class Slot<T> {
  Slot(this.value, this.confidence, this.heard);
  final T value;
  final double confidence;
  final String heard;

  /// Low-confidence values are highlighted for the user to verify.
  bool get needsCheck => confidence < 0.9;

  @override
  String toString() => 'Slot($value, ${confidence.toStringAsFixed(2)}, "$heard")';
}

/// Minimal reference to an app entity, keeps the NLU independent of the UI models.
class EntityRef {
  const EntityRef(this.id, this.name, {this.aliases = const []});
  final String id;
  final String name;
  final List<String> aliases;
}

class ProjectRef extends EntityRef {
  const ProjectRef(super.id, super.name, {required this.crop, required this.season});
  final String crop;
  final String season;
}

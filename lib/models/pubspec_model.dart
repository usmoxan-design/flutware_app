import 'dart:convert';

class PubspecDependency {
  final String name;
  final String version;
  final bool isDevDependency;
  final String? description;

  const PubspecDependency({
    required this.name,
    required this.version,
    this.isDevDependency = false,
    this.description,
  });

  factory PubspecDependency.fromJson(Map<String, dynamic> json) {
    return PubspecDependency(
      name: json['name'] as String,
      version: json['version'] as String? ?? '^1.0.0',
      isDevDependency: json['isDevDependency'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'isDevDependency': isDevDependency,
    if (description != null) 'description': description,
  };

  PubspecDependency copyWith({
    String? name,
    String? version,
    bool? isDevDependency,
    String? description,
  }) {
    return PubspecDependency(
      name: name ?? this.name,
      version: version ?? this.version,
      isDevDependency: isDevDependency ?? this.isDevDependency,
      description: description ?? this.description,
    );
  }
}

class PubspecConfig {
  final String sdkVersion;
  final List<PubspecDependency> dependencies;
  final List<PubspecDependency> devDependencies;

  const PubspecConfig({
    this.sdkVersion = '^3.10.4',
    this.dependencies = const [],
    this.devDependencies = const [],
  });

  factory PubspecConfig.defaultConfig() {
    return PubspecConfig(
      sdkVersion: '^3.10.4',
      dependencies: const [
        PubspecDependency(name: 'flutter', version: 'sdk: flutter'),
        PubspecDependency(name: 'cupertino_icons', version: '^1.0.8'),
        PubspecDependency(name: 'flutter_riverpod', version: '^2.3.6'),
        PubspecDependency(name: 'hive', version: '^2.2.3'),
        PubspecDependency(name: 'hive_flutter', version: '^1.1.0'),
        PubspecDependency(name: 'google_fonts', version: '^8.0.1'),
        PubspecDependency(name: 'archive', version: '^3.3.7'),
        PubspecDependency(name: 'fluttertoast', version: '^8.2.2'),
        PubspecDependency(name: 'path_provider', version: '^2.1.1'),
        PubspecDependency(name: 'share_plus', version: '^7.1.0'),
        PubspecDependency(name: 'permission_handler', version: '^12.0.1'),
        PubspecDependency(name: 'flutter_blockly', version: '^1.6.0'),
      ],
      devDependencies: const [
        PubspecDependency(name: 'flutter_test', version: 'sdk: flutter', isDevDependency: true),
        PubspecDependency(name: 'hive_generator', version: '^2.0.1', isDevDependency: true),
        PubspecDependency(name: 'build_runner', version: '^2.4.6', isDevDependency: true),
        PubspecDependency(name: 'flutter_lints', version: '^6.0.0', isDevDependency: true),
      ],
    );
  }

  factory PubspecConfig.fromJson(Map<String, dynamic> json) {
    return PubspecConfig(
      sdkVersion: json['sdkVersion'] as String? ?? '^3.10.4',
      dependencies: (json['dependencies'] as List<dynamic>?)
          ?.map((e) => PubspecDependency.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      devDependencies: (json['devDependencies'] as List<dynamic>?)
          ?.map((e) => PubspecDependency.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'sdkVersion': sdkVersion,
    'dependencies': dependencies.map((e) => e.toJson()).toList(),
    'devDependencies': devDependencies.map((e) => e.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  factory PubspecConfig.decode(String json) {
    return PubspecConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  PubspecConfig copyWith({
    String? sdkVersion,
    List<PubspecDependency>? dependencies,
    List<PubspecDependency>? devDependencies,
  }) {
    return PubspecConfig(
      sdkVersion: sdkVersion ?? this.sdkVersion,
      dependencies: dependencies ?? this.dependencies,
      devDependencies: devDependencies ?? this.devDependencies,
    );
  }

  List<PubspecDependency> get allDependencies => [...dependencies, ...devDependencies];
}

// Popular packages for quick add
final List<PubspecDependency> popularPackages = [
  const PubspecDependency(name: 'http', version: '^1.1.0', description: 'HTTP requests'),
  const PubspecDependency(name: 'dio', version: '^5.3.0', description: 'Powerful HTTP client'),
  const PubspecDependency(name: 'shared_preferences', version: '^2.2.0', description: 'Local storage'),
  const PubspecDependency(name: 'flutter_bloc', version: '^8.1.0', description: 'State management'),
  const PubspecDependency(name: 'get_it', version: '^7.6.0', description: 'Service locator'),
  const PubspecDependency(name: 'go_router', version: '^11.0.0', description: 'Navigation'),
  const PubspecDependency(name: 'intl', version: '^0.18.0', description: 'Internationalization'),
  const PubspecDependency(name: 'url_launcher', version: '^6.1.0', description: 'Open URLs'),
  const PubspecDependency(name: 'image_picker', version: '^1.0.0', description: 'Pick images'),
  const PubspecDependency(name: 'firebase_core', version: '^2.15.0', description: 'Firebase core'),
  const PubspecDependency(name: 'cloud_firestore', version: '^4.8.0', description: 'Firestore DB'),
  const PubspecDependency(name: 'firebase_auth', version: '^4.7.0', description: 'Firebase auth'),
  const PubspecDependency(name: 'supabase_flutter', version: '^1.10.0', description: 'Supabase SDK'),
  const PubspecDependency(name: 'sqflite', version: '^2.3.0', description: 'SQLite database'),
  const PubspecDependency(name: 'isar', version: '^3.1.0', description: 'NoSQL database'),
  const PubspecDependency(name: 'animations', version: '^2.0.0', description: 'Material animations'),
  const PubspecDependency(name: 'flutter_svg', version: '^2.0.0', description: 'SVG support'),
  const PubspecDependency(name: 'cached_network_image', version: '^3.2.0', description: 'Image caching'),
  const PubspecDependency(name: 'shimmer', version: '^3.0.0', description: 'Shimmer effect'),
  const PubspecDependency(name: 'lottie', version: '^2.6.0', description: 'Lottie animations'),
];

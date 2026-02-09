import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_models.dart';

class ApkBuilder {
  static const String _templateFallback = 'assets/template.apk';
  static const Map<String, String> _abiTemplates = {
    'arm64-v8a': 'assets/template_arm64.apk',
    'armeabi-v7a': 'assets/template_armeabi_v7a.apk',
    'x86_64': 'assets/template_x86_64.apk',
  };
  static const String _projectJsonPath =
      'assets/flutter_assets/assets/project.json';

  static final List<String> logs = [];

  static void _log(String message) {
    logs.add(
      '[${DateTime.now().toString().split(' ').last.split('.').first}] $message',
    );
    debugPrint(message);
  }

  static Future<String?> buildApk(
    ProjectData project, {
    Function(String)? onProgress,
    String? templateAsset,
  }) async {
    logs.clear();
    _log('Build jarayoni boshlandi: ${project.appName}');
    try {
      if (onProgress != null) onProgress('Tayyorlanmoqda...');

      // Ruxsatlarni tekshirish
      if (!await _requestPermissions()) {
        _log('Ruxsat berilmadi!');
        if (onProgress != null)
          onProgress('Xatolik: Xotiraga yozishga ruxsat yo\'q');
        return null;
      }

      // 1. Template asset-ni ABI bo'yicha tanlash va vaqtinchalik faylga ko'chirish
      final String selectedTemplate =
          templateAsset ?? await getRecommendedTemplateAsset();
      _log('Template asset-ni nusxalash: $selectedTemplate');
      ByteData data;
      try {
        data = await rootBundle.load(selectedTemplate);
      } catch (_) {
        if (selectedTemplate != _templateFallback) {
          _log('Template topilmadi, fallback ishlatiladi: $_templateFallback');
          data = await rootBundle.load(_templateFallback);
        } else {
          rethrow;
        }
      }
      final list = data.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final templateTempFile = File('${tempDir.path}/template_source.apk');
      await templateTempFile.writeAsBytes(list);

      // 2. JSON kontentni tayyorlash
      if (onProgress != null) onProgress('Konfiguratsiya qilinmoqda...');
      final String jsonContent = jsonEncode(project.toJson());

      // 3. Saqlash joyini aniqlash (Download papkasi)
      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!targetDir.existsSync()) {
          targetDir = await getExternalStorageDirectory();
        }
      }
      targetDir ??= await getTemporaryDirectory();

      final String outPathSigned = '${targetDir.path}/${project.appName}.apk';

      if (onProgress != null) onProgress('Imzolanmoqda va Patch qilinmoqda...');
      _log('Native Signer (ZipFlinger) ishga tushirildi...');

      // 4. Native kodni chaqiramiz (Patch + Sign)
      final String? resultPath = await buildAndSignApk(
        templateTempFile.path,
        jsonContent,
        outPathSigned,
        appName: project.appName,
        packageName: project.packageName,
        versionCode: project.versionCode,
        versionName: project.versionName,
      );

      // Vaqtinchalik template faylni o'chiramiz
      if (await templateTempFile.exists()) await templateTempFile.delete();

      if (resultPath != null) {
        if (onProgress != null) onProgress('Tayyor!');
        _log('Build muvaffaqiyatli yakunlandi: $resultPath');
        return resultPath;
      } else {
        _log('Native jarayonda xatolik yuz berdi');
        throw Exception("Build xatoligi");
      }
    } catch (e) {
      _log('XATOLIK: $e');
      debugPrint('BUILD ERROR: $e');
      return null;
    }
  }

  static Future<String?> buildAndSignApk(
    String templatePath,
    String jsonContent,
    String outputPath, {
    required String appName,
    required String packageName,
    required String versionCode,
    required String versionName,
  }) async {
    const platform = MethodChannel('com.flutware.builder/installer');
    try {
      final String? result = await platform.invokeMethod('buildAndSignApk', {
        'templatePath': templatePath,
        'jsonContent': jsonContent,
        'outputPath': outputPath,
        'appName': appName,
        'packageName': packageName,
        'versionCode': versionCode,
        'versionName': versionName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Native Error: ${e.message}');
      return null;
    }
  }

  static Future<void> installApk(String path) async {
    const platform = MethodChannel('com.flutware.builder/installer');
    try {
      await platform.invokeMethod('installApk', {'path': path});
    } on PlatformException catch (e) {
      debugPrint('Install Error: ${e.message}');
    }
  }

  static Future<AbiInfo> getAbiInfo() async {
    final info = await _getAbiInfo();
    _log(
      'ABI info: supported=${info.supported} 64bit=${info.abis64} '
      '32bit=${info.abis32} is64=${info.is64Bit}',
    );
    return info;
  }

  static Future<String> getRecommendedTemplateAsset() async {
    if (!Platform.isAndroid) return _templateFallback;
    final abiInfo = await _getAbiInfo();
    final selected = chooseTemplateFor(abiInfo);
    _log(
      'ABI info: supported=${abiInfo.supported} 64bit=${abiInfo.abis64} '
      '32bit=${abiInfo.abis32} is64=${abiInfo.is64Bit}',
    );
    return selected;
  }

  static String chooseTemplateFor(AbiInfo abiInfo) {
    final supported = abiInfo.supported;
    final abis64 = abiInfo.abis64;
    final abis32 = abiInfo.abis32;
    final is64Bit = abiInfo.is64Bit;

    // 1) 64-bit tizim bo'lsa 64-bit template-ni afzal ko'ramiz
    if (is64Bit && abis64.isNotEmpty) {
      for (final abi in abis64) {
        final template = _abiTemplates[abi];
        if (template != null) return template;
      }
    }

    // 2) 32-bit tizim bo'lsa yoki 64-bit topilmasa, 32-bit template
    for (final abi in abis32.isNotEmpty ? abis32 : supported) {
      final template = _abiTemplates[abi];
      if (template != null) return template;
    }

    // 3) Fallback
    return _templateFallback;
  }

  static Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. Storage (Android 9 va pastroq uchun, va Android 10 legacy)
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) return true;

    // 2. Manage External Storage (Android 11+ uchun)
    var manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      manageStatus = await Permission.manageExternalStorage.request();
    }

    return manageStatus.isGranted;
  }

  static Future<AbiInfo> _getAbiInfo() async {
    const platform = MethodChannel('com.flutware.builder/installer');
    try {
      final Map<dynamic, dynamic>? result =
          await platform.invokeMethod('getAbiInfo');
      if (result == null) {
        return const AbiInfo();
      }
      return AbiInfo(
        supported: _toStringList(result['supported']),
        abis32: _toStringList(result['abis32']),
        abis64: _toStringList(result['abis64']),
        is64Bit: result['is64Bit'] == true,
      );
    } catch (_) {
      return const AbiInfo();
    }
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }
}

class AbiInfo {
  final List<String> supported;
  final List<String> abis32;
  final List<String> abis64;
  final bool is64Bit;

  const AbiInfo({
    this.supported = const [],
    this.abis32 = const [],
    this.abis64 = const [],
    this.is64Bit = false,
  });
}

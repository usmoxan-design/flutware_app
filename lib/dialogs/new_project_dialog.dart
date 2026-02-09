import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../providers/project_provider.dart';

class NewProjectDialog extends ConsumerStatefulWidget {
  const NewProjectDialog({super.key});

  @override
  ConsumerState<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends ConsumerState<NewProjectDialog> {
  final _formKey = GlobalKey<FormState>();

  final _appNameController = TextEditingController();
  final _packageNameController = TextEditingController(
    text: 'com.example.myapp',
  );
  // Project Name is often just the App Name but we can keep it separate if needed.
  // For now, let's treat App Name as the main one.
  final _versionCodeController = TextEditingController(text: '1');
  final _versionNameController = TextEditingController(text: '1.0');

  bool _showAdvanced = false;

  // Default colors
  Color _colorPrimary = const Color(0xFF2196F3);
  final Color _colorPrimaryDark = const Color(0xFF1976D2);
  Color _colorAccent = const Color(0xFFFF4081);

  // Predefined palette for selection
  final List<Color> _palette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.brown,
    Colors.blueGrey,
  ];

  @override
  void dispose() {
    _appNameController.dispose();
    _packageNameController.dispose();
    _versionCodeController.dispose();
    _versionNameController.dispose();
    super.dispose();
  }

  void _generatePackageName(String name) {
    // Only auto-generate if user hasn't heavily modified it (simple check)
    // or just generate on focus loss if empty.
    // Check if the current value is default or empty
    final isDefault = _packageNameController.text == 'com.example.myapp';
    final isEmpty = _packageNameController.text.isEmpty;

    // Only update if it's default, empty, or starts with 'com.example.' (assuming user hasn't fully customized it)
    if (isDefault ||
        isEmpty ||
        _packageNameController.text.startsWith('com.example.')) {
      final sanitized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (sanitized.isNotEmpty) {
        _packageNameController.text = 'com.example.$sanitized';
      } else {
        _packageNameController.text = 'com.example.myapp';
      }
    }
  }

  Widget _buildColorPicker(
    String label,
    Color current,
    ValueChanged<Color> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _palette.map((c) {
            final isSelected = c.value == current.value;
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 2)
                      : null,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _onCreate() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _appNameController.text.trim();
      final pkg = _packageNameController.text.trim();
      final vCode = _versionCodeController.text.trim();
      final vName = _versionNameController.text.trim();

      // Color to Hex String
      String colorToHex(Color c) {
        return '0xFF${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      }

      final cPrimary = colorToHex(_colorPrimary);
      final cPrimaryDark = colorToHex(_colorPrimaryDark);
      final cAccent = colorToHex(_colorAccent);

      // Check for duplicates
      final projects = ref.read(projectProvider);
      final exists = projects.any((p) => p.packageName == pkg);

      if (exists) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xatolik'),
            content: Text(
              '"$pkg" nomli package allaqachon mavjud. Iltimos, boshqa nom tanlang.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      ref
          .read(projectProvider.notifier)
          .addProject(
            appName: name,
            packageName: pkg,
            versionCode: vCode,
            versionName: vName,
            colorPrimary: cPrimary,
            colorPrimaryDark: cPrimaryDark,
            colorAccent: cAccent,
          );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Project', style: TextStyle(color: Colors.blue)),
      content: SizedBox(
        width: 400, // Fixed width for better look
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon and App Name
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        // TODO: Implement icon picker
                      },
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey,
                        child: Icon(
                          Icons.android,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _appNameController,
                            decoration: const InputDecoration(
                              labelText: 'Application name',
                              hintText: 'My Amazing App',
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Kiritish shart'
                                : null,
                            onChanged: _generatePackageName,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                    icon: Icon(
                      _showAdvanced ? Icons.expand_less : Icons.settings,
                    ),
                    label: const Text('Advanced Settings'),
                  ),
                ),
                if (_showAdvanced) ...[
                  const Divider(),
                  // Colors
                  Row(
                    children: [
                      Expanded(
                        child: _buildColorPicker(
                          'Primary',
                          _colorPrimary,
                          (c) => setState(() => _colorPrimary = c),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildColorPicker(
                          'Accent',
                          _colorAccent,
                          (c) => setState(() => _colorAccent = c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Package Name
                  TextFormField(
                    controller: _packageNameController,
                    decoration: const InputDecoration(
                      labelText: 'Package name',
                      hintText: 'com.company.project',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kiritish shart';
                      if (!RegExp(
                        r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$',
                      ).hasMatch(v)) {
                        return 'Noto\'g\'ri format (e.g., com.example.app)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Versions
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _versionCodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ver. Code',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Req' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _versionNameController,
                          decoration: const InputDecoration(
                            labelText: 'Ver. Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Req' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _onCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('CREATE APP'),
        ),
      ],
    );
  }
}

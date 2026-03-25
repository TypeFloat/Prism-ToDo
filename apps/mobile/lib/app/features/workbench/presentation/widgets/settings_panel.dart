import 'package:flutter/material.dart';

import '../../../../app_strings.dart';
import '../../../settings/domain/ai_settings.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onSave,
    required this.onTestConnection,
    required this.testing,
    this.lastTestResult,
  });

  final AISettings settings;
  final ValueChanged<AISettings> onChanged;
  final VoidCallback onSave;
  final VoidCallback onTestConnection;
  final bool testing;
  final String? lastTestResult;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _timeoutController;
  late AISettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
    _baseUrlController = TextEditingController(text: _draft.baseUrl);
    _apiKeyController = TextEditingController(text: _draft.apiKey);
    _modelController = TextEditingController(text: _draft.model);
    _temperatureController = TextEditingController(text: _draft.temperature);
    _timeoutController = TextEditingController(text: _draft.timeoutSeconds);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _temperatureController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.settingsTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(AppStrings.settingsSubtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _draft.themeMode,
              decoration: const InputDecoration(
                labelText: AppStrings.themeModeTitle,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'system', child: Text(AppStrings.themeModeSystem)),
                DropdownMenuItem(value: 'light', child: Text(AppStrings.themeModeLight)),
                DropdownMenuItem(value: 'dark', child: Text(AppStrings.themeModeDark)),
              ],
              onChanged: (value) {
                if (value == null) return;
                _update(_draft.copyWith(themeMode: value));
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.aiFeatureToggle),
              value: _draft.enabled,
              onChanged: (value) => _update(_draft.copyWith(enabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.aiAdvancedMode),
              value: _draft.advancedMode,
              onChanged: (value) => _update(_draft.copyWith(advancedMode: value)),
            ),
            const SizedBox(height: 12),
            _Field(label: AppStrings.aiBaseUrl, controller: _baseUrlController, onChanged: (value) => _update(_draft.copyWith(baseUrl: value))),
            if (_draft.advancedMode) ...[
              const SizedBox(height: 12),
              _Field(label: AppStrings.aiApiKey, controller: _apiKeyController, obscureText: true, onChanged: (value) => _update(_draft.copyWith(apiKey: value))),
              const SizedBox(height: 12),
              _Field(label: AppStrings.aiModel, controller: _modelController, onChanged: (value) => _update(_draft.copyWith(model: value))),
              const SizedBox(height: 12),
              _Field(label: AppStrings.aiTemperature, controller: _temperatureController, onChanged: (value) => _update(_draft.copyWith(temperature: value))),
              const SizedBox(height: 12),
              _Field(label: AppStrings.aiTimeout, controller: _timeoutController, onChanged: (value) => _update(_draft.copyWith(timeoutSeconds: value))),
            ],
            const SizedBox(height: 12),
            Text(AppStrings.aiEnvFallbackHint, style: Theme.of(context).textTheme.bodySmall),
            if (_draft.usingEnvBaseUrl || _draft.usingEnvApiKey) ...[
              const SizedBox(height: 8),
              Text(
                '当前生效来源：${_draft.usingEnvBaseUrl ? 'URL=环境变量 ' : 'URL=软件内 '} ${_draft.usingEnvApiKey ? 'Token=环境变量' : 'Token=软件内或空'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(onPressed: widget.onSave, icon: const Icon(Icons.save_outlined), label: const Text(AppStrings.saveSettings)),
                OutlinedButton.icon(
                  onPressed: widget.testing ? null : widget.onTestConnection,
                  icon: widget.testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check_outlined),
                  label: Text(widget.testing ? '请求中…' : AppStrings.testConnection),
                ),
              ],
            ),
            if (widget.lastTestResult != null) ...[
              const SizedBox(height: 16),
              SelectableText(widget.lastTestResult!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  void _update(AISettings next) {
    setState(() {
      _draft = next;
    });
    widget.onChanged(next);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

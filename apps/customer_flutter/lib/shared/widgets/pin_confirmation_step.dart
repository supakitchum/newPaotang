import 'package:flutter/material.dart';

class PinConfirmationStep extends StatelessWidget {
  const PinConfirmationStep({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.error,
    required this.saving,
    required this.biometricEnabled,
    required this.biometricLabel,
    required this.onBack,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    super.key,
  });

  final String title;
  final String subtitle;
  final String pin;
  final String error;
  final bool saving;
  final bool biometricEnabled;
  final String biometricLabel;
  final VoidCallback onBack;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: saving ? null : onBack,
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Text(
                '${'●' * pin.length}${'○' * (6 - pin.length)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (saving) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
              const SizedBox(height: 12),
              if (biometricEnabled) ...[
                OutlinedButton.icon(
                  onPressed: saving ? null : onBiometric,
                  icon: const Icon(Icons.face_retouching_natural),
                  label: Text(biometricLabel),
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 24),
              _PinKeypad(onDigit: onDigit, onBackspace: onBackspace),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final key in keys)
          if (key.isEmpty)
            const SizedBox.shrink()
          else
            TextButton(
              onPressed: key == 'back' ? onBackspace : () => onDigit(key),
              child: key == 'back'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(key, style: Theme.of(context).textTheme.titleLarge),
            ),
      ],
    );
  }
}

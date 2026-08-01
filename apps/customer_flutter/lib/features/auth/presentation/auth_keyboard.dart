import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> dismissAuthKeyboard(
  BuildContext context, {
  bool waitForAnimation = false,
  bool finishAutofillContext = false,
}) async {
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;

  FocusManager.instance.primaryFocus?.unfocus(
    disposition: UnfocusDisposition.scope,
  );
  FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
  if (finishAutofillContext && isIos) {
    TextInput.finishAutofillContext(shouldSave: false);
  }

  await _hideAuthTextInput();
  if (isIos) {
    // iOS may still be completing the editing action that triggered submit.
    // Hiding again on the next frame prevents that client from leaving a blank
    // keyboard surface attached while the next route creates its own client.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await _hideAuthTextInput();
  }

  if (!waitForAnimation || !isIos) return;

  // iOS dismisses the keyboard asynchronously. Waiting for the bottom inset to
  // settle prevents the next route from attaching a second text input client.
  for (var frame = 0; frame < 28; frame += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!context.mounted) return;
    if (MediaQuery.viewInsetsOf(context).bottom <= 0.5) return;
  }

  await _hideAuthTextInput();
}

Future<void> _hideAuthTextInput() async {
  try {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  } on MissingPluginException {
    // Widget tests and non-native targets may not install a text input plugin.
  } on PlatformException {
    // Clearing Flutter focus remains the safe fallback.
  }
}

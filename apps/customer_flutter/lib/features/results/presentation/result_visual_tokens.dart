import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const resultNuxtSurface = Color(0xFFFFFFFF);
const resultNuxtHistorySheet = Color(0xFFF7F7F7);
const resultNuxtSectionTitle = Color(0xFF15171C);
const resultNuxtMuted = Color(0xFF8A8F98);
const resultNuxtInk = Color(0xFF242833);
const resultNuxtStateText = Color(0xFF20385F);
const resultNuxtSmallNumber = Color(0xFF22262D);
const resultNuxtLink = Color(0xFF656A72);
const resultNuxtDivider = Color(0xFFEEF0F2);
const resultNuxtError = Color(0xFFD33B38);
const resultNuxtCardShadow = Color(0x14213755);
const resultNuxtHistoryCardShadow = Color(0x17242C3A);
const resultNuxtPayoutShadow = Color(0x1F182A48);
const resultNuxtUnofficialFill = Color(0xFFFFF8E6);
const resultNuxtUnofficialBorder = Color(0xFFFFE0A3);
const resultNuxtUnofficialText = Color(0xFF8B5C03);
const resultNuxtUnofficialIcon = Color(0xFFD48A00);

Color resultHeroPrimary(BuildContext context) {
  return Theme.of(context).colorScheme.primary;
}

Color resultHeroSecondary(BuildContext context) {
  return Theme.of(context).colorScheme.secondary;
}

Color resultOutlineBorder(BuildContext context) {
  return AppTheme.primaryOutlineBorder(
    Theme.of(context).colorScheme.primary,
  );
}

Color resultOutlineText(BuildContext context) {
  return AppTheme.primaryOutlineText(
    Theme.of(context).colorScheme.primary,
  );
}

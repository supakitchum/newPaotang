import 'package:flutter/material.dart';

class SiamblendReceiptLogo extends StatelessWidget {
  const SiamblendReceiptLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/siamblend_horizontal_logo.png',
      width: 210,
      height: 70,
      fit: BoxFit.contain,
      semanticLabel: 'Siamblend',
    );
  }
}

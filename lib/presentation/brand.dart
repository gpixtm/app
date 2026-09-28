import 'package:flutter/material.dart';

import 'localization.dart';

/// The shared outlined wordmark, exported from the editable brand masters.
class GpixLogo extends StatelessWidget {
  const GpixLogo({this.width = 174, super.key});

  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/generated/gpix-logo-on-light.png',
    width: width,
    height: width / 3,
    fit: BoxFit.contain,
    alignment: Alignment.centerLeft,
    semanticLabel: context.l10n.appTitle,
    filterQuality: FilterQuality.medium,
  );
}

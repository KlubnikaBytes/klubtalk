import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileScaffold;
  final Widget webScaffold;

  const ResponsiveLayout({
    super.key,
    required this.mobileScaffold,
    required this.webScaffold,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return mobileScaffold;
        } else {
          return webScaffold;
        }
      },
    );
  }
}

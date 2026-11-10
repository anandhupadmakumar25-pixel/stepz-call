import 'package:flutter/material.dart';
import 'app_background.dart';

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final String? backgroundImage;
  final Color? baseColor;
  final List<Color>? ambientGradients;
  final bool useGlowOrbs;

  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundImage,
    this.baseColor,
    this.ambientGradients,
    this.useGlowOrbs = true,
  });

  @override
  Widget build(BuildContext context) {
    final isStandaloneRoute = Navigator.canPop(context);
    return AppBackground(
      preset: AppBackgroundPreset.cleanEnterprise,
      animateBlobs: useGlowOrbs,
      backgroundImageAsset: backgroundImage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          top: isStandaloneRoute,
          bottom: isStandaloneRoute,
          child: body,
        ),
      ),
    );
  }
}

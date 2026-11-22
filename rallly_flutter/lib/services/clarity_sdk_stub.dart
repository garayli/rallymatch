import 'package:flutter/widgets.dart';

/// Web: Clarity has no web SDK here, so masking is a pass-through.
class ClarityMask extends StatelessWidget {
  const ClarityMask({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

bool clarityInitialize(BuildContext context, String projectId) => false;

bool clarityConsent(bool allowed) => false;

bool clarityPause() => false;

bool clarityResume() => false;

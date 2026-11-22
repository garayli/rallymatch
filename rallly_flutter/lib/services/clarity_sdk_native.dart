import 'package:clarity_flutter/clarity_flutter.dart' as sdk;
import 'package:flutter/widgets.dart';

export 'package:clarity_flutter/clarity_flutter.dart' show ClarityMask;

bool clarityInitialize(BuildContext context, String projectId) =>
    sdk.Clarity.initialize(context, sdk.ClarityConfig(projectId: projectId));

bool clarityConsent(bool allowed) => sdk.Clarity.consent(allowed, allowed);

bool clarityPause() => sdk.Clarity.pause();

bool clarityResume() => sdk.Clarity.resume();

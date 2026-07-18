import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/inspector.dart';

void main() => runApp(const FlutterObservationDevToolsExtension());

class FlutterObservationDevToolsExtension extends StatelessWidget {
  const FlutterObservationDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: ObservationInspector());
  }
}

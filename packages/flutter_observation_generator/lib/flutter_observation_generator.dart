import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/observable_generator.dart';
import 'src/observation_widget_generator.dart';

/// Builds observable models and lifecycle-aware observation widgets.
Builder observationBuilder(BuilderOptions options) => SharedPartBuilder([
  ObservableGenerator(),
  ObservationWidgetGenerator(),
], 'observation');

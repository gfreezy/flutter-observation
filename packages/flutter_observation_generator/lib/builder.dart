import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/observable_generator.dart';
import 'src/reactive_widget_generator.dart';

Builder observableBuilder(BuilderOptions options) => SharedPartBuilder([
  ObservableGenerator(),
  ObservationWidgetGenerator(),
], 'observable');

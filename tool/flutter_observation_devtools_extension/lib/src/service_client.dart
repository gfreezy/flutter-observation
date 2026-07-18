import 'service_client_base.dart';
import 'service_client_stub.dart'
    if (dart.library.js_interop) 'service_client_web.dart'
    as platform;

export 'service_client_base.dart';

ObservationServiceClient createVmObservationServiceClient() {
  return platform.createVmObservationServiceClient();
}

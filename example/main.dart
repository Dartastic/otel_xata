// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_xata/otel_xata.dart';

/// Traces Xata calls with OpenTelemetry.
///
/// `otel_xata` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Xata call in
/// [tracedXataQuery]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'xata-example');

  // Wraps a Xata query (SDK query/getMany/search) in a CLIENT span.
  final xataQueryId = await tracedXataQuery<String>(
    operation: 'create',
    tableName: 'orders',
    database: 'example',
    branch: 'example',
    region: 'us-east-1',
    invoke: () async {
      // Make the Xata call here, then report what it returned.
      const id = 'xata_8f3a2c';
      return const XataQueryResult(value: id, recordCount: 3);
    },
  );
  OTelLog.info('tracedXataQuery create returned $xataQueryId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutXataInstrumentationAsync.
  await runWithoutXataInstrumentationAsync(
    () => tracedXataQuery<String>(
      operation: 'create',
      tableName: 'orders',
      database: 'example',
      branch: 'example',
      region: 'us-east-1',
      invoke: () async {
        const id = 'xata_8f3a2c';
        return const XataQueryResult(value: id, recordCount: 3);
      },
    ),
  );

  await OTel.shutdown();
}

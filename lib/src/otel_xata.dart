// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_xata_suppression.dart';

const _tracerName = 'dartastic_otel_libs_xata';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedXataQuery` callback.
class XataQueryResult<T> {
  /// Creates a result.
  const XataQueryResult({required this.value, this.recordCount});

  /// The value returned to the caller.
  final T value;
  final int? recordCount;
}

/// Wraps a Xata query (SDK `query`/`getMany`/`search`) in a CLIENT
/// span. db.system is `postgresql` (Xata is Postgres-backed) plus
/// xata.* fields.
Future<T> tracedXataQuery<T>({
  required String operation,
  required String tableName,
  required Future<XataQueryResult<T>> Function() invoke,
  String? database,
  String? branch,
  String? region,
}) async {
  if (xataInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': 'postgresql',
    'db.operation': operation,
    'db.collection.name': tableName,
    'xata.table': tableName,
    'xata.driver': 'sdk',
  };
  if (database != null) m['xata.database'] = database;
  if (branch != null) m['xata.branch'] = branch;
  if (region != null) m['xata.region'] = region;

  final span = _tracer().startSpan(
    'xata $operation $tableName',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.recordCount != null) {
      span.addAttributes(OTelAPI.attributes([
        OTelAPI.attributeInt('xata.record_count', r.recordCount!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

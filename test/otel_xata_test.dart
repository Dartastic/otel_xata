// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_xata/otel_xata.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_xata-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('query records CLIENT span', () async {
    await tracedXataQuery<String>(
      operation: 'query',
      tableName: 'users',
      database: 'app',
      branch: 'main',
      region: 'us-east-1',
      invoke: () async => const XataQueryResult(
        value: 'rows',
        recordCount: 5,
      ),
    );
    final a = attrsOf(spans.findSpanByName('xata query users')!);
    expect(a['db.system'], 'postgresql');
    expect(a['db.operation'], 'query');
    expect(a['db.collection.name'], 'users');
    expect(a['xata.table'], 'users');
    expect(a['xata.database'], 'app');
    expect(a['xata.branch'], 'main');
    expect(a['xata.region'], 'us-east-1');
    expect(a['xata.record_count'], 5);
  });

  test('suppression skips spans', () async {
    await runWithoutXataInstrumentationAsync(() async {
      await tracedXataQuery<String>(
        operation: 'query',
        tableName: 'u',
        invoke: () async => const XataQueryResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('xata '), isEmpty);
  });
}

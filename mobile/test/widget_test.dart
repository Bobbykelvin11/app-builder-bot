import 'dart:io';

import 'package:appbuilder/src/api.dart';
import 'package:appbuilder/src/app.dart';
import 'package:appbuilder/src/local/model_catalog.dart';
import 'package:appbuilder/src/local/model_manager.dart';
import 'package:appbuilder/src/prompting.dart';
import 'package:appbuilder/src/storage.dart';
import 'package:appbuilder/src/templates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('endpoint trims trailing slashes', () {
    expect(
      GeneratorApi.endpoint('https://x.vercel.app///').toString(),
      'https://x.vercel.app/api/generate',
    );
  });

  test('stripCodeFences removes markdown fences and chatter', () {
    expect(
      stripCodeFences('Here:\n```dart\nvoid main() {}\n```\nDone'),
      'void main() {}\n',
    );
    expect(stripCodeFences('```\nvoid main() {}'), 'void main() {}\n');
    expect(stripCodeFences('void main() {}'), 'void main() {}\n');
  });

  test('catalog and templates are well formed', () {
    expect(modelById(kDefaultLocalModelId), isNotNull);
    for (final m in kLocalModels) {
      expect(m.url, startsWith('https://huggingface.co/'));
      expect(m.url, endsWith(m.fileName));
      expect(m.sizeBytes, greaterThan(100000000));
    }
    expect(kTemplates.length, greaterThanOrEqualTo(4));
    for (final t in kTemplates) {
      expect(t.code, contains('void main()'));
      expect(t.code, contains('runApp('));
    }
  });

  testWidgets('empty prompt shows validation error; on-device is default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final models = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('models');
      return ModelManager.openAt(dir);
    });
    await tester.pumpWidget(AppBuilderApp(store: store, models: models!));
    await tester.pumpAndSettle();
    expect(find.text('App Builder'), findsWidgets);
    expect(find.text('On-device model not downloaded'), findsOneWidget);
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the app you want first.'), findsOneWidget);
  });
}

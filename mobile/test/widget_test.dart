import 'package:appbuilder/src/api.dart';
import 'package:appbuilder/src/app.dart';
import 'package:appbuilder/src/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('endpoint trims trailing slashes', () {
    expect(
      GeneratorApi.endpoint('https://x.vercel.app///').toString(),
      'https://x.vercel.app/api/generate',
    );
  });

  testWidgets('empty prompt shows validation error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    await tester.pumpWidget(AppBuilderApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('App Builder'), findsWidgets);
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the app you want first.'), findsOneWidget);
  });
}

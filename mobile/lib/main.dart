import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  runApp(AppBuilderApp(store: store));
}

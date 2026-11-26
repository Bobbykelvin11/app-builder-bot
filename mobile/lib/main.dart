import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/local/model_manager.dart';
import 'src/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final models = await ModelManager.open();
  runApp(AppBuilderApp(store: store, models: models));
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AppBuilderClient());

class AppBuilderClient extends StatelessWidget {
  const AppBuilderClient({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'App Builder Bot',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const BuilderHome(),
      );
}

class BuilderHome extends StatefulWidget {
  const BuilderHome({super.key});
  @override
  State<BuilderHome> createState() => _BuilderHomeState();
}

class _BuilderHomeState extends State<BuilderHome> {
  final prompt = TextEditingController();

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('App Builder Bot')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Describe the app you want to generate.'),
            const SizedBox(height: 12),
            TextField(controller: prompt, minLines: 4, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'A habit tracker with reminders…')),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Connect the generator API'), content: const Text('The API client endpoint will be configured for your deployment in a future step.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))])), child: const Text('Generate')),
            const SizedBox(height: 10),
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: prompt.text)), icon: const Icon(Icons.copy), label: const Text('Copy prompt')),
          ]),
        ),
      );
}

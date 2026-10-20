import 'package:flutter/material.dart';
import 'package:prism_search/prism_search.dart';

/// Demo app for prism_search.
void main() => runApp(const DemoApp());

/// Root widget showing the adaptive search.
class DemoApp extends StatelessWidget {
  /// Creates the demo.
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const frameworks = [
      'Dart',
      'Flutter',
      'Firebase',
      'Riverpod',
      'React Native',
      'Kotlin Multiplatform',
    ];
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('prism_search demo')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: PrismSearch<String>(
            items: frameworks,
            itemLabel: (item) => item,
            onSelected: (item) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Picked: $item')),
            ),
          ),
        ),
      ),
    );
  }
}
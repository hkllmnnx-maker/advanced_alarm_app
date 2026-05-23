import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize the local data layer before the UI starts. If the
  // database fails to come up (e.g. corrupted box on disk) we still want
  // the app to launch in a degraded state instead of crashing on a black
  // screen.
  bool dataLayerReady = true;
  try {
    await AlarmDatabase.instance.init();
  } catch (e, s) {
    dataLayerReady = false;
    if (kDebugMode) {
      debugPrint('Data layer failed to initialize: $e\n$s');
    }
  }

  runApp(MyApp(dataLayerReady: dataLayerReady));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.dataLayerReady = true});

  final bool dataLayerReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _DataLayerStatusPage(dataLayerReady: dataLayerReady),
    );
  }
}

/// Temporary landing page shown until Agent-03 (UI) takes over.
///
/// It proves the data layer was wired correctly: when the database is
/// initialized we can call into [AlarmRepository] without crashing and
/// show the live alarm count via the reactive stream.
class _DataLayerStatusPage extends StatelessWidget {
  const _DataLayerStatusPage({required this.dataLayerReady});

  final bool dataLayerReady;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Alarm – Data Layer'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: dataLayerReady
                ? _ReadyView()
                : const _ErrorView(),
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AlarmRepository repository = AlarmRepository.fromDatabase();
    return StreamBuilder<List<Alarm>>(
      stream: repository.watchAll(),
      builder: (BuildContext context, AsyncSnapshot<List<Alarm>> snap) {
        final List<Alarm> alarms = snap.data ?? const <Alarm>[];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Data layer ready',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Stored alarms: ${alarms.length}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const Text(
              'UI will be implemented by the next agent.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.error_outline, color: Colors.red, size: 64),
        const SizedBox(height: 16),
        Text(
          'Storage unavailable',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'The local alarm database failed to initialize. '
          'The app will keep running, but alarms cannot be saved.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

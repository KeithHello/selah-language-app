import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_lazy_indexed_stack.dart';

class _PersistentCounter extends StatefulWidget {
  const _PersistentCounter({required this.onMount, super.key});

  final VoidCallback onMount;

  @override
  State<_PersistentCounter> createState() => _PersistentCounterState();
}

class _PersistentCounterState extends State<_PersistentCounter> {
  var _count = 0;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('counter'),
    onTap: () => setState(() => _count++),
    child: Text('Count $_count'),
  );
}

void main() {
  testWidgets('inactive visited children update only when selected', (
    tester,
  ) async {
    var firstBuilds = 0;
    var secondBuilds = 0;

    Widget host(int index, int revision) => Directionality(
      textDirection: TextDirection.ltr,
      child: SelahLazyIndexedStack(
        index: index,
        children: [
          Builder(
            key: const ValueKey('first'),
            builder: (context) {
              firstBuilds++;
              return Text('First $revision');
            },
          ),
          Builder(
            key: const ValueKey('second'),
            builder: (context) {
              secondBuilds++;
              return Text('Second $revision');
            },
          ),
        ],
      ),
    );

    await tester.pumpWidget(host(0, 0));
    expect(firstBuilds, 1);
    expect(secondBuilds, 0);

    await tester.pumpWidget(host(0, 1));
    expect(firstBuilds, 2);
    expect(secondBuilds, 0);

    await tester.pumpWidget(host(1, 2));
    expect(firstBuilds, 2);
    expect(secondBuilds, 1);

    await tester.pumpWidget(host(0, 3));
    expect(firstBuilds, 3);
    expect(secondBuilds, 1);
    expect(find.text('First 3'), findsOneWidget);
  });

  testWidgets('visited page State survives switching away and back', (
    tester,
  ) async {
    var mounts = 0;
    Widget host(int index) => Directionality(
      textDirection: TextDirection.ltr,
      child: SelahLazyIndexedStack(
        index: index,
        children: [
          _PersistentCounter(
            key: const ValueKey('counter-page'),
            onMount: () => mounts++,
          ),
          const Text('Other page'),
        ],
      ),
    );

    await tester.pumpWidget(host(0));
    await tester.tap(find.byKey(const ValueKey('counter')));
    await tester.pump();
    await tester.pumpWidget(host(1));
    await tester.pumpWidget(host(0));

    expect(mounts, 1);
    expect(find.text('Count 1'), findsOneWidget);
  });
}

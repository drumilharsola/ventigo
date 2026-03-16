import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VentigoApp()));
    await tester.pump();
    expect(find.byType(VentigoApp), findsOneWidget);
  });
}

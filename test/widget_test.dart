import 'package:flutter_test/flutter_test.dart';

import 'package:tese/src/ui/tese_app.dart';

void main() {
  testWidgets('Desktop shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TeseDesktopApp());
    await tester.pumpAndSettle();

    expect(find.text('Tese Desktop'), findsAtLeastNWidgets(1));
    expect(find.text('Areas'), findsOneWidget);
    expect(find.text('Dialogos Ativos'), findsOneWidget);
  });
}

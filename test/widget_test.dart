import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:closi_app/app.dart';

void main() {
  testWidgets('Closi app se inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const ClosiApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

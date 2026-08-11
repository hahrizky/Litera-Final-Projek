import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:litera2/global/provider/provider_bahasa.dart';
import 'package:litera2/global/provider/provider_tema.dart';
import 'package:litera2/main.dart';

void main() {
  testWidgets('Litera app builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const LiteraApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(LiteraApp), findsOneWidget);
  });
}

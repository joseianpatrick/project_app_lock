import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/shared/theme/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('loads the persisted theme preference', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode': 'dark',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = ThemeStore(preferences);

    expect(store.isDark, isTrue);
  });

  test('toggles and persists the theme preference', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = ThemeStore(preferences);

    await store.toggle();

    expect(store.isDark, isTrue);
    expect(preferences.getString('theme_mode'), 'dark');
  });
}

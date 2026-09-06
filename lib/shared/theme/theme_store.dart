import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_store.g.dart';

class ThemeStore = ThemeStoreBase with _$ThemeStore;

abstract class ThemeStoreBase with Store {
  ThemeStoreBase(SharedPreferences preferences)
    : _preferences = preferences,
      isDark = preferences.getString(_themeModeKey) == 'dark';

  static const String _themeModeKey = 'theme_mode';
  final SharedPreferences _preferences;

  @observable
  bool isDark;

  @action
  Future<void> toggle() async {
    isDark = !isDark;
    await _preferences.setString(_themeModeKey, isDark ? 'dark' : 'light');
  }
}

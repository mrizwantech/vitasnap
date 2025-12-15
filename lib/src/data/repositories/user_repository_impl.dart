import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  static const _kName = 'user_name';
  final SharedPreferences _prefs;
  UserRepositoryImpl(this._prefs);

  @override
  Future<String?> getUserName() async => _prefs.getString(_kName);

  @override
  Future<void> setUserName(String name) async => _prefs.setString(_kName, name);
}

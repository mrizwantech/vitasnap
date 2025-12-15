abstract class UserRepository {
  Future<String?> getUserName();
  Future<void> setUserName(String name);
}

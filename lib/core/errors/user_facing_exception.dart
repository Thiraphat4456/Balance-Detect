class UserFacingException implements Exception {
  const UserFacingException(this.message, {this.canOpenSettings = false});

  final String message;
  final bool canOpenSettings;

  @override
  String toString() => message;
}

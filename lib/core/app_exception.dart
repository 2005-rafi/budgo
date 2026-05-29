class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

class StorageException extends AppException {
  StorageException(super.message);
}

class ValidationException extends AppException {
  ValidationException(super.message);
}

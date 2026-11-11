/// Base exception for domain, storage, and validation errors across Budgo.
/// Carries optional structured metadata (`reason`, `guidance`, `code`) so the
/// UI can render clear explanations and recovery actions without exposing raw
/// technical details.
class AppException implements Exception {
  final String message;
  final String? reason;
  final String? guidance;
  final String? code;

  AppException(
    this.message, {
    this.reason,
    this.guidance,
    this.code,
  });

  @override
  String toString() => message;
}

class StorageException extends AppException {
  StorageException(
    super.message, {
    super.reason,
    super.guidance,
    super.code = 'STORAGE_ERROR',
  });
}

class ValidationException extends AppException {
  ValidationException(
    super.message, {
    super.reason,
    super.guidance,
    super.code = 'VALIDATION_ERROR',
  });
}

class InsufficientFundsException extends AppException {
  final int? availablePaise;
  final int? requestedPaise;
  final String? accountName;

  InsufficientFundsException(
    super.message, {
    this.availablePaise,
    this.requestedPaise,
    this.accountName,
    String? alternativeHint,
    super.reason,
    super.code = 'INSUFFICIENT_FUNDS',
  }) : super(guidance: alternativeHint);
}

class NotFoundException extends AppException {
  final String? entityType;

  NotFoundException(
    super.message, {
    this.entityType,
    super.reason,
    super.guidance,
    super.code = 'NOT_FOUND',
  });
}

class DuplicateEntityException extends AppException {
  final String? entityType;

  DuplicateEntityException(
    super.message, {
    this.entityType,
    super.reason,
    super.guidance,
    super.code = 'DUPLICATE_ENTITY',
  });
}

class LimitExceededException extends AppException {
  final int? maxLimit;

  LimitExceededException(
    super.message, {
    this.maxLimit,
    super.reason,
    super.guidance,
    super.code = 'LIMIT_EXCEEDED',
  });
}

class PermissionException extends AppException {
  PermissionException(
    super.message, {
    super.reason,
    super.guidance,
    super.code = 'PERMISSION_DENIED',
  });
}

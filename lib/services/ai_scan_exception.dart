class AIScanException implements Exception {
  final String userMessage;

  AIScanException(this.userMessage);

  @override
  String toString() => userMessage;
}

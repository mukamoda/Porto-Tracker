/// Exceção base da aplicação, sempre com mensagem amigável ao usuário.
class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Lançada quando o perfil do usuário não permite a operação.
class PermissionException extends AppException {
  const PermissionException(
      [super.message = 'Seu perfil não tem permissão para esta operação.']);
}

/// Lançada quando uma regra de negócio é violada (ex.: sequência de status).
class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message);
}

/// Converte qualquer erro em uma mensagem exibível.
String mensagemDeErro(Object erro) {
  if (erro is AppException) return erro.message;
  return 'Ocorreu um erro inesperado. Tente novamente.';
}

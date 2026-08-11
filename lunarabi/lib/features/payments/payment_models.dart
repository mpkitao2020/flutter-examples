enum PaymentMethod { storeIap, gmoLink, aozoraTransfer }

enum PaymentStatus { idle, pending, success, failure }

class ProductRef {
  const ProductRef({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

class GmoLinkSession {
  const GmoLinkSession({required this.paymentId, required this.checkoutUrl});

  final String paymentId;
  final Uri checkoutUrl;
}

class AozoraTransferSession {
  const AozoraTransferSession({
    required this.paymentId,
    required this.accountDisplay,
    required this.expiresAt,
  });

  final String paymentId;
  final String accountDisplay;
  final DateTime expiresAt;
}

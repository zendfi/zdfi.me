/// Data models for the Zend! payment page.

class PageCustomisation {
  final String themeColor;
  final String backgroundColor;
  final String accentColor;
  final String? bio;
  final String? avatarUrl;
  final String linkStyle;
  final bool showRecentActivity;
  final String? displayNameOverride;

  const PageCustomisation({
    this.themeColor = '#2D6A4F',
    this.backgroundColor = '#FAFAF7',
    this.accentColor = '#52B788',
    this.bio,
    this.avatarUrl,
    this.linkStyle = 'card',
    this.showRecentActivity = false,
    this.displayNameOverride,
  });

  factory PageCustomisation.fromJson(Map<String, dynamic> json) {
    return PageCustomisation(
      themeColor: json['theme_color'] as String? ?? '#2D6A4F',
      backgroundColor: json['background_color'] as String? ?? '#FAFAF7',
      accentColor: json['accent_color'] as String? ?? '#52B788',
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      linkStyle: json['link_style'] as String? ?? 'card',
      showRecentActivity: json['show_recent_activity'] as bool? ?? false,
      displayNameOverride: json['display_name_override'] as String?,
    );
  }
}

class UserLinkData {
  final String zendtag;
  final String displayName;
  final String countryCode;
  final String provider;
  final String rail;
  final PageCustomisation customisation;

  const UserLinkData({
    required this.zendtag,
    required this.displayName,
    required this.countryCode,
    required this.provider,
    required this.rail,
    required this.customisation,
  });
}

class PaymentRequestData {
  final String id;
  final String requestLinkId;
  final double amountUsdc;
  final String? description;
  final String? expiresAt;
  final LocalPaymentOption? localPaymentOption;

  const PaymentRequestData({
    required this.id,
    required this.requestLinkId,
    required this.amountUsdc,
    this.description,
    this.expiresAt,
    this.localPaymentOption,
  });

  factory PaymentRequestData.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>;
    final localOpt = json['local_payment_option'] as Map<String, dynamic>?;
    return PaymentRequestData(
      id: request['id'] as String,
      requestLinkId: request['request_link_id'] as String,
      amountUsdc: (request['amount_usdc'] as num?)?.toDouble() ?? 0.0,
      description: request['description'] as String?,
      expiresAt: request['expires_at'] as String?,
      localPaymentOption: localOpt != null ? LocalPaymentOption.fromJson(localOpt) : null,
    );
  }
}

class LocalPaymentOption {
  final String countryCode;
  final String provider;
  final String rail;
  final String localCurrency;
  final double localAmount;
  final double fxRate;
  final Map<String, dynamic>? paymentDetails;

  const LocalPaymentOption({
    required this.countryCode,
    required this.provider,
    required this.rail,
    required this.localCurrency,
    required this.localAmount,
    required this.fxRate,
    this.paymentDetails,
  });

  factory LocalPaymentOption.fromJson(Map<String, dynamic> json) {
    return LocalPaymentOption(
      countryCode: json['country_code'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      rail: json['rail'] as String? ?? '',
      localCurrency: json['local_currency'] as String? ?? 'USD',
      localAmount: (json['local_amount'] as num?)?.toDouble() ?? 0.0,
      fxRate: (json['fx_rate'] as num?)?.toDouble() ?? 1.0,
      paymentDetails: json['payment_details'] as Map<String, dynamic>?,
    );
  }

  bool get isPaj => provider.toLowerCase() == 'paj';
  bool get isBridge => provider.toLowerCase() == 'bridge';
  bool get isComingSoon =>
      paymentDetails?['coming_soon'] == true;
  bool get isBlocked =>
      paymentDetails?['blocked'] == true;
  bool get needsKyc =>
      paymentDetails?['reason'] == 'bridge_kyc_required';
}

class CheckoutData {
  final String paymentId;
  final String merchantName;
  final double amountUsd;
  final String? description;
  final LocalPaymentOption? localPaymentOption;
  final bool onramp;

  const CheckoutData({
    required this.paymentId,
    required this.merchantName,
    required this.amountUsd,
    this.description,
    this.localPaymentOption,
    this.onramp = false,
  });

  factory CheckoutData.fromJson(Map<String, dynamic> json) {
    final localOpt = json['local_payment_option'] as Map<String, dynamic>?;
    return CheckoutData(
      paymentId: json['payment_id'] as String,
      merchantName: json['merchant_name'] as String? ?? '',
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      localPaymentOption: localOpt != null ? LocalPaymentOption.fromJson(localOpt) : null,
      onramp: json['onramp'] as bool? ?? false,
    );
  }
}

class OnrampOrder {
  final String orderId;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final double fiatAmount;
  final String? paymentId;

  const OnrampOrder({
    required this.orderId,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountName,
    required this.fiatAmount,
    this.paymentId,
  });

  factory OnrampOrder.fromJson(Map<String, dynamic> json) {
    return OnrampOrder(
      orderId: json['order_id'] as String,
      bankName: json['bank_name'] as String? ?? '',
      bankAccountNumber: json['bank_account_number'] as String? ?? '',
      bankAccountName: json['bank_account_name'] as String? ?? '',
      fiatAmount: (json['fiat_amount'] as num?)?.toDouble() ?? 0.0,
      paymentId: json['payment_id'] as String?,
    );
  }
}

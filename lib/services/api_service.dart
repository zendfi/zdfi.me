import 'package:dio/dio.dart';
import '../models/page_data.dart';

// API base URL — hardcoded since this is a public web app with a fixed backend.
// String.fromEnvironment is unreliable in Flutter web builds without explicit
// --dart-define flags, which Vercel doesn't pass by default.
const _kApiBase = 'https://api-v2.zendfi.tech';

class ZendPayApiService {
  final Dio _dio;

  ZendPayApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: _kApiBase,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ));

  // ── Public resolution ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserLinkData(String zendtag) async {
    final resp = await _dio.get('/api/v1/public/zend/$zendtag');
    return resp.data as Map<String, dynamic>;
  }

  Future<PageCustomisation> getCustomisation(String zendtag) async {
    try {
      final resp = await _dio.get('/api/v1/public/zend/$zendtag/customisation');
      return PageCustomisation.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return const PageCustomisation();
    }
  }

  Future<Map<String, dynamic>> getRequestData(
      String zendtag, String requestId) async {
    final resp = await _dio.get('/api/v1/public/zend/$zendtag/$requestId');
    return resp.data as Map<String, dynamic>;
  }

  Future<CheckoutData> createPaymentFromUserLink(
      String zendtag, double amountUsd) async {
    final resp = await _dio.post(
      '/api/v1/public/zend/$zendtag/pay',
      data: {'amount_usd': amountUsd},
    );
    return CheckoutData.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CheckoutData> createPaymentFromRequest(
      String zendtag, String requestId) async {
    final resp = await _dio.post('/api/v1/public/zend/$zendtag/$requestId/pay');
    return CheckoutData.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> prepareTransfer(
      String zendtag, String requestId,
      {String? countryCode}) async {
    final resp = await _dio.post(
      '/api/v1/public/zend/$zendtag/$requestId/prepare-transfer',
      data: {
        if (countryCode != null) 'country_code': countryCode,
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── PAJ onramp ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> onrampInitiate({
    required String email,
    required double fiatAmount,
    required String paymentLinkId,
    double? amountNgn,
  }) async {
    final resp = await _dio.post('/api/v1/onramp/initiate', data: {
      'customer_email': email,
      'fiat_amount': fiatAmount,
      'payment_link_id': paymentLinkId,
      if (amountNgn != null) 'amount_ngn': amountNgn,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<OnrampOrder> onrampCreateOrder({
    required String email,
    required String sessionId,
    required double fiatAmount,
    required String paymentLinkId,
    double? amountNgn,
  }) async {
    final resp = await _dio.post('/api/v1/onramp/create-order', data: {
      'customer_email': email,
      'session_id': sessionId,
      'fiat_amount': fiatAmount,
      'currency': 'USD',
      'payment_link_id': paymentLinkId,
      'payment_intent_id': null,
      'webhook_url': null,
      if (amountNgn != null) 'amount_ngn': amountNgn,
    });
    return OnrampOrder.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    final resp = await _dio.get('/api/v1/payments/$paymentId/status');
    return resp.data as Map<String, dynamic>;
  }

  // ── NGN payin (onramp) ─────────────────────────────────────────────────────

  /// Prepare a PAJ NGN onramp order for a zdfi.me payment page.
  /// No email required — backend handles PAJ session transparently.
  Future<Map<String, dynamic>> prepareNgnPayin({
    required String zendtag,
    required double amountUsd,
  }) async {
    final resp = await _dio.post(
      '/api/v1/public/zend/$zendtag/ngn-payin/prepare',
      data: {'amount_usd': amountUsd},
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Crypto deposit ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSupportedChains() async {
    final resp = await _dio.get('/api/v1/public/chains');
    return (resp.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getCryptoDepositAddress({
    required String zendtag,
    required int chainId,
  }) async {
    final resp = await _dio.get(
      '/api/v1/public/zend/$zendtag/crypto-deposit-address',
      queryParameters: {'chain_id': chainId},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Submit a payer's on-chain tx hash after sending funds for a one-time
  /// (non-stablecoin) deposit quote. Dextopus uses this to confirm receipt
  /// and trigger the bridge to USDC on Solana.
  Future<void> submitCryptoDepositTx({
    required String zendtag,
    required String depositId,
    required String txHash,
  }) async {
    await _dio.post(
      '/api/v1/public/zend/$zendtag/crypto-deposit/submit',
      data: {'deposit_id': depositId, 'tx_hash': txHash},
    );
  }
}

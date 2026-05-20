import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../models/page_data.dart';
import '../services/api_service.dart';
import '../utils/color_utils.dart';
import '../widgets/bridge_payment_details.dart';
import '../widgets/crypto_deposit_section.dart';
import '../widgets/paj_onramp_flow.dart';
import '../widgets/zendapp_banner.dart';

/// The main payment page — rendered for both PWYW and fixed-amount requests.
///
/// URL patterns:
///   /{zendtag}              — PWYW
///   /{zendtag}/{request_id} — fixed amount
class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.zendtag,
    this.requestId,
  });

  final String zendtag;
  final String? requestId;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _api = ZendPayApiService();

  // Page state
  bool _loading = true;
  String? _error;

  // Data
  PageCustomisation _customisation = const PageCustomisation();
  String _displayName = '';
  String _countryCode = '';
  String _provider = '';

  // For PWYW
  double _amountUsd = 10.0;
  final _amountController = TextEditingController(text: '10');

  // For fixed-amount request
  PaymentRequestData? _requestData;

  // Checkout state
  CheckoutData? _checkoutData;
  bool _creatingPayment = false;
  bool _paymentSuccess = false;
  bool _showCryptoSection = false;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final zendtag = widget.zendtag.replaceFirst('@', '');

    try {
      final customisation = await _api.getCustomisation(zendtag);

      final Map<String, dynamic> linkData;
      if (widget.requestId != null) {
        linkData = await _api.getRequestData(zendtag, widget.requestId!);
      } else {
        linkData = await _api.getUserLinkData(zendtag);
      }

      String displayName;
      String countryCode;
      String provider;

      if (widget.requestId != null) {
        final user = (linkData['user'] as Map<String, dynamic>?) ?? {};
        displayName = customisation.displayNameOverride
            ?? user['display_name'] as String? ?? zendtag;
        final localOpt = linkData['local_payment_option'] as Map<String, dynamic>?;
        countryCode = localOpt?['country_code'] as String? ?? '';
        provider = localOpt?['provider'] as String? ?? '';
        _requestData = PaymentRequestData.fromJson(linkData);
      } else {
        final user = (linkData['user'] as Map<String, dynamic>?) ?? {};
        displayName = customisation.displayNameOverride
            ?? user['display_name'] as String? ?? zendtag;
        final routing = (linkData['routing'] as Map<String, dynamic>?) ?? {};
        countryCode = routing['country_code'] as String? ?? '';
        provider = routing['provider'] as String? ?? '';
      }

      setState(() {
        _customisation = customisation;
        _displayName = displayName;
        _countryCode = countryCode;
        _provider = provider;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading page: $e';
        _loading = false;
      });
    }
  }

  Future<void> _startCheckout() async {
    setState(() {
      _creatingPayment = true;
      _error = null;
    });

    final zendtag = widget.zendtag.replaceFirst('@', '');

    try {
      CheckoutData data;
      if (widget.requestId != null) {
        data = await _api.createPaymentFromRequest(zendtag, widget.requestId!);
      } else {
        data = await _api.createPaymentFromUserLink(zendtag, _amountUsd);
      }
      setState(() {
        _checkoutData = data;
        _creatingPayment = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to start checkout. Please try again.';
        _creatingPayment = false;
      });
    }
  }

  Color get _themeColor =>
      hexToColor(_customisation.themeColor, fallback: ZendColors.accent);
  Color get _bgColor =>
      hexToColor(_customisation.backgroundColor, fallback: ZendColors.bgPrimary);
  Color get _accentColor =>
      hexToColor(_customisation.accentColor, fallback: ZendColors.accentBright);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: _loading
            ? _buildLoading()
            : _error != null && _checkoutData == null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _themeColor, strokeWidth: 2),
          const SizedBox(height: 12),
          const Text(
            'Loading...',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              color: ZendColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 40, color: ZendColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: ZendColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ZendApp smart banner (mobile only)
              ZendAppBanner(
                zendtag: widget.zendtag,
                requestId: widget.requestId,
                amountUsdc: _requestData?.amountUsdc ?? _amountUsd,
                description: _requestData?.description,
              ),

              // Profile header
              _buildProfileHeader(),
              const SizedBox(height: 10),

              // Payment card
              _buildPaymentCard(),

              const SizedBox(height: 16),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final style = _customisation.linkStyle;

    return switch (style) {
      'minimal' => _MinimalHeader(
          displayName: _displayName,
          zendtag: widget.zendtag,
          bio: _customisation.bio,
          themeColor: _themeColor,
          avatarUrl: _customisation.avatarUrl,
        ),
      'full' => _FullHeader(
          displayName: _displayName,
          zendtag: widget.zendtag,
          bio: _customisation.bio,
          themeColor: _themeColor,
          accentColor: _accentColor,
          avatarUrl: _customisation.avatarUrl,
        ),
      _ => _CardHeader(
          displayName: _displayName,
          zendtag: widget.zendtag,
          bio: _customisation.bio,
          themeColor: _themeColor,
          avatarUrl: _customisation.avatarUrl,
        ),
    };
  }

  // Flat card — no shadow, tight border, compact padding
  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZendRadii.xl),
        border: Border.all(color: ZendColors.border),
      ),
      child: _checkoutData != null
          ? _buildCheckoutFlow()
          : _buildPreCheckout(),
    );
  }

  Widget _buildPreCheckout() {
    final isRequest = widget.requestId != null;
    final amount = isRequest ? _requestData?.amountUsdc ?? 0.0 : _amountUsd;

    // When crypto section is active, replace the entire card content
    if (_showCryptoSection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back to payment options
          GestureDetector(
            onTap: () => setState(() => _showCryptoSection = false),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 16, color: _themeColor),
                const SizedBox(width: 6),
                Text(
                  'Back to payment options',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _themeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CryptoDepositSection(
            key: const ValueKey('crypto'),
            zendtag: widget.zendtag.replaceFirst('@', ''),
            themeColor: _themeColor,
            amountUsd: _requestData?.amountUsdc ?? _amountUsd,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount display
        if (isRequest) ...[
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: _themeColor,
            ),
          ),
          if (_requestData?.description != null) ...[
            const SizedBox(height: 2),
            Text(
              _requestData!.description!,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: ZendColors.textSecondary,
              ),
            ),
          ],
        ] else ...[
          // PWYW amount input
          const Text(
            'Enter amount',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ZendColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: _themeColor,
            ),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: _themeColor.withValues(alpha: 0.4),
              ),
              hintText: '0.00',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed > 0) {
                setState(() => _amountUsd = parsed);
              }
            },
          ),
        ],

        const SizedBox(height: 12),

        // Geo routing info
        if (_countryCode.isNotEmpty) ...[
          _GeoRoutingBadge(
            countryCode: _countryCode,
            provider: _provider,
            themeColor: _themeColor,
          ),
          const SizedBox(height: 12),
        ],

        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              color: ZendColors.destructive,
            ),
          ),
          const SizedBox(height: 10),
        ],

        ElevatedButton(
          onPressed: _creatingPayment || (isRequest ? false : _amountUsd <= 0)
              ? null
              : _startCheckout,
          style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
          child: _creatingPayment
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isRequest
                  ? 'Pay \$${amount.toStringAsFixed(2)}'
                  : 'Pay'),
        ),

        const SizedBox(height: 16),
        const Divider(color: ZendColors.border, height: 1),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _showCryptoSection = true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.currency_bitcoin_outlined,
                  size: 14, color: _themeColor),
              const SizedBox(width: 6),
              Text(
                'Send crypto instead?',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _themeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutFlow() {
    final checkout = _checkoutData!;
    final localOpt = checkout.localPaymentOption;

    if (_paymentSuccess) {
      return _buildSuccessState();
    }

    // PAJ onramp (NG)
    if (localOpt != null && localOpt.isPaj && !localOpt.isBlocked) {
      return PajOnrampFlow(
        zendtag: widget.zendtag.replaceFirst('@', ''),
        amountUsd: checkout.amountUsd,
        themeColor: _themeColor,
        onSuccess: () => setState(() => _paymentSuccess = true),
      );
    }

    // Bridge (US/UK/EU/MX/CO)
    if (localOpt != null && localOpt.isBridge && !localOpt.isBlocked) {
      return BridgePaymentDetails(
        localOption: localOpt,
        themeColor: _themeColor,
      );
    }

    // KYC required
    if (localOpt != null && localOpt.needsKyc) {
      return _buildKycRequired(localOpt);
    }

    return _buildComingSoon();
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: ZendColors.positive,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Payment confirmed!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your payment to @${widget.zendtag.replaceFirst('@', '')} has been received.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildKycRequired(LocalPaymentOption localOpt) {
    final kycLink = localOpt.paymentDetails?['kyc_link'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user_outlined,
            size: 36, color: ZendColors.textSecondary),
        const SizedBox(height: 10),
        const Text(
          'Identity verification required',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'This user needs to complete identity verification before receiving local payments.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: ZendColors.textSecondary,
          ),
        ),
        if (kycLink != null) ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () async {
              // Open KYC link — user will complete in browser
            },
            child: const Text('Complete verification'),
          ),
        ],
      ],
    );
  }

  Widget _buildComingSoon() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.public, size: 36, color: ZendColors.textSecondary),
        const SizedBox(height: 10),
        const Text(
          'Coming to your country soon',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Local payment rails are not yet available in your region. Check back soon.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: ZendColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Powered by ',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 11,
            color: ZendColors.textSecondary,
          ),
        ),
        Text(
          'Zend!',
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _themeColor,
          ),
        ),
        const Text(
          '',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 11,
            color: ZendColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Header variants ───────────────────────────────────────────────────────────

class _MinimalHeader extends StatelessWidget {
  const _MinimalHeader({
    required this.displayName,
    required this.zendtag,
    required this.bio,
    required this.themeColor,
    required this.avatarUrl,
  });

  final String displayName;
  final String zendtag;
  final String? bio;
  final Color themeColor;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(url: avatarUrl, name: displayName, color: themeColor, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ZendColors.textPrimary,
                ),
              ),
              Text(
                '@$zendtag',
                style: const TextStyle(
                  fontFamily: 'DMMono',
                  fontSize: 11,
                  color: ZendColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Flat card header — no shadow, border only
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.displayName,
    required this.zendtag,
    required this.bio,
    required this.themeColor,
    required this.avatarUrl,
  });

  final String displayName;
  final String zendtag;
  final String? bio;
  final Color themeColor;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZendRadii.xl),
        border: Border.all(color: ZendColors.border),
      ),
      child: Row(
        children: [
          _Avatar(url: avatarUrl, name: displayName, color: themeColor, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ZendColors.textPrimary,
                  ),
                ),
                Text(
                  'zdfi.me/$zendtag',
                  style: const TextStyle(
                    fontFamily: 'DMMono',
                    fontSize: 11,
                    color: ZendColors.textSecondary,
                  ),
                ),
                if (bio != null && bio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bio!,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: ZendColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Full gradient header — kept as-is (gradient is intentional identity element),
// just tightened padding and font sizes
class _FullHeader extends StatelessWidget {
  const _FullHeader({
    required this.displayName,
    required this.zendtag,
    required this.bio,
    required this.themeColor,
    required this.accentColor,
    required this.avatarUrl,
  });

  final String displayName;
  final String zendtag;
  final String? bio;
  final Color themeColor;
  final Color accentColor;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor, accentColor],
        ),
        borderRadius: BorderRadius.circular(ZendRadii.xl),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          _Avatar(
            url: avatarUrl,
            name: displayName,
            color: Colors.white.withValues(alpha: 0.25),
            radius: 26,
            textColor: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'zdfi.me/$zendtag',
                  style: const TextStyle(
                    fontFamily: 'DMMono',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                if (bio != null && bio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bio!,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.color,
    required this.radius,
    this.textColor,
  });

  final String? url;
  final String name;
  final Color color;
  final double radius;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url!),
        backgroundColor: color,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'Z',
        style: TextStyle(
          fontFamily: 'InstrumentSerif',
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: textColor ?? contrastColor(color),
        ),
      ),
    );
  }
}

class _GeoRoutingBadge extends StatelessWidget {
  const _GeoRoutingBadge({
    required this.countryCode,
    required this.provider,
    required this.themeColor,
  });

  final String countryCode;
  final String provider;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    final label = switch (provider.toLowerCase()) {
      'paj' => '🇳🇬 Bank transfer (NGN)',
      'bridge' => '🏦 Local bank transfer',
      _ => '🌍 $countryCode',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZendRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 13, color: themeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }
}

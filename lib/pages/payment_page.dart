import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../models/page_data.dart';
import '../services/api_service.dart';
import '../utils/color_utils.dart';
import '../widgets/bridge_payment_details.dart';
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

    // Strip any leading @ that may appear in old bookmarked/shared links
    // e.g. zdfi.me/@blessed → treats zendtag as "@blessed" without this strip
    final zendtag = widget.zendtag.replaceFirst('@', '');

    try {
      // Run both calls — customisation failure is non-fatal, link data failure is fatal
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
        // Null-safe cast — routing may be absent if user has no geo config yet
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
      // Show the real error so we can debug — revert to generic message after fixing
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
          CircularProgressIndicator(color: _themeColor),
          const SizedBox(height: 16),
          const Text(
            'Loading...',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
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
            const Icon(Icons.link_off, size: 48, color: ZendColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: ZendColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            const SizedBox(height: 24),

            // Payment card
            _buildPaymentCard(),

            const SizedBox(height: 32),

            // Footer
            _buildFooter(),
          ],
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

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZendRadii.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _checkoutData != null
          ? _buildCheckoutFlow()
          : _buildPreCheckout(),
    );
  }

  Widget _buildPreCheckout() {
    final isRequest = widget.requestId != null;
    final amount = isRequest
        ? _requestData?.amountUsdc ?? 0.0
        : _amountUsd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount display
        if (isRequest) ...[
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: _themeColor,
            ),
          ),
          if (_requestData?.description != null) ...[
            const SizedBox(height: 4),
            Text(
              _requestData!.description!,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ZendColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: _themeColor,
            ),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: _themeColor.withValues(alpha: 0.5),
              ),
              hintText: '0.00',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed > 0) {
                setState(() => _amountUsd = parsed);
              }
            },
          ),
        ],

        const SizedBox(height: 20),

        // Geo routing info
        if (_countryCode.isNotEmpty)
          _GeoRoutingBadge(
            countryCode: _countryCode,
            provider: _provider,
            themeColor: _themeColor,
          ),

        const SizedBox(height: 20),

        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              color: ZendColors.destructive,
            ),
          ),
          const SizedBox(height: 12),
        ],

        ElevatedButton(
          onPressed: _creatingPayment || (isRequest ? false : _amountUsd <= 0)
              ? null
              : _startCheckout,
          style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
          child: _creatingPayment
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Pay ${isRequest ? '\$${amount.toStringAsFixed(2)}' : ''}'),
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

    // PAJ onramp (NG) — new proxy-email flow, no user email required
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

    // Coming soon / fallback
    return _buildComingSoon();
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ZendColors.positive,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment confirmed!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your payment to @${widget.zendtag.replaceFirst('@', '')} has been received.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildKycRequired(LocalPaymentOption localOpt) {
    final kycLink = localOpt.paymentDetails?['kyc_link'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user_outlined,
            size: 40, color: ZendColors.textSecondary),
        const SizedBox(height: 12),
        const Text(
          'Identity verification required',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This user needs to complete identity verification before receiving local payments.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        if (kycLink != null) ...[
          const SizedBox(height: 16),
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
        const Icon(Icons.public, size: 40, color: ZendColors.textSecondary),
        const SizedBox(height: 12),
        const Text(
          'Coming to your country soon',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Local payment rails are not yet available in your region. Check back soon.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Powered by ',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 12,
                color: ZendColors.textSecondary,
              ),
            ),
            Text(
              'ZendFi',
              style: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _themeColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Secure · Global · Instant',
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
        _Avatar(url: avatarUrl, name: displayName, color: themeColor, radius: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ZendColors.textPrimary,
                ),
              ),
              Text(
                '@$zendtag',
                style: const TextStyle(
                  fontFamily: 'DMMono',
                  fontSize: 12,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZendRadii.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _Avatar(url: avatarUrl, name: displayName, color: themeColor, radius: 32),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ZendColors.textPrimary,
            ),
          ),
          Text(
            'zdfi.me/$zendtag',
            style: const TextStyle(
              fontFamily: 'DMMono',
              fontSize: 12,
              color: ZendColors.textSecondary,
            ),
          ),
          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: ZendColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(ZendRadii.xxl),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _Avatar(
            url: avatarUrl,
            name: displayName,
            color: Colors.white.withValues(alpha: 0.3),
            radius: 36,
            textColor: Colors.white,
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: const TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'zdfi.me/$zendtag',
            style: const TextStyle(
              fontFamily: 'DMMono',
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZendRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 14, color: themeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }
}

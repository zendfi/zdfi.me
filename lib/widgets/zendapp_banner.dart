import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/tokens.dart';

/// Smart banner shown on mobile web — detects if ZendApp might be installed
/// and offers to open the payment directly in the app.
///
/// Uses the custom URI scheme `zendapp://pay?zendtag=...&amount=...&request_id=...`
/// as a fallback when Android App Links don't auto-fire (e.g. in-app browsers).
class ZendAppBanner extends StatefulWidget {
  const ZendAppBanner({
    super.key,
    required this.zendtag,
    this.requestId,
    this.amountUsdc,
    this.description,
  });

  final String zendtag;
  final String? requestId;
  final double? amountUsdc;
  final String? description;

  @override
  State<ZendAppBanner> createState() => _ZendAppBannerState();
}

class _ZendAppBannerState extends State<ZendAppBanner> {
  bool _dismissed = false;

  bool get _isMobile {
    if (!kIsWeb) return false;
    // On web, check user agent via defaultTargetPlatform
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _openInApp() async {
    final params = <String, String>{
      'zendtag': widget.zendtag,
      if (widget.requestId != null) 'request_id': widget.requestId!,
      if (widget.amountUsdc != null)
        'amount': widget.amountUsdc!.toStringAsFixed(2),
      if (widget.description != null) 'note': widget.description!,
    };

    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final uri = Uri.parse('zendapp://pay?$query');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // App not installed — open Play Store (Android) or App Store (iOS)
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      final storeUri = Uri.parse(isIos
          ? 'https://apps.apple.com/app/zendapp/id0000000000' // TODO: replace with real App Store ID
          : 'https://play.google.com/store/apps/details?id=com.zendfi.zendapp');
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_isMobile) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZendColors.bgDeep,
        borderRadius: BorderRadius.circular(ZendRadii.xl),
      ),
      child: Row(
        children: [
          // App icon placeholder
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ZendColors.accentBright.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, color: ZendColors.accentBright, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open in ZendApp',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ZendColors.textOnDeep,
                  ),
                ),
                const Text(
                  'Pay instantly with your Zend wallet',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 11,
                    color: Color(0x99E8F4EC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openInApp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ZendColors.accentBright,
                borderRadius: BorderRadius.circular(ZendRadii.pill),
              ),
              child: const Text(
                'Open',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ZendColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(Icons.close, size: 16, color: Color(0x66E8F4EC)),
          ),
        ],
      ),
    );
  }
}

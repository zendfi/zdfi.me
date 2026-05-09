import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../models/page_data.dart';

/// Displays Bridge bank transfer details for US/UK/EU payments.
/// Shows only the source deposit instructions (what the payer needs to send)
/// and the payment rail — nothing else.
class BridgePaymentDetails extends StatefulWidget {
  const BridgePaymentDetails({
    super.key,
    required this.localOption,
    required this.themeColor,
  });

  final LocalPaymentOption localOption;
  final Color themeColor;

  @override
  State<BridgePaymentDetails> createState() => _BridgePaymentDetailsState();
}

class _BridgePaymentDetailsState extends State<BridgePaymentDetails> {
  String? _copiedKey;

  void _copy(String key, String value) {
    Clipboard.setData(ClipboardData(text: value));
    setState(() => _copiedKey = key);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.localOption.paymentDetails ?? {};
    final bridgeVa = details['bridge_virtual_account'] as Map<String, dynamic>?;

    // Extract source deposit instructions — check both direct and nested under 'raw'
    final rawPayload = bridgeVa?['raw'] as Map<String, dynamic>?;
    final sourceInstructions = (bridgeVa?['source_deposit_instructions']
        ?? rawPayload?['source_deposit_instructions'])
        as Map<String, dynamic>?;

    // Extract payment rail from destination
    final rawDestination = rawPayload?['destination'] as Map<String, dynamic>?;
    final destination = bridgeVa?['destination'] as Map<String, dynamic>?;
    final paymentRail = (rawDestination?['payment_rail']
        ?? destination?['payment_rail']
        ?? bridgeVa?['destination_payment_rail']
        ?? rawPayload?['source_deposit_instructions']?['payment_rail']
        ?? widget.localOption.rail) as String;
    final currency = (rawDestination?['currency']
        ?? destination?['currency']
        ?? bridgeVa?['destination_currency']
        ?? widget.localOption.localCurrency) as String;
    final amount = widget.localOption.localAmount;

    // Rail display label — only show payer-meaningful bank rail names.
    // The fallback sanitizes any crypto/internal rail names that should never
    // be shown to a payer (e.g. 'solana', 'base', 'usdc').
    final displayRail = (sourceInstructions?['payment_rail'] as String? ?? paymentRail).toLowerCase();
    final railLabel = switch (displayRail) {
      'ach' || 'ach_push' || 'ach_credit' => 'ACH (US Bank Transfer)',
      'wire' => 'Wire Transfer',
      'sepa' => 'SEPA (EU Bank Transfer)',
      'faster_payments' => 'Faster Payments (UK)',
      'spei' => 'SPEI (Mexico)',
      _ => _sanitizeRailLabel(displayRail),
    };

    if (sourceInstructions == null || sourceInstructions.isEmpty) {
      return _buildPendingState();
    }

    // Only show fiat currency codes — never expose crypto token names (USDC, USDT, etc.)
    // The source instructions currency is what the payer actually sends in their local currency.
    final rawCurrency = (sourceInstructions['currency'] as String? ?? currency).toUpperCase();
    final sourceCurrency = _sanitizeCurrency(rawCurrency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row — title + rail badge inline
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bank transfer details',
                    style: TextStyle(
                      fontFamily: 'InstrumentSerif',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ZendColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Send ${amount.toStringAsFixed(2)} $sourceCurrency via $railLabel',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: ZendColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZendRadii.pill),
              ),
              child: Text(
                railLabel,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.themeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Source deposit instructions card — flat
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZendColors.bgSecondary,
            borderRadius: BorderRadius.circular(ZendRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SEND PAYMENT TO',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ZendColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ..._buildInstructionRows(sourceInstructions),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Info note — flat tinted strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.themeColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(ZendRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: widget.themeColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Transfer exactly ${amount.toStringAsFixed(2)} $sourceCurrency. '
                  'Funds typically arrive within 1–2 business days.',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    color: widget.themeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInstructionRows(Map<String, dynamic> instructions) {
    const priorityKeys = [
      'bank_name',
      'bank_address',
      'routing_number',
      'account_number',
      'iban',
      'bic',
      'swift_code',
      'sort_code',
      'account_holder_name',
      'account_holder_address',
      'reference',
      'memo',
      'payment_reference',
    ];

    final rows = <Widget>[];
    final seen = <String>{};

    for (final key in priorityKeys) {
      if (instructions.containsKey(key)) {
        final value = instructions[key];
        if (value != null && value.toString().isNotEmpty) {
          rows.addAll(_buildRow(key, value.toString(), seen));
        }
      }
    }

    const skipKeys = {
      'id', 'created_at', 'updated_at', 'bridge_virtual_account_id',
      'bridge_customer_id', 'status', 'developer_fee_percent',
    };
    for (final entry in instructions.entries) {
      if (!seen.contains(entry.key) && !skipKeys.contains(entry.key)) {
        final value = entry.value;
        if (value != null && value.toString().isNotEmpty && value is! Map && value is! List) {
          rows.addAll(_buildRow(entry.key, value.toString(), seen));
        }
      }
    }

    return rows;
  }

  List<Widget> _buildRow(String key, String value, Set<String> seen) {
    seen.add(key);
    final label = _formatLabel(key);
    final isCopied = _copiedKey == key;

    return [
      if (seen.length > 1) const Divider(height: 16, color: ZendColors.border),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 11,
                    color: ZendColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'DMMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ZendColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copy(key, value),
            child: Icon(
              isCopied ? Icons.check_circle_outline : Icons.copy_outlined,
              size: 16,
              color: isCopied ? ZendColors.positive : ZendColors.textSecondary,
            ),
          ),
        ],
      ),
    ];
  }

  String _formatLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Returns a safe fiat currency code, or 'USD' as fallback.
  /// Prevents crypto token names (USDC, USDT, SOL, etc.) from surfacing to payers.
  static String _sanitizeCurrency(String raw) {
    const knownFiat = {
      'USD', 'EUR', 'GBP', 'MXN', 'COP', 'NGN', 'CAD', 'AUD',
      'CHF', 'JPY', 'BRL', 'ARS', 'CLP', 'PEN', 'CRC',
    };
    if (knownFiat.contains(raw)) return raw;
    // Anything not in the fiat allowlist (USDC, USDT, SOL, ETH, etc.) → USD
    return 'USD';
  }

  /// Returns a human-readable bank rail label, suppressing any crypto/internal
  /// rail names that should never be shown to a payer.
  static String _sanitizeRailLabel(String raw) {
    const cryptoRails = {
      'solana', 'sol', 'ethereum', 'eth', 'base', 'polygon', 'matic',
      'usdc', 'usdt', 'tron', 'trc20', 'erc20', 'spl',
    };
    if (cryptoRails.contains(raw)) return 'Bank Transfer';
    return raw.toUpperCase().replaceAll('_', ' ');
  }

  Widget _buildPendingState() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZendColors.bgSecondary,
        borderRadius: BorderRadius.circular(ZendRadii.lg),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Preparing transfer instructions...',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: ZendColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

    // Rail display label — use source instructions rail if available (e.g. ach_push → ACH)
    final displayRail = (sourceInstructions?['payment_rail'] as String? ?? paymentRail).toLowerCase();
    final railLabel = switch (displayRail) {
      'ach' || 'ach_push' || 'ach_credit' => 'ACH (US Bank Transfer)',
      'wire' => 'Wire Transfer',
      'sepa' => 'SEPA (EU Bank Transfer)',
      'faster_payments' => 'Faster Payments (UK)',
      'spei' => 'SPEI (Mexico)',
      _ => displayRail.toUpperCase().replaceAll('_', ' '),
    };

    if (sourceInstructions == null || sourceInstructions.isEmpty) {
      return _buildPendingState();
    }

    final sourceCurrency = (sourceInstructions['currency'] as String? ?? currency).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          'Bank transfer details',
          style: const TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Send ${amount.toStringAsFixed(2)} $sourceCurrency via $railLabel',
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // Payment rail badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZendRadii.pill),
              ),
              child: Text(
                railLabel,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.themeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Source deposit instructions card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZendColors.bgSecondary,
            borderRadius: BorderRadius.circular(ZendRadii.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send payment to',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ZendColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ..._buildInstructionRows(sourceInstructions),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Important note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.themeColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(ZendRadii.lg),
            border: Border.all(
              color: widget.themeColor.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: widget.themeColor),
              const SizedBox(width: 8),
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
    // Priority order for display — show the most important fields first
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

    // Show priority keys first
    for (final key in priorityKeys) {
      if (instructions.containsKey(key)) {
        final value = instructions[key];
        if (value != null && value.toString().isNotEmpty) {
          rows.addAll(_buildRow(key, value.toString(), seen));
        }
      }
    }

    // Show remaining keys (skip internal/technical fields)
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
      if (seen.length > 1) const Divider(height: 20, color: ZendColors.border),
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'DMMono',
                    fontSize: 14,
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
              size: 18,
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

  Widget _buildPendingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZendColors.bgSecondary,
        borderRadius: BorderRadius.circular(ZendRadii.xl),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Preparing transfer instructions...',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: ZendColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../models/page_data.dart';

/// Displays Bridge virtual account / bank transfer details for US/UK/EU/MX/CO.
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

    // Extract Bridge virtual account details
    final bridgeVa = details['bridge_virtual_account'] as Map<String, dynamic>?;
    final sourceDepositInstructions = bridgeVa?['source_deposit_instructions']
        ?? details['source_deposit_instructions'];
    final destination = bridgeVa?['destination'] as Map<String, dynamic>?;

    final rail = destination?['payment_rail']
        ?? widget.localOption.rail;
    final currency = destination?['currency']?.toString().toUpperCase()
        ?? widget.localOption.localCurrency;
    final address = destination?['address'] as String?;

    final instructionStatus = details['instruction_status'] as String?;
    final isCreated = instructionStatus == 'created';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZendRadii.pill),
              ),
              child: Text(
                widget.localOption.provider.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.themeColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ZendColors.bgSecondary,
                borderRadius: BorderRadius.circular(ZendRadii.pill),
              ),
              child: Text(
                rail.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ZendColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Bank transfer details',
          style: const TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Send ${widget.localOption.localAmount.toStringAsFixed(2)} $currency to complete payment',
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        if (!isCreated)
          _buildPendingState()
        else ...[
          // Amount + currency
          _DetailCard(children: [
            _DetailRow(
              label: 'Amount',
              value: '${widget.localOption.localAmount.toStringAsFixed(2)} $currency',
              copyKey: 'amount',
              copiedKey: _copiedKey,
              onCopy: () => _copy('amount',
                  widget.localOption.localAmount.toStringAsFixed(2)),
            ),
            const Divider(height: 16),
            _DetailRow(
              label: 'Rail',
              value: rail,
              copyKey: null,
              copiedKey: _copiedKey,
              onCopy: null,
            ),
            if (address != null) ...[
              const Divider(height: 16),
              _DetailRow(
                label: 'Account / Address',
                value: address,
                copyKey: 'address',
                copiedKey: _copiedKey,
                onCopy: () => _copy('address', address),
              ),
            ],
          ]),

          // Source deposit instructions (raw JSON prettified)
          if (sourceDepositInstructions != null) ...[
            const SizedBox(height: 12),
            _DetailCard(children: [
              const Text(
                'DEPOSIT INSTRUCTIONS',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: ZendColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _SourceInstructionsWidget(
                instructions: sourceDepositInstructions,
                copiedKey: _copiedKey,
                onCopy: _copy,
              ),
            ]),
          ],
        ],
      ],
    );
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZendColors.bgSecondary,
        borderRadius: BorderRadius.circular(ZendRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.copyKey,
    required this.copiedKey,
    required this.onCopy,
  });

  final String label;
  final String value;
  final String? copyKey;
  final String? copiedKey;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isCopied = copyKey != null && copiedKey == copyKey;
    return Row(
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
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Icon(
              isCopied ? Icons.check_circle_outline : Icons.copy_outlined,
              size: 18,
              color: isCopied ? ZendColors.positive : ZendColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _SourceInstructionsWidget extends StatelessWidget {
  const _SourceInstructionsWidget({
    required this.instructions,
    required this.copiedKey,
    required this.onCopy,
  });

  final dynamic instructions;
  final String? copiedKey;
  final void Function(String key, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    if (instructions is Map<String, dynamic>) {
      final map = instructions as Map<String, dynamic>;
      return Column(
        children: map.entries.map((e) {
          final val = e.value?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DetailRow(
              label: e.key,
              value: val,
              copyKey: e.key,
              copiedKey: copiedKey,
              onCopy: val.isNotEmpty ? () => onCopy(e.key, val) : null,
            ),
          );
        }).toList(),
      );
    }
    return Text(
      instructions.toString(),
      style: const TextStyle(
        fontFamily: 'DMMono',
        fontSize: 12,
        color: ZendColors.textSecondary,
      ),
    );
  }
}

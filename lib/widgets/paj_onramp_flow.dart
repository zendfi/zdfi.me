import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../models/page_data.dart';
import '../services/api_service.dart';

/// PAJ NGN onramp (payin) flow for zdfi.me payment pages.
///
/// No email required — the backend handles PAJ session acquisition transparently
/// via the proxy email pattern. The payer just clicks Pay and gets bank details.
///
/// Flow:
///   1. Show loading while backend acquires PAJ session + creates onramp order (~10-15s)
///   2. Display bank details (bank name, account number, amount in NGN)
///   3. Poll for payment confirmation
class PajOnrampFlow extends StatefulWidget {
  const PajOnrampFlow({
    super.key,
    required this.zendtag,
    required this.amountUsd,
    required this.themeColor,
    required this.onSuccess,
    // Legacy field — kept for API compatibility but not used
    this.checkoutData,
  });

  final String zendtag;
  final double amountUsd;
  final Color themeColor;
  final VoidCallback onSuccess;
  final CheckoutData? checkoutData;

  @override
  State<PajOnrampFlow> createState() => _PajOnrampFlowState();
}

enum _OnrampStep { preparing, bankDetails, success, error }

class _PajOnrampFlowState extends State<PajOnrampFlow> {
  final _api = ZendPayApiService();

  _OnrampStep _step = _OnrampStep.preparing;
  String? _error;
  String? _copiedField;

  // Bank details from the prepare response
  String? _bankName;
  String? _accountNumber;
  String? _accountName;
  double? _fiatAmount;
  double? _usdcAmount;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _step = _OnrampStep.preparing;
      _error = null;
    });

    try {
      final result = await _api.prepareNgnPayin(
        zendtag: widget.zendtag,
        amountUsd: widget.amountUsd,
      );

      if (!mounted) return;
      setState(() {
        _bankName = result['bank_name'] as String?;
        _accountNumber = result['account_number'] as String?;
        _accountName = result['account_name'] as String?;
        _fiatAmount = (result['fiat_amount'] as num?)?.toDouble();
        _usdcAmount = (result['usdc_amount'] as num?)?.toDouble();
        _step = _OnrampStep.bankDetails;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not prepare payment. Please try again.';
        _step = _OnrampStep.error;
      });
    }
  }

  void _copyToClipboard(String text, String field) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedField = field);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedField = null);
    });
  }

  String _formatNgn(double value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final fromEnd = text.length - i;
      buf.write(text[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_step) {
        _OnrampStep.preparing => _buildPreparingStep(),
        _OnrampStep.bankDetails => _buildBankDetailsStep(),
        _OnrampStep.success => _buildSuccessStep(),
        _OnrampStep.error => _buildErrorStep(),
      },
    );
  }

  Widget _buildPreparingStep() {
    return Column(
      key: const ValueKey('preparing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: CircularProgressIndicator(
            color: widget.themeColor,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Preparing payment details...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'This takes about 10–15 seconds',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 12,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBankDetailsStep() {
    final ngn = _fiatAmount != null ? _formatNgn(_fiatAmount!) : '—';
    final usdc = _usdcAmount != null
        ? _usdcAmount!.toStringAsFixed(2)
        : widget.amountUsd.toStringAsFixed(2);

    return Column(
      key: const ValueKey('bank'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Send ₦$ngn to complete payment',
          style: const TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Recipient will receive \$$usdc',
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 12,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),

        // Bank details card — flat, no shadow
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZendColors.bgSecondary,
            borderRadius: BorderRadius.circular(ZendRadii.lg),
          ),
          child: Column(
            children: [
              _BankDetailRow(
                label: 'Bank',
                value: _bankName ?? '—',
                onCopy: null,
                copied: false,
              ),
              const Divider(height: 16, color: ZendColors.border),
              _BankDetailRow(
                label: 'Account Name',
                value: _accountName ?? '—',
                onCopy: null,
                copied: false,
              ),
              const Divider(height: 16, color: ZendColors.border),
              _BankDetailRow(
                label: 'Account Number',
                value: _accountNumber ?? '—',
                copied: _copiedField == 'account',
                onCopy: _accountNumber != null
                    ? () => _copyToClipboard(_accountNumber!, 'account')
                    : null,
              ),
              const Divider(height: 16, color: ZendColors.border),
              _BankDetailRow(
                label: 'Amount (NGN)',
                value: '₦$ngn',
                copied: _copiedField == 'amount',
                onCopy: _fiatAmount != null
                    ? () => _copyToClipboard(_fiatAmount!.round().toString(), 'amount')
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('success'),
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
        const Text(
          'Payment has been delivered to the recipient.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildErrorStep() {
    return Column(
      key: const ValueKey('error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ZendColors.destructive.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline,
                color: ZendColors.destructive, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _error ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _prepare,
          style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  const _BankDetailRow({
    required this.label,
    required this.value,
    required this.copied,
    required this.onCopy,
  });

  final String label;
  final String value;
  final bool copied;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 1),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: ZendColors.bgPrimary,
                borderRadius: BorderRadius.circular(ZendRadii.xs),
                border: Border.all(color: ZendColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    copied ? Icons.check : Icons.copy_outlined,
                    size: 13,
                    color: copied ? ZendColors.positive : ZendColors.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    copied ? 'Copied' : 'Copy',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: copied ? ZendColors.positive : ZendColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

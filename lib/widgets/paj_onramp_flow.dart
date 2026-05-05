import 'dart:async';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../models/page_data.dart';
import '../services/api_service.dart';

/// PAJ onramp flow: email → (background OTP verification) → bank details → polling.
///
/// Mirrors the OnrampCheckout component from the Next.js checkout but in Flutter.
class PajOnrampFlow extends StatefulWidget {
  const PajOnrampFlow({
    super.key,
    required this.checkoutData,
    required this.themeColor,
    required this.onSuccess,
  });

  final CheckoutData checkoutData;
  final Color themeColor;
  final VoidCallback onSuccess;

  @override
  State<PajOnrampFlow> createState() => _PajOnrampFlowState();
}

enum _OnrampStep { email, processing, bankDetails, success }

class _PajOnrampFlowState extends State<PajOnrampFlow> {
  final _api = ZendPayApiService();
  final _emailController = TextEditingController();

  _OnrampStep _step = _OnrampStep.email;
  bool _loading = false;
  String? _error;
  String? _sessionId;
  OnrampOrder? _order;
  String? _copiedField;

  Timer? _pollTimer;
  Timer? _pollTimeout;
  int _pollAttempts = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _pollTimer?.cancel();
    _pollTimeout?.cancel();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _api.onrampInitiate(
        email: email,
        fiatAmount: widget.checkoutData.amountUsd,
        paymentLinkId: widget.checkoutData.paymentId,
      );
      final sessionId = resp['session_id'] as String;
      setState(() {
        _sessionId = sessionId;
        _step = _OnrampStep.processing;
        _loading = false;
      });
      _startBackgroundVerification(email, sessionId);
    } catch (e) {
      setState(() {
        _error = 'Failed to initiate payment. Please try again.';
        _loading = false;
      });
    }
  }

  void _startBackgroundVerification(String email, String sessionId) {
    _pollAttempts = 0;

    // Timeout after 90 seconds
    _pollTimeout = Timer(const Duration(seconds: 90), () {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() {
          _step = _OnrampStep.email;
          _error = 'Verification timed out. Please try again.';
        });
      }
    });

    // Poll every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _pollAttempts++;
      try {
        final order = await _api.onrampCreateOrder(
          email: email,
          sessionId: sessionId,
          fiatAmount: widget.checkoutData.amountUsd,
          paymentLinkId: widget.checkoutData.paymentId,
        );
        _pollTimer?.cancel();
        _pollTimeout?.cancel();
        if (mounted) {
          setState(() {
            _order = order;
            _step = _OnrampStep.bankDetails;
          });
          _startPaymentPolling(order);
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 202) return; // still processing
        _pollTimer?.cancel();
        _pollTimeout?.cancel();
        if (mounted) {
          setState(() {
            _step = _OnrampStep.email;
            _error = 'Verification failed. Please try again.';
          });
        }
      } catch (_) {
        // keep polling
      }
    });
  }

  void _startPaymentPolling(OnrampOrder order) {
    final paymentId = order.paymentId ?? widget.checkoutData.paymentId;

    // Timeout after 15 minutes
    _pollTimeout = Timer(const Duration(minutes: 15), () {
      _pollTimer?.cancel();
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final status = await _api.getPaymentStatus(paymentId);
        if (status['status'] == 'confirmed') {
          _pollTimer?.cancel();
          _pollTimeout?.cancel();
          if (mounted) {
            setState(() => _step = _OnrampStep.success);
            widget.onSuccess();
          }
        }
      } catch (_) {}
    });
  }

  void _copyToClipboard(String text, String field) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedField = field);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedField = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_step) {
        _OnrampStep.email => _buildEmailStep(),
        _OnrampStep.processing => _buildProcessingStep(),
        _OnrampStep.bankDetails => _buildBankDetailsStep(),
        _OnrampStep.success => _buildSuccessStep(),
      },
    );
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your email',
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'We\'ll send your payment receipt here',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.mail_outline, size: 18),
          ),
          onSubmitted: (_) => _submitEmail(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              color: ZendColors.destructive,
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _submitEmail,
          style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildProcessingStep() {
    return Column(
      key: const ValueKey('processing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: CircularProgressIndicator(color: widget.themeColor),
        ),
        const SizedBox(height: 20),
        const Text(
          'Preparing payment details...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 15,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This takes just a few seconds',
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

  Widget _buildBankDetailsStep() {
    final order = _order!;
    return Column(
      key: const ValueKey('bank'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Complete your transfer',
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Send ₦${order.fiatAmount.toStringAsFixed(0)} to the account below',
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZendColors.bgSecondary,
            borderRadius: BorderRadius.circular(ZendRadii.xl),
          ),
          child: Column(
            children: [
              _BankDetailRow(
                label: 'Bank',
                value: order.bankName,
                onCopy: null,
              ),
              const Divider(height: 20),
              _BankDetailRow(
                label: 'Account Name',
                value: order.bankAccountName,
                onCopy: null,
              ),
              const Divider(height: 20),
              _BankDetailRow(
                label: 'Account Number',
                value: order.bankAccountNumber,
                copied: _copiedField == 'account',
                onCopy: () =>
                    _copyToClipboard(order.bankAccountNumber, 'account'),
              ),
              const Divider(height: 20),
              _BankDetailRow(
                label: 'Amount',
                value: '₦${order.fiatAmount.toStringAsFixed(0)}',
                copied: _copiedField == 'amount',
                onCopy: () => _copyToClipboard(
                    order.fiatAmount.toStringAsFixed(0), 'amount'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.themeColor.withValues(alpha: 0.08),
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
                  'Waiting for your transfer...',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: ZendColors.textSecondary,
                  ),
                ),
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
        const Text(
          'Your payment has been received.',
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
}

class _BankDetailRow extends StatelessWidget {
  const _BankDetailRow({
    required this.label,
    required this.value,
    this.copied = false,
    this.onCopy,
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
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'DMMono',
                  fontSize: 15,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ZendColors.bgPrimary,
                borderRadius: BorderRadius.circular(ZendRadii.sm),
                border: Border.all(color: ZendColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    copied ? Icons.check : Icons.copy_outlined,
                    size: 14,
                    color: copied
                        ? ZendColors.positive
                        : ZendColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    copied ? 'Copied' : 'Copy',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: copied
                          ? ZendColors.positive
                          : ZendColors.textSecondary,
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

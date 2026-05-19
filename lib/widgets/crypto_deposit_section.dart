import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../services/api_service.dart';

enum _CryptoStep {
  idle,
  loadingChains,
  chainSelected,
  loadingAddress,
  addressReady,
  error,
}

class CryptoDepositSection extends StatefulWidget {
  const CryptoDepositSection({
    super.key,
    required this.zendtag,
    required this.themeColor,
    this.amountUsd,
  });

  final String zendtag;
  final Color themeColor;
  final double? amountUsd;

  @override
  State<CryptoDepositSection> createState() => _CryptoDepositSectionState();
}

class _CryptoDepositSectionState extends State<CryptoDepositSection> {
  _CryptoStep _step = _CryptoStep.idle;
  List<Map<String, dynamic>> _chains = [];
  Map<String, dynamic>? _selectedChain;
  String? _depositAddress;
  bool _isStatic = true;
  String? _expiresAt;
  String? _error;
  String? _copiedField;

  // For one-time quote tx submission (non-stablecoin deposits)
  bool _showTxSubmit = false;
  bool _submittingTx = false;
  bool _txSubmitted = false;
  String? _txSubmitError;
  final _txHashController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredChains = [];
  final _api = ZendPayApiService();

  @override
  void initState() {
    super.initState();
    _loadChains();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _txHashController.dispose();
    super.dispose();
  }

  Future<void> _loadChains() async {
    setState(() => _step = _CryptoStep.loadingChains);
    try {
      final chains = await _api.getSupportedChains();
      if (!mounted) return;
      setState(() {
        _chains = chains;
        _filteredChains = chains;
        _step = _CryptoStep.idle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load supported chains.';
        _step = _CryptoStep.error;
      });
    }
  }

  Future<void> _onChainSelected(Map<String, dynamic> chain) async {
    setState(() {
      _selectedChain = chain;
      _step = _CryptoStep.loadingAddress;
      _searchQuery = '';
      _searchController.clear();
      _filteredChains = _chains;
    });
    try {
      final result = await _api.getCryptoDepositAddress(
        zendtag: widget.zendtag,
        chainId: chain['chain_id'] as int,
      );
      if (!mounted) return;
      setState(() {
        _depositAddress = result['deposit_address'] as String?;
        _isStatic = result['is_static'] as bool? ?? true;
        _expiresAt = result['expires_at'] as String?;
        _step = _CryptoStep.addressReady;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load deposit address. Please try again.';
        _step = _CryptoStep.error;
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

  Future<void> _submitTxHash() async {
    final txHash = _txHashController.text.trim();
    if (txHash.isEmpty) return;

    setState(() {
      _submittingTx = true;
      _txSubmitError = null;
    });

    try {
      // We need a deposit_id from Dextopus — for one-time quotes the deposit_id
      // is the deposit address itself (Dextopus uses it as the identifier).
      await _api.submitCryptoDepositTx(
        zendtag: widget.zendtag,
        depositId: _depositAddress ?? '',
        txHash: txHash,
      );
      if (!mounted) return;
      setState(() {
        _submittingTx = false;
        _txSubmitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingTx = false;
        _txSubmitError = 'Could not submit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_step) {
        _CryptoStep.loadingChains => _buildLoadingChains(),
        _CryptoStep.idle => _buildChainSelector(),
        _CryptoStep.chainSelected => _buildLoadingAddress(),
        _CryptoStep.loadingAddress => _buildLoadingAddress(),
        _CryptoStep.addressReady => _buildAddressReady(),
        _CryptoStep.error => _buildError(),
      },
    );
  }

  Widget _buildLoadingChains() {
    return Column(
      key: const ValueKey('loadingChains'),
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
          'Loading supported chains...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChainSelector() {
    return Column(
      key: const ValueKey('chainSelector'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select a chain to pay with',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: ZendColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search chains...',
            hintStyle: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              color: ZendColors.textSecondary,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: ZendColors.textSecondary,
            ),
            filled: true,
            fillColor: ZendColors.bgSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZendRadii.pill),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZendRadii.pill),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZendRadii.pill),
              borderSide: BorderSide.none,
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onChanged: (query) {
            setState(() {
              _searchQuery = query;
              _filteredChains = _chains
                  .where((c) =>
                      c['display_name']
                          .toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()) ||
                      c['symbol']
                          .toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()))
                  .toList();
            });
          },
        ),
        const SizedBox(height: 8),
        if (_filteredChains.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No chains found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: ZendColors.textSecondary,
              ),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < _filteredChains.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _onChainSelected(_filteredChains[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: ZendColors.bgSecondary,
                      borderRadius: BorderRadius.circular(ZendRadii.lg),
                    ),
                    child: Row(
                      children: [
                        // Letter avatar
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.themeColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (_filteredChains[i]['blockchain_name'] as String)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.themeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _filteredChains[i]['display_name'] as String,
                              style: const TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ZendColors.textPrimary,
                              ),
                            ),
                            Text(
                              _filteredChains[i]['symbol'] as String,
                              style: const TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 11,
                                color: ZendColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildLoadingAddress() {
    return Column(
      key: const ValueKey('loadingAddress'),
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
          'Getting deposit address...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: ZendColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAddressReady() {
    final chain = _selectedChain!;
    final address = _depositAddress ?? '—';

    return Column(
      key: const ValueKey('addressReady'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button row
        GestureDetector(
          onTap: () => setState(() {
            _step = _CryptoStep.idle;
            _selectedChain = null;
            _depositAddress = null;
            _isStatic = true;
            _expiresAt = null;
            _showTxSubmit = false;
            _txSubmitted = false;
            _txSubmitError = null;
            _txHashController.clear();
          }),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back,
                size: 16,
                color: ZendColors.textSecondary,
              ),
              const SizedBox(width: 4),
              const Text(
                'Back',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  color: ZendColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Chain name header
        Text(
          chain['display_name'] as String,
          style: const TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ZendColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),

        // Instructional text
        Text(
          'Send ${chain['symbol']} on ${chain['blockchain_name']} to this address. '
          "It will arrive in @${widget.zendtag}'s Zend balance automatically.",
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 12,
            color: ZendColors.textSecondary,
          ),
        ),
        if (!_isStatic && _expiresAt != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(ZendRadii.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 13, color: Color(0xFF856404)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This address expires soon — send within the time window.',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: Color(0xFF856404),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Address card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZendColors.bgSecondary,
            borderRadius: BorderRadius.circular(ZendRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Deposit Address',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  color: ZendColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                address,
                style: const TextStyle(
                  fontFamily: 'DMMono',
                  fontSize: 13,
                  color: ZendColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _depositAddress != null
                    ? () => _copyToClipboard(_depositAddress!, 'address')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                ),
                icon: Icon(
                  _copiedField == 'address'
                      ? Icons.check
                      : Icons.copy_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  _copiedField == 'address' ? 'Copied!' : 'Copy address',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // For one-time quotes (non-stablecoin), let the payer submit their tx hash
        // so Dextopus can confirm receipt and trigger the bridge.
        if (!_isStatic) ...[
          const SizedBox(height: 16),
          if (_txSubmitted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZendColors.positive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ZendRadii.lg),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: ZendColors.positive),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transaction submitted! Your payment will arrive once confirmed on-chain.',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 12,
                        color: ZendColors.positive,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!_showTxSubmit)
            GestureDetector(
              onTap: () => setState(() => _showTxSubmit = true),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_outlined, size: 13, color: widget.themeColor),
                  const SizedBox(width: 6),
                  Text(
                    "I've sent it — submit tx hash",
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.themeColor,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _txHashController,
              style: const TextStyle(fontFamily: 'DMMono', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Paste your transaction hash',
                hintStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  color: ZendColors.textSecondary,
                ),
                filled: true,
                fillColor: ZendColors.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZendRadii.lg),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (_txSubmitError != null) ...[
              const SizedBox(height: 4),
              Text(
                _txSubmitError!,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  color: ZendColors.destructive,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submittingTx ? null : _submitTxHash,
              style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
              child: _submittingTx
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildError() {
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
            child: const Icon(
              Icons.error_outline,
              color: ZendColors.destructive,
              size: 28,
            ),
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
          onPressed: () {
            if (_chains.isEmpty) {
              _loadChains();
            } else {
              setState(() {
                _step = _CryptoStep.idle;
                _error = null;
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

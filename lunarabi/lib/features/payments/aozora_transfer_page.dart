import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

/// Shows virtual account details and a single manual confirm button.
class AozoraTransferPage extends StatefulWidget {
  const AozoraTransferPage({
    super.key,
    required this.session,
    required this.backend,
    required this.navigator,
    required this.config,
  });

  final AozoraTransferSession session;
  final PaymentBackendClient backend;
  final AppNavigator navigator;
  final AppConfig config;

  @override
  State<AozoraTransferPage> createState() => _AozoraTransferPageState();
}

class _AozoraTransferPageState extends State<AozoraTransferPage> {
  var _busy = false;
  String? _message;
  Future<PaymentStatus>? _inFlight;

  @override
  void dispose() {
    // Do not loop; just drop the reference so a late result is ignored.
    _inFlight = null;
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final future = widget.backend.checkBankTransfer(
      paymentId: widget.session.paymentId,
    );
    _inFlight = future;

    PaymentStatus status;
    try {
      status = await future;
    } catch (error) {
      if (!mounted || !identical(_inFlight, future)) return;
      setState(() {
        _busy = false;
        _message = '確認に失敗しました';
      });
      return;
    }

    if (!mounted || !identical(_inFlight, future)) return;

    switch (status) {
      case PaymentStatus.success:
        await widget.navigator.openDeepLink(
          widget.config.webBaseUrl.replace(path: '/pay/done'),
        );
        if (mounted) Navigator.of(context).pop(PaymentStatus.success);
      case PaymentStatus.pending:
        setState(() {
          _busy = false;
          _message = 'まだ入金を確認できません。しばらくしてから再度お試しください。';
        });
      case PaymentStatus.failure:
      case PaymentStatus.idle:
        setState(() {
          _busy = false;
          _message = '入金確認に失敗しました';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('銀行振込')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '以下の口座へお振り込みください',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              widget.session.accountDisplay,
              key: const Key('aozora-account-display'),
            ),
            const SizedBox(height: 8),
            Text(
              '有効期限: ${widget.session.expiresAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('aozora-confirm-button'),
              onPressed: _busy ? null : _onConfirm,
              child: Text(_busy ? '確認中…' : '入金を確認'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                key: const Key('aozora-status-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/auth_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  QrCodeResult? _qrResult;
  String _statusText = '请使用哔哩哔哩客户端扫码登录';
  bool _isLoading = true;
  bool _isExpired = false;
  void Function()? _cancelPolling;

  @override
  void initState() {
    super.initState();
    _fetchQr();
  }

  Future<void> _fetchQr() async {
    setState(() {
      _isLoading = true;
      _isExpired = false;
      _statusText = '请使用哔哩哔哩客户端扫码登录';
    });

    _cancelPolling?.call();

    final result = await AuthApiService().generateQrCode();
    if (result != null && mounted) {
      setState(() {
        _qrResult = result;
        _isLoading = false;
      });

      _cancelPolling = context.read<AuthProvider>().startQrPolling(
        qrcodeKey: result.qrcodeKey,
        onStatus: (pollResult) {
          if (!mounted) return;
          if (pollResult.isScanned) {
            setState(() {
              _statusText = '已扫码，请在手机上确认登录';
            });
          } else if (pollResult.isExpired) {
            setState(() {
              _isExpired = true;
              _statusText = '二维码已失效，点击刷新';
            });
          }
        },
        onSuccess: () {
          if (!mounted) return;
          Navigator.of(context).pop(true);
          AppToast.show(
            context,
            '登录成功！',
            icon: Icons.check_circle_rounded,
          );
        },
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _statusText = '获取二维码失败，请重试';
      });
    }
  }

  @override
  void dispose() {
    _cancelPolling?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xD91E1E24) : const Color(0xF0FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '扫码登录',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // QR Code Box
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : _isExpired
                            ? InkWell(
                                onTap: _fetchQr,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 34, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '二维码已失效\n点击刷新',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.black87, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : (_qrResult != null
                                ? Center(
                                    child: QrImageView(
                                      data: _qrResult!.url,
                                      version: QrVersions.auto,
                                      size: 160.0,
                                      padding: const EdgeInsets.all(10),
                                    ),
                                  )
                                : const Center(child: Text('加载失败', style: TextStyle(fontSize: 12, color: Colors.black87)))),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isExpired ? Theme.of(context).colorScheme.primary : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

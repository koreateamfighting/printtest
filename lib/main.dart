import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'pdf_print_service.dart';
import 'windows_printer_service.dart'
    if (dart.library.html) 'windows_printer_service_stub.dart';
import 'bluetooth_printer_service.dart'
    if (dart.library.html) 'bluetooth_printer_service_stub.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Printer Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const PrintDemoPage(),
    );
  }
}

class PrintDemoPage extends StatefulWidget {
  const PrintDemoPage({super.key});

  @override
  State<PrintDemoPage> createState() => _PrintDemoPageState();
}

class _PrintDemoPageState extends State<PrintDemoPage> {
  late final TextEditingController _printerController;

  final TextEditingController _textController = TextEditingController(
    text: '''
================================
        휘모리 주식회사
================================
인천광역시 연수구 갯벌로 12, 갯벌타워 1104호
TEL: 032-710-0325
--------------------------------
주문번호: #20231208-001
날짜: 2025-12-08 14:30:25
--------------------------------
[주문내역]

아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500
아메리카노            1   4,500

--------------------------------
합계                      4,500
--------------------------------
결제수단: 카드
승인번호: 12345678

--------------------------------
      감사합니다!
    또 방문해주세요 :)
================================
''',
  );

  bool _isPrinting = false;
  bool _autoCut = true;
  bool _isBluetoothConnected = false;
  bool _hasBluetoothPermission = false;

  /// 현재 플랫폼 타입
  String get _platformType {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid || Platform.isIOS) return 'mobile';
    return 'other';
  }

  /// 앱바 타이틀
  String get _appBarTitle {
    switch (_platformType) {
      case 'web':
        return '영수증 프린터 (PDF)';
      case 'windows':
        return '영수증 프린터 (ESC/POS)';
      case 'mobile':
        return '영수증 프린터 (Bluetooth)';
      default:
        return '영수증 프린터';
    }
  }

  /// 기본 프린터 이름
  String get _defaultPrinterName {
    switch (_platformType) {
      case 'windows':
        return 'SLK-TS400';
      case 'mobile':
        return 'POS Printer';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _printerController = TextEditingController(text: _defaultPrinterName);
    // 모바일에서 블루투스 권한 요청 (프레임 빌드 후 실행)
    if (!kIsWeb && _platformType == 'mobile') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestBluetoothPermission();
      });
    }
  }

  /// 블루투스 권한 요청 (모바일 전용)
  Future<void> _requestBluetoothPermission() async {
    if (_platformType != 'mobile') return;

    try {
      // 권한 요청 (이미 허용된 경우에도 true 반환)
      final hasPermission = await BluetoothPrinterService.requestPermissions();

      if (mounted) {
        setState(() => _hasBluetoothPermission = hasPermission);
      }
    } catch (e) {
      // 권한 요청 실패해도 일단 true로 설정하고 연결 시도 시 다시 확인
      if (mounted) {
        setState(() => _hasBluetoothPermission = true);
      }
    }
  }

  /// 권한 거부 시 다이얼로그
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('블루투스 권한 필요'),
        content: const Text(
          '블루투스 프린터를 사용하려면 블루투스 권한이 필요합니다.\n\n'
          '권한 요청이 나타나지 않으면 "설정 열기"를 눌러\n'
          '앱 권한에서 직접 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BluetoothPrinterService.openSettings();
            },
            child: const Text('설정 열기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestBluetoothPermission();
            },
            child: const Text('다시 요청'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _printerController.dispose();
    _textController.dispose();
    // 블루투스 연결 해제
    if (_platformType == 'mobile') {
      BluetoothPrinterService.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          // 모바일: 블루투스 연결 상태 표시
          if (_platformType == 'mobile')
            IconButton(
              onPressed: _handleBluetoothConnect,
              icon: Icon(
                _isBluetoothConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                color: _isBluetoothConnected ? Colors.green : null,
              ),
              tooltip: _isBluetoothConnected ? '연결됨' : '블루투스 연결',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프린터 이름 텍스트필드 (Windows, Mobile)
            if (_platformType != 'web') ...[
              TextField(
                controller: _printerController,
                decoration: InputDecoration(
                  labelText: _platformType == 'mobile' ? '블루투스 프린터 이름' : '프린터 이름',
                  hintText: _defaultPrinterName,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    _platformType == 'mobile' ? Icons.bluetooth : Icons.print,
                  ),
                  suffixIcon: _platformType == 'mobile'
                      ? IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _handleBluetoothConnect,
                          tooltip: '프린터 검색',
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // 옵션
              Row(
                children: [
                  Checkbox(
                    value: _autoCut,
                    onChanged: (value) {
                      setState(() => _autoCut = value ?? true);
                    },
                  ),
                  const Text('인쇄 후 자동 커팅'),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 플랫폼별 안내 메시지
            _buildPlatformInfo(),

            // 모바일에서 권한 없을 때 권한 요청 버튼
            if (_platformType == 'mobile' && !_hasBluetoothPermission) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestBluetoothPermission,
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('블루투스 권한 허용'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 텍스트 입력
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  labelText: '출력할 텍스트',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 인쇄 버튼
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _handlePrint,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: Text(_isPrinting ? '인쇄 중...' : _getPrintButtonLabel()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 플랫폼별 안내 메시지 위젯
  Widget _buildPlatformInfo() {
    String message;
    Color color;
    IconData icon;

    switch (_platformType) {
      case 'web':
        message = '웹에서는 PDF로 변환하여 인쇄합니다.\n인쇄 버튼을 누르면 미리보기가 표시됩니다.';
        color = Colors.blue;
        icon = Icons.info_outline;
        break;
      case 'mobile':
        if (!_hasBluetoothPermission) {
          message = '블루투스 권한이 필요합니다.\n아래 버튼을 눌러 권한을 허용해주세요.';
          color = Colors.red;
          icon = Icons.warning_amber;
        } else if (_isBluetoothConnected) {
          message = '블루투스 프린터에 연결되었습니다.\n인쇄 버튼을 눌러 출력하세요.';
          color = Colors.green;
          icon = Icons.check_circle_outline;
        } else {
          message = '블루투스 아이콘을 눌러 프린터를 연결하세요.\n프린터 이름: ${_printerController.text}';
          color = Colors.orange;
          icon = Icons.bluetooth_searching;
        }
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// 인쇄 버튼 라벨
  String _getPrintButtonLabel() {
    switch (_platformType) {
      case 'web':
        return 'PDF 인쇄';
      case 'mobile':
        return '블루투스 인쇄';
      default:
        return '인쇄';
    }
  }

  /// 블루투스 연결 처리
  Future<void> _handleBluetoothConnect() async {
    if (_isBluetoothConnected) {
      // 연결 해제
      await BluetoothPrinterService.disconnect();
      setState(() => _isBluetoothConnected = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('블루투스 연결이 해제되었습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 연결 시도
    final printerName = _printerController.text.trim();
    if (printerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프린터 이름을 입력하세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$printerName 검색 중...'),
          duration: const Duration(seconds: 10),
        ),
      );

      await BluetoothPrinterService.connectToPrinter(printerName: printerName);

      if (!mounted) return;
      setState(() => _isBluetoothConnected = true);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$printerName 연결 완료!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연결 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 인쇄 처리
  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);

    try {
      switch (_platformType) {
        case 'web':
          // 웹: PDF로 인쇄
          await PdfPrintService.printText(text: _textController.text);
          break;

        case 'windows':
          // Windows: ESC/POS RAW 전송
          final printerName = _printerController.text.trim();
          if (printerName.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('프린터 이름을 입력하세요'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          await WindowsPrinterService.printTextToPrinter(
            text: _textController.text,
            printerName: printerName,
            cut: _autoCut,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인쇄 완료!'),
              backgroundColor: Colors.green,
            ),
          );
          break;

        case 'mobile':
          // Android/iOS: Bluetooth ESC/POS
          final printerName = _printerController.text.trim();
          if (printerName.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('프린터 이름을 입력하세요'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          await BluetoothPrinterService.printText(
            text: _textController.text,
            printerName: printerName,
            cut: _autoCut,
          );

          if (!mounted) return;
          setState(() => _isBluetoothConnected = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인쇄 완료!'),
              backgroundColor: Colors.green,
            ),
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('인쇄 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }
}

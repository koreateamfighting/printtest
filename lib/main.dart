import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'pdf_print_service.dart';
import 'windows_printer_service.dart'
    if (dart.library.html) 'windows_printer_service_stub.dart';

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
  final TextEditingController _printerController = TextEditingController(
    text: 'SEWOO SLK-TS100',
  );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(kIsWeb ? '영수증 프린터 (PDF)' : '영수증 프린터 (ESC/POS)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프린터 이름 텍스트필드 (Windows만)
            if (!kIsWeb) ...[
              TextField(
                controller: _printerController,
                decoration: const InputDecoration(
                  labelText: '프린터 이름',
                  hintText: 'SEWOO SLK-TS100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.print),
                ),
              ),
              const SizedBox(height: 12),

              // 옵션 (Windows만)
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

            // 웹 안내 메시지
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '웹에서는 PDF로 변환하여 인쇄합니다.\n인쇄 버튼을 누르면 미리보기가 표시됩니다.',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

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
                label: Text(_isPrinting
                    ? '인쇄 중...'
                    : (kIsWeb ? 'PDF 인쇄' : '인쇄')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);

    try {
      if (kIsWeb) {
        // 웹: PDF로 인쇄
        await PdfPrintService.printText(text: _textController.text);
      } else {
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

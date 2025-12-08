/// 웹용 WindowsPrinterService stub
/// 웹에서는 이 클래스가 사용되지 않지만, 컴파일을 위해 필요
class WindowsPrinterService {
  static Future<void> printTextToPrinter({
    required String text,
    required String printerName,
    bool cut = true,
    int feedLines = 3,
  }) async {
    throw UnsupportedError('웹에서는 지원되지 않습니다. PDF 인쇄를 사용하세요.');
  }
}

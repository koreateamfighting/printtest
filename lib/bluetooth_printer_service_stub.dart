/// 웹용 BluetoothPrinterService stub
/// 웹에서는 이 클래스가 사용되지 않지만, 컴파일을 위해 필요
class BluetoothPrinterService {
  static const String defaultPrinterName = 'POS Printer';

  static Future<bool> requestPermissions() async {
    return true; // 웹에서는 권한 불필요
  }

  static Future<bool> openSettings() async {
    return false; // 웹에서는 지원 안됨
  }

  static Future<bool> isBluetoothOn() async {
    throw UnsupportedError('웹에서는 지원되지 않습니다.');
  }

  static Future<void> connectToPrinter({
    String printerName = defaultPrinterName,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    throw UnsupportedError('웹에서는 지원되지 않습니다. PDF 인쇄를 사용하세요.');
  }

  static Future<void> disconnect() async {
    // 웹에서는 아무것도 하지 않음
  }

  static Future<void> printText({
    required String text,
    String printerName = defaultPrinterName,
    bool cut = true,
    int feedLines = 3,
  }) async {
    throw UnsupportedError('웹에서는 지원되지 않습니다. PDF 인쇄를 사용하세요.');
  }

  static bool get isConnected => false;

  static String? get connectedDeviceName => null;
}

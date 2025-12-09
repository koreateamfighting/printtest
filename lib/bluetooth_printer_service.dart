import 'dart:async';
import 'dart:io';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charset_converter/charset_converter.dart';

/// Android/iOS에서 Classic Bluetooth로 ESC/POS 프린터에 연결하여 인쇄하는 서비스
/// Sewoo SLK-TS400B 등 SPP 프린터 지원
class BluetoothPrinterService {
  static String? _connectedMac;
  static bool _isConnected = false;

  /// 기본 프린터 이름 (블루투스에서는 "POS Printer"로 표시됨)
  static const String defaultPrinterName = 'POS Printer';

  /// 블루투스 권한 요청
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 12+ (API 31+) 권한
      List<Permission> permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ];

      // 권한 요청
      Map<Permission, PermissionStatus> statuses = await permissions.request();

      // 결과 확인 - granted 또는 limited면 OK
      for (var entry in statuses.entries) {
        if (!entry.value.isGranted && !entry.value.isLimited) {
          // 권한이 거부된 경우에도 일단 진행 시도
          // 실제 블루투스 연결 시 다시 확인됨
        }
      }

      // 항상 true 반환 - 실제 연결 시 권한 문제가 있으면 에러 발생
      return true;
    } else if (Platform.isIOS) {
      PermissionStatus status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// 앱 설정 열기
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// 블루투스 상태 확인
  static Future<bool> isBluetoothOn() async {
    return await PrintBluetoothThermal.bluetoothEnabled;
  }

  /// 페어링된 장치 목록 가져오기
  static Future<List<BluetoothInfo>> getBondedDevices() async {
    bool hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('블루투스 권한이 필요합니다.');
    }

    bool isOn = await isBluetoothOn();
    if (!isOn) {
      throw Exception('블루투스가 꺼져 있습니다. 블루투스를 켜주세요.');
    }

    List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices;
  }

  /// 프린터 이름으로 연결
  static Future<void> connectToPrinter({
    String printerName = defaultPrinterName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // 이미 연결된 경우 확인
    if (_isConnected && _connectedMac != null) {
      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (connected) {
        return;
      }
      _isConnected = false;
      _connectedMac = null;
    }

    // 권한 확인
    bool hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('블루투스 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
    }

    // 블루투스 상태 확인
    bool isOn = await isBluetoothOn();
    if (!isOn) {
      throw Exception('블루투스가 꺼져 있습니다. 블루투스를 켜주세요.');
    }

    // 페어링된 장치에서 찾기
    List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
    BluetoothInfo? targetDevice;

    for (var device in devices) {
      if (_matchesPrinterName(device.name, printerName)) {
        targetDevice = device;
        break;
      }
    }

    if (targetDevice == null) {
      // 사용 가능한 장치 목록 출력
      String availableDevices = devices.map((d) => d.name).join(', ');
      throw Exception('프린터를 찾을 수 없습니다: $printerName\n'
          '1. 프린터 전원이 켜져 있는지 확인하세요.\n'
          '2. 휴대폰 블루투스 설정에서 먼저 페어링하세요.\n'
          '페어링된 장치: $availableDevices');
    }

    // 연결 시도
    bool result = await PrintBluetoothThermal.connect(
      macPrinterAddress: targetDevice.macAdress,
    );

    if (!result) {
      throw Exception('연결에 실패했습니다. 다시 시도해주세요.\n'
          '프린터 전원과 블루투스가 켜져 있는지 확인하세요.');
    }

    _connectedMac = targetDevice.macAdress;
    _isConnected = true;
  }

  /// 프린터 이름 매칭
  static bool _matchesPrinterName(String deviceName, String searchName) {
    if (deviceName.isEmpty) return false;
    final lowerDevice = deviceName.toLowerCase();
    final lowerSearch = searchName.toLowerCase();
    return lowerDevice.contains(lowerSearch) || lowerSearch.contains(lowerDevice);
  }

  /// 연결 해제
  static Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    _connectedMac = null;
    _isConnected = false;
  }

  /// 텍스트 인쇄 (ESC/POS RAW 데이터)
  static Future<void> printText({
    required String text,
    String printerName = defaultPrinterName,
    bool cut = true,
    int feedLines = 3,
  }) async {
    // 연결 확인 및 연결
    await connectToPrinter(printerName: printerName);

    // 연결 상태 재확인
    bool connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      throw Exception('프린터에 연결되어 있지 않습니다.');
    }

    // ESC/POS 명령어 생성
    List<int> bytes = [];

    // ESC @ : 프린터 초기화
    bytes.addAll([0x1B, 0x40]);

    // FS & : 한글 모드 ON (Sewoo 프린터)
    bytes.addAll([0x1C, 0x26]);

    // 텍스트를 EUC-KR (CP949)로 인코딩 - 한글 지원
    final encodedText = await CharsetConverter.encode('euc-kr', text);
    bytes.addAll(encodedText);

    // 줄바꿈 (피드)
    for (int i = 0; i < feedLines; i++) {
      bytes.add(0x0A);
    }

    // 용지 커팅
    if (cut) {
      bytes.addAll([0x1D, 0x56, 0x00]); // GS V 0 : 전체 커팅
    }

    // RAW 데이터 전송
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  /// 연결 상태 확인
  static bool get isConnected => _isConnected;

  /// 연결된 장치 MAC 주소
  static String? get connectedDeviceMac => _connectedMac;
}

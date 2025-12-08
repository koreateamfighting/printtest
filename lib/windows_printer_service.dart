import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 윈도우에서 영수증 프린터(POS/써멀)로 ESC/POS 명령어를 전송
class WindowsPrinterService {
  /// [text] : 출력할 내용 (한글 포함)
  /// [printerName] : 윈도우에 등록된 프린터 이름
  /// [cut] : 인쇄 후 용지 커팅 여부 (기본 true)
  /// [feedLines] : 커팅 전 빈 줄 수 (기본 3)
  static Future<void> printTextToPrinter({
    required String text,
    required String printerName,
    bool cut = true,
    int feedLines = 3,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows에서만 지원됩니다.');
    }

    // 텍스트를 임시 파일에 저장 (PowerShell에서 CP949로 변환)
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final txtFile = File('${tempDir.path}/flutter_print_$timestamp.txt');
    final binFile = File('${tempDir.path}/flutter_print_$timestamp.bin');

    // UTF-8로 텍스트 저장
    await txtFile.writeAsString(text);

    final escapedTxtPath = txtFile.path.replaceAll("'", "''");
    final escapedBinPath = binFile.path.replaceAll("'", "''");
    final escapedPrinter = printerName.replaceAll("'", "''");

    // PowerShell 스크립트: CP949 인코딩 + ESC/POS 명령어 + RAW 전송
    final script = '''
# 텍스트 파일 읽기
\$text = Get-Content -Path '$escapedTxtPath' -Raw -Encoding UTF8

# CP949 (EUC-KR) 인코딩
\$cp949 = [System.Text.Encoding]::GetEncoding(949)

# ESC/POS 바이트 배열 생성
\$bytes = New-Object System.Collections.ArrayList

# ESC @ : 프린터 초기화
[void]\$bytes.Add([byte]0x1B)
[void]\$bytes.Add([byte]0x40)

# FS & : 한글 모드 ON (SEWOO 프린터)
[void]\$bytes.Add([byte]0x1C)
[void]\$bytes.Add([byte]0x26)

# 텍스트를 CP949로 인코딩하여 추가
\$textBytes = \$cp949.GetBytes(\$text)
foreach (\$b in \$textBytes) {
    [void]\$bytes.Add(\$b)
}

# 줄바꿈 추가 (피드)
for (\$i = 0; \$i -lt $feedLines; \$i++) {
    [void]\$bytes.Add([byte]0x0A)
}

# 용지 커팅
if (\$$cut) {
    [void]\$bytes.Add([byte]0x1D)
    [void]\$bytes.Add([byte]0x56)
    [void]\$bytes.Add([byte]0x00)
}

# 바이트 배열을 파일로 저장
[System.IO.File]::WriteAllBytes('$escapedBinPath', \$bytes.ToArray())

# RAW 프린터 전송 클래스 정의
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class RawPrinter {
    [DllImport("winspool.drv", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool OpenPrinter(string pPrinterName, out IntPtr hPrinter, IntPtr pDefault);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int Level, ref DOCINFOA pDocInfo);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    [StructLayout(LayoutKind.Sequential)]
    public struct DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDataType;
    }

    public static bool SendBytesToPrinter(string printerName, byte[] bytes) {
        IntPtr hPrinter = IntPtr.Zero;
        DOCINFOA docInfo = new DOCINFOA();
        docInfo.pDocName = "Flutter POS Print";
        docInfo.pDataType = "RAW";

        if (!OpenPrinter(printerName, out hPrinter, IntPtr.Zero)) {
            Console.WriteLine("OpenPrinter failed: " + Marshal.GetLastWin32Error());
            return false;
        }

        if (!StartDocPrinter(hPrinter, 1, ref docInfo)) {
            Console.WriteLine("StartDocPrinter failed: " + Marshal.GetLastWin32Error());
            ClosePrinter(hPrinter);
            return false;
        }

        if (!StartPagePrinter(hPrinter)) {
            Console.WriteLine("StartPagePrinter failed: " + Marshal.GetLastWin32Error());
            EndDocPrinter(hPrinter);
            ClosePrinter(hPrinter);
            return false;
        }

        IntPtr pBytes = Marshal.AllocHGlobal(bytes.Length);
        Marshal.Copy(bytes, 0, pBytes, bytes.Length);

        int written;
        bool success = WritePrinter(hPrinter, pBytes, bytes.Length, out written);
        if (!success) {
            Console.WriteLine("WritePrinter failed: " + Marshal.GetLastWin32Error());
        }

        Marshal.FreeHGlobal(pBytes);
        EndPagePrinter(hPrinter);
        EndDocPrinter(hPrinter);
        ClosePrinter(hPrinter);

        return success;
    }
}
"@

# 바이트 파일 읽어서 프린터로 전송
\$printBytes = [System.IO.File]::ReadAllBytes('$escapedBinPath')
\$result = [RawPrinter]::SendBytesToPrinter('$escapedPrinter', \$printBytes)

if (-not \$result) {
    throw "프린터 전송 실패"
}
Write-Host "인쇄 성공"
''';

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
    );

    // 임시 파일 삭제
    try {
      await txtFile.delete();
      await binFile.delete();
    } catch (_) {}

    if (result.exitCode != 0) {
      throw Exception(
          '인쇄 실패 (exitCode: ${result.exitCode})\nstdout: ${result.stdout}\nstderr: ${result.stderr}');
    }
  }
}

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// 웹/모바일에서 PDF로 영수증을 인쇄하는 서비스
class PdfPrintService {
  static pw.Font? _nanumFont;

  /// 한글 폰트 로드
  static Future<pw.Font> _loadFont() async {
    if (_nanumFont != null) return _nanumFont!;

    final fontData = await rootBundle.load('assets/fonts/NanumGothic.ttf');
    _nanumFont = pw.Font.ttf(fontData);
    return _nanumFont!;
  }

  /// 텍스트를 PDF로 변환하여 인쇄 대화상자 표시
  static Future<void> printText({
    required String text,
  }) async {
    final font = await _loadFont();

    final pdf = pw.Document();

    // 영수증 용지 크기 (80mm 폭, 높이는 A4 기준으로 자동 페이지 분할)
    const receiptWidth = 80.0 * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      receiptWidth,
      PdfPageFormat.a4.height,
      marginAll: 10,
    );

    final textStyle = pw.TextStyle(
      font: font,
      fontSize: 10,
    );

    // 줄 단위로 분리하여 각각 위젯으로 생성 (자동 페이지 분할 가능)
    final lines = text.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return lines.map((line) {
            return pw.Text(
              line.isEmpty ? ' ' : line, // 빈 줄은 공백으로
              style: textStyle,
            );
          }).toList();
        },
      ),
    );

    // 인쇄 대화상자 표시
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '영수증',
      format: pageFormat,
    );
  }

  /// PDF 미리보기 위젯용 빌더
  static Future<Uint8List> buildPdf(String text) async {
    final font = await _loadFont();

    final pdf = pw.Document();

    const receiptWidth = 80.0 * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      receiptWidth,
      PdfPageFormat.a4.height,
      marginAll: 10,
    );

    final textStyle = pw.TextStyle(
      font: font,
      fontSize: 10,
    );

    final lines = text.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return lines.map((line) {
            return pw.Text(
              line.isEmpty ? ' ' : line,
              style: textStyle,
            );
          }).toList();
        },
      ),
    );

    return pdf.save();
  }
}

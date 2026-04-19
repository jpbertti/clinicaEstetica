import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> generateCaixaReport({
    required Map<String, dynamic> caixa,
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> movimentos,
  }) async {
    final pdf = pw.Document();

    // Use Roboto from Google Fonts via Printing package to support Unicode (accents, R$, etc)
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final baseStyle = pw.TextStyle(font: fontRegular, fontSize: 10);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 10);

    final saldoInicial = (caixa['saldo_inicial'] as num?)?.toDouble() ?? 0.0;
    final totalEntradas = (stats['total_entradas'] as num?)?.toDouble() ?? 0.0;
    final totalSaidas = (stats['total_apenas_saidas'] as num?)?.toDouble() ?? 0.0;
    final totalSangrias = (stats['total_sangrias'] as num?)?.toDouble() ?? 0.0;
    final saldoFinalSistemo = saldoInicial + totalEntradas - totalSaidas - totalSangrias;
    final saldoFinalReal = (caixa['saldo_final_real'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Relatório de Fechamento de Caixa', 
                    style: boldStyle.copyWith(fontSize: 20)
                  ),
                  pw.Text(_dateFormat.format(DateTime.now()), style: baseStyle),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Summary Section
            pw.Text('Resumo Financeiro', style: boldStyle.copyWith(fontSize: 16)),
            pw.Divider(color: PdfColors.grey300),
            _buildPdfRow('ID do Caixa', caixa['id'].toString(), baseStyle, boldStyle),
            _buildPdfRow('Status', caixa['status'].toString().toUpperCase(), baseStyle, boldStyle),
            _buildPdfRow('Abertura', _dateFormat.format(DateTime.parse(caixa['aberto_em'] as String).toLocal()), baseStyle, boldStyle),
            if (caixa['fechado_em'] != null)
              _buildPdfRow('Fechamento', _dateFormat.format(DateTime.parse(caixa['fechado_em'] as String).toLocal()), baseStyle, boldStyle),
            _buildPdfRow('Saldo Inicial', _currencyFormat.format(saldoInicial), baseStyle, boldStyle),
            _buildPdfRow('Total Entradas (+)', _currencyFormat.format(totalEntradas), baseStyle, boldStyle),
            _buildPdfRow('Total Saídas (-)', _currencyFormat.format(totalSaidas), baseStyle, boldStyle),
            _buildPdfRow('Total Sangrias (-)', _currencyFormat.format(totalSangrias), baseStyle, boldStyle),
            pw.Divider(color: PdfColors.grey300),
            _buildPdfRow('Saldo Final (Sistema)', _currencyFormat.format(saldoFinalSistemo), baseStyle, boldStyle, isBold: true),
            _buildPdfRow('Saldo Final (Físico)', _currencyFormat.format(saldoFinalReal), baseStyle, boldStyle, isBold: true),
            _buildPdfRow('Diferença', _currencyFormat.format(saldoFinalReal - saldoFinalSistemo), 
              baseStyle, boldStyle,
              isBold: true, 
              color: (saldoFinalReal - saldoFinalSistemo) >= 0 ? PdfColors.green : PdfColors.red),
            
            pw.SizedBox(height: 32),

            // Movements Table
            pw.Text('Listagem de Movimentações', style: boldStyle.copyWith(fontSize: 16)),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('Data/Hora', boldStyle, isHeader: true),
                    _buildTableCell('Tipo', boldStyle, isHeader: true),
                    _buildTableCell('Descrição', boldStyle, isHeader: true),
                    _buildTableCell('Valor', boldStyle, isHeader: true, align: pw.Alignment.centerRight),
                  ],
                ),
                // Table Rows
                ...movimentos.map((m) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(_dateFormat.format(m['data'] as DateTime), baseStyle),
                      _buildTableCell(m['tipo'].toString().toUpperCase(), baseStyle),
                      _buildTableCell(
                        (m['titulo'] as String) + (m['infos'] != null ? '\n${m['infos']}' : ''), 
                        baseStyle
                      ),
                      _buildTableCell(_currencyFormat.format(m['valor']), baseStyle, align: pw.Alignment.centerRight),
                    ],
                  );
                }),
              ],
            ),
            
            if (caixa['observacoes'] != null && (caixa['observacoes'] as String).isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text('Observações', style: boldStyle),
              pw.SizedBox(height: 4),
              pw.Text(caixa['observacoes'].toString(), style: baseStyle),
            ],
          ];
        },
      ),
    );

    // layoutPdf is the most compatible way for both Mobile and Web
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Caixa_${caixa['id']}.pdf',
    );
  }

  static pw.Widget _buildPdfRow(String label, String value, pw.TextStyle baseStyle, pw.TextStyle boldStyle, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: baseStyle),
          pw.Text(
            value, 
            style: (isBold ? boldStyle : baseStyle).copyWith(color: color)
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, pw.TextStyle style, {bool isHeader = false, pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: style.copyWith(
            fontSize: isHeader ? 10 : 9,
          ),
        ),
      ),
    );
  }
}


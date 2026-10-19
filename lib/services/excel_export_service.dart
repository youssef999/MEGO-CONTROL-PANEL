import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../models/driver_model.dart';
import '../models/food_checkout_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';

class ExcelExportService {
  ExcelExportService._();

  static final _dateStamp = DateFormat('yyyy-MM-dd');
  static const emptyValue = '-';

  static String fileName(String prefix) =>
      'mego_${prefix}_${_dateStamp.format(DateTime.now())}';

  static Future<void> exportSheet({
    required String sheetName,
    required List<String> headers,
    required List<List<Object?>> rows,
    required String fileName,
  }) async {
    if (rows.isEmpty) {
      throw StateError('No rows to export');
    }
    final bytes = _buildXlsx(
      sheetName: sheetName,
      headers: headers,
      rows: rows,
    );
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static List<List<Object?>> rowsFromUsers(List<UserModel> users) {
    return users
        .map(
          (u) => <Object?>[
            u.id,
            u.name,
            u.email,
            u.phone,
            u.userType,
            u.formattedDate,
          ],
        )
        .toList();
  }

  static List<List<Object?>> rowsFromDrivers(List<DriverModel> drivers) {
    return drivers.map((d) {
      final type = (d.type?.trim().isNotEmpty ?? false) ? d.type!.trim() : 'ride';
      final statusParts = <String>[
        d.activated ? 'Activated' : 'Inactive',
        d.online ? 'Online' : 'Offline',
      ];
      return <Object?>[
        d.id,
        d.name,
        d.email,
        d.phone,
        type,
        d.carDescription,
        _round1(d.rate),
        statusParts.join(' / '),
        d.city,
        d.formattedDate,
      ];
    }).toList();
  }

  static List<List<Object?>> rowsFromRestaurants(
    List<RestaurantModel> restaurants,
  ) {
    return restaurants
        .map(
          (r) => <Object?>[
            r.id,
            r.name,
            r.category,
            r.isAccepted ? 'Accepted' : 'Pending',
            _round1(r.rate ?? 0),
            r.email,
            r.details,
          ],
        )
        .toList();
  }

  static List<List<Object?>> rowsFromFoodOrders(
    List<FoodCheckoutModel> orders,
    Map<int, RestaurantModel> restaurants,
  ) {
    return orders.map((o) {
      final restaurantName = o.restaurantId == null
          ? null
          : restaurants[o.restaurantId!]?.name;
      return <Object?>[
        o.id,
        o.formattedCreatedAt,
        o.userEmail,
        restaurantName,
        o.status,
        o.paymentType,
        o.foodAmount,
        o.couponDiscount,
        o.deliveryPrice ?? 0,
        o.grandTotal,
        o.cartId,
        o.driverId,
      ];
    }).toList();
  }

  static double _round1(num v) => double.parse(v.toStringAsFixed(1));

  static Uint8List _buildXlsx({
    required String sheetName,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final safeSheet = _sanitizeSheetName(sheetName);
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('[Content_Types].xml', _contentTypesXml),
      )
      ..addFile(ArchiveFile.string('_rels/.rels', _relsXml))
      ..addFile(
        ArchiveFile.string('xl/workbook.xml', _workbookXml(safeSheet)),
      )
      ..addFile(
        ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelsXml),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet1.xml',
          _sheetXml(headers: headers, rows: rows),
        ),
      )
      ..addFile(ArchiveFile.string('xl/styles.xml', _stylesXml));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _sanitizeSheetName(String name) {
    var cleaned = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (cleaned.isEmpty) cleaned = 'Sheet1';
    if (cleaned.length > 31) cleaned = cleaned.substring(0, 31);
    return cleaned;
  }

  static String _sheetXml({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buf = StringBuffer();
    buf.write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView tabSelected="1" workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>',
    );

    buf.write('<cols>');
    for (var i = 0; i < headers.length; i++) {
      final width = (headers[i].length + 8).clamp(14, 36);
      buf.write('<col min="${i + 1}" max="${i + 1}" width="$width" customWidth="1"/>');
    }
    buf.write('</cols><sheetData>');

    buf.write('<row r="1">');
    for (var c = 0; c < headers.length; c++) {
      buf.write(_inlineStringCell(_columnLetter(c), 1, headers[c], style: 1));
    }
    buf.write('</row>');

    for (var r = 0; r < rows.length; r++) {
      final excelRow = r + 2;
      final row = rows[r];
      buf.write('<row r="$excelRow">');
      for (var c = 0; c < headers.length; c++) {
        final value = c < row.length ? row[c] : null;
        buf.write(_cell(_columnLetter(c), excelRow, value));
      }
      buf.write('</row>');
    }

    buf.write('</sheetData></worksheet>');
    return buf.toString();
  }

  static String _cell(String col, int row, Object? value) {
    if (value is num) {
      return '<c r="$col$row" t="n"><v>${value.toString()}</v></c>';
    }
    final text = _display(value);
    return _inlineStringCell(col, row, text);
  }

  static String _inlineStringCell(
    String col,
    int row,
    String text, {
    int? style,
  }) {
    final s = style == null ? '' : ' s="$style"';
    return '<c r="$col$row"$s t="inlineStr"><is><t xml:space="preserve">${_escapeXml(text)}</t></is></c>';
  }

  static String _display(Object? value) {
    if (value == null) return emptyValue;
    final text = value.toString().trim();
    return text.isEmpty ? emptyValue : text;
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _columnLetter(int index) {
    var n = index + 1;
    final chars = <String>[];
    while (n > 0) {
      final rem = (n - 1) % 26;
      chars.add(String.fromCharCode(65 + rem));
      n = (n - 1) ~/ 26;
    }
    return chars.reversed.join();
  }

  static const _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _relsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbookXml(String sheetName) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_escapeXml(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const _workbookRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const _stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2">'
      '<font><sz val="11"/><color theme="1"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf/></cellStyleXfs>'
      '<cellXfs count="2"><xf xfId="0"/><xf xfId="0" fontId="1" applyFont="1"/></cellXfs>'
      '</styleSheet>';
}
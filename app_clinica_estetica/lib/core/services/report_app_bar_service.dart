import 'package:flutter/material.dart';

class ReportAppBarService extends ChangeNotifier {
  static final ReportAppBarService _instance = ReportAppBarService._internal();
  factory ReportAppBarService() => _instance;
  ReportAppBarService._internal();

  bool _showActions = false;
  bool _hideLeading = false;
  String? _customTitle;
  VoidCallback? _onPdfPressed;
  VoidCallback? _onCalendarPressed;

  bool get showActions => _showActions;
  bool get hideLeading => _hideLeading;
  String? get customTitle => _customTitle;
  VoidCallback? get onPdfPressed => _onPdfPressed;
  VoidCallback? get onCalendarPressed => _onCalendarPressed;

  void setActions({
    String? title,
    VoidCallback? onPdf,
    VoidCallback? onCalendar,
  }) {
    _customTitle = title;
    _onPdfPressed = onPdf;
    _onCalendarPressed = onCalendar;
    _showActions = true;
    _hideLeading = false;
    notifyListeners();
  }

  void setTitleOnly(String title, {bool hideLeading = false}) {
    _customTitle = title;
    _onPdfPressed = null;
    _onCalendarPressed = null;
    _showActions = false;
    _hideLeading = hideLeading;
    notifyListeners();
  }

  void reset() {
    _customTitle = null;
    _onPdfPressed = null;
    _onCalendarPressed = null;
    _showActions = false;
    _hideLeading = false;
    notifyListeners();
  }
}

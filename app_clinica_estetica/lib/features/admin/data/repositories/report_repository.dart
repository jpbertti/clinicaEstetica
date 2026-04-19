
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';
import 'package:flutter/material.dart';

abstract class IReportRepository {
  Future<FinancialReport> getFinancialReport(DateTimeRange range);
  Future<PatientReport> getPatientReport(DateTimeRange range);
  Future<OperationalReport> getOperationalReport(DateTimeRange range);
  Future<List<ProfessionalPerformance>> getProfessionalPerformance(DateTimeRange range);
  Future<List<ServicePerformance>> getServicePerformance(DateTimeRange range);
  Future<FinancialStatement> getFinancialStatement(DateTimeRange range);
  Future<StockReport> getStockReport(DateTimeRange range);
  Future<PeakTimeReport> getPeakTimeReport(DateTimeRange range);
  Future<List<ProductSale>> getProductSales(DateTimeRange range, {String? professionalId});
  Future<List<ServiceSale>> getServiceSales(DateTimeRange range, {String? professionalId});
  Future<CommissionReport> getCommissionsReport(DateTimeRange range);
  Future<List<Map<String, dynamic>>> getProfessionals();
}


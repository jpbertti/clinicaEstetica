
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';
import 'package:flutter/material.dart';

abstract class IReportRepository {
  Future<FinancialReport> getFinancialReport(DateTimeRange range, {String? professionalId});
  Future<PatientReport> getPatientReport(DateTimeRange range, {String? professionalId});
  Future<OperationalReport> getOperationalReport(DateTimeRange range, {String? professionalId});
  Future<List<ProfessionalPerformance>> getProfessionalPerformance(DateTimeRange range, {String? professionalId});
  Future<List<ServicePerformance>> getServicePerformance(DateTimeRange range, {String? professionalId});
  Future<FinancialStatement> getFinancialStatement(DateTimeRange range, {String? professionalId});
  Future<StockReport> getStockReport(DateTimeRange range, {String? professionalId});
  Future<PeakTimeReport> getPeakTimeReport(DateTimeRange range, {String? professionalId});
  Future<List<ProductSale>> getProductSales(DateTimeRange range, {String? professionalId});
  Future<List<ServiceSale>> getServiceSales(DateTimeRange range, {String? professionalId});
  Future<CommissionReport> getCommissionsReport(DateTimeRange range, {String? professionalId});
  Future<List<Map<String, dynamic>>> getProfessionals();
}


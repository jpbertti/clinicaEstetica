
class FinancialReport {
  final double totalRevenue;
  final double totalTaxes;
  final double totalCommissions;
  final double previousPeriodRevenue;
  final List<TimeSeriesData> revenueByDay;
  final Map<String, double> revenueByProfessional;
  final Map<String, double> revenueByService;
  final Map<String, double> revenueByPaymentMethod; // 'pix', 'convenio', etc.
  final Map<String, double> revenueByConvenio; // Specific names
  final int totalAppointments;
  
  double get netRevenue => totalRevenue - totalTaxes;
  double get operatingProfit => netRevenue - totalCommissions;

  double get revenueGrowth => previousPeriodRevenue == 0 
      ? 0 
      : ((totalRevenue - previousPeriodRevenue) / previousPeriodRevenue) * 100;

  double get averageTicket => totalAppointments == 0 ? 0 : totalRevenue / totalAppointments;

  FinancialReport({
    required this.totalRevenue,
    required this.totalTaxes,
    required this.totalCommissions,
    required this.previousPeriodRevenue,
    required this.revenueByDay,
    required this.revenueByProfessional,
    required this.revenueByService,
    required this.revenueByPaymentMethod,
    required this.revenueByConvenio,
    required this.totalAppointments,
  });
}

class FinancialStatement {
  final double income;
  final double expenses;
  final double totalTaxes;
  final double totalCommissions;
  final List<CashFlowData> cashFlow; // Income vs Expenses over time
  final Map<String, double> expensesByCategory;

  double get netRevenue => income - totalTaxes;
  double get netProfit => netRevenue - totalCommissions - expenses;
  double get profitMargin => income == 0 ? 0 : (netProfit / income) * 100;

  FinancialStatement({
    required this.income,
    required this.expenses,
    required this.totalTaxes,
    required this.totalCommissions,
    required this.cashFlow,
    required this.expensesByCategory,
  });
}

class CashFlowData {
  final DateTime date;
  final double income;
  final double expenses;

  CashFlowData(this.date, this.income, this.expenses);
}

class PatientReport {
  final int totalPatients;
  final int newPatients;
  final int inactivePatients;
  final double retentionRate;
  final List<TimeSeriesData> newPatientsByDay;

  PatientReport({
    required this.totalPatients,
    required this.newPatients,
    required this.inactivePatients,
    required this.retentionRate,
    required this.newPatientsByDay,
  });
}

class OperationalReport {
  final int totalAgendamentos;
  final int concluidos;
  final int cancelados;
  final int ausentes;
  final double taxaOcupacao;
  final List<TimeSeriesData> appointmentsByDay;

  double get noShowRate => totalAgendamentos == 0 
      ? 0 
      : (ausentes / totalAgendamentos) * 100;

  OperationalReport({
    required this.totalAgendamentos,
    required this.concluidos,
    required this.cancelados,
    required this.ausentes,
    required this.taxaOcupacao,
    required this.appointmentsByDay,
  });
}

class TimeSeriesData {
  final DateTime date;
  final double value;

  TimeSeriesData(this.date, this.value);
}

class ProfessionalPerformance {
  final String id;
  final String nome;
  final double faturamento;
  final int atendimentos;
  final double taxaOcupacao;

  ProfessionalPerformance({
    required this.id,
    required this.nome,
    required this.faturamento,
    required this.atendimentos,
    required this.taxaOcupacao,
  });
}

class ServicePerformance {
  final String id;
  final String nome;
  final int count;
  final double totalRevenue;

  ServicePerformance({
    required this.id,
    required this.nome,
    required this.count,
    required this.totalRevenue,
  });
}
class StockReport {
  final int totalSalesCount;
  final double totalRevenue;
  final double totalCommissions;
  final List<StockMovementData> movements;
  final Map<String, double> salesByProduct; // Curva ABC
  final Map<String, double> commissionsByProfessional;
  final List<ProductAlert> lowStockProducts;

  StockReport({
    required this.totalSalesCount,
    required this.totalRevenue,
    required this.totalCommissions,
    required this.movements,
    required this.salesByProduct,
    required this.commissionsByProfessional,
    required this.lowStockProducts,
  });
}

class StockMovementData {
  final String productName;
  final String type; // 'venda', 'ajuste', 'entrada'
  final int quantity;
  final double? value;
  final double? commissionValue; // Bruta
  final double? commissionValueLiquido; // Líquida
  final DateTime date;
  final String? clientName;
  final String? professionalName;

  StockMovementData({
    required this.productName,
    required this.type,
    required this.quantity,
    this.value,
    this.commissionValue,
    this.commissionValueLiquido,
    required this.date,
    this.clientName,
    this.professionalName,
  });
}

class ProductAlert {
  final String name;
  final int currentStock;
  final int minStock;

  ProductAlert({required this.name, required this.currentStock, required this.minStock});
}
class PeakTimeReport {
  final List<PeakTimeData> hourlyData;
  final List<PeakTimeData> dailyData;

  PeakTimeReport({
    required this.hourlyData,
    required this.dailyData,
  });
}

class PeakTimeData {
  final String label; // "08:00" ou "Segunda-feira"
  final int appointmentsCount;
  final double totalRevenue;
  final double grossProfit;

  double get averageTicket => appointmentsCount == 0 ? 0 : totalRevenue / appointmentsCount;

  PeakTimeData({
    required this.label,
    required this.appointmentsCount,
    required this.totalRevenue,
    required this.grossProfit,
  });
}

class ProductSale {
  final String id;
  final String productName;
  final String clientName;
  final String professionalName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String paymentMethod;
  final double? comissaoAplicada;
  final double? valorComissaoBruta;
  final double? valorComissaoLiquida;
  final DateTime date;

  ProductSale({
    required this.id,
    required this.productName,
    required this.clientName,
    required this.professionalName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.paymentMethod,
    this.comissaoAplicada,
    this.valorComissaoBruta,
    this.valorComissaoLiquida,
    required this.date,
  });
}

class ServiceSale {
  final String id;
  final String serviceName;
  final String clientName;
  final String professionalName;
  final double price;
  final String status;
  final String paymentMethod;
  final DateTime date;

  ServiceSale({
    required this.id,
    required this.serviceName,
    required this.clientName,
    required this.professionalName,
    required this.price,
    required this.status,
    required this.paymentMethod,
    required this.date,
  });
}

class CommissionReport {
  final double totalCommissionedRevenue; // Base para comissão
  final double totalCommissionPayout; // Valor total a pagar
  final List<ProfessionalCommission> professionals;
  final List<TimeSeriesData> payoutsByDay;

  CommissionReport({
    required this.totalCommissionedRevenue,
    required this.totalCommissionPayout,
    required this.professionals,
    required this.payoutsByDay,
  });
}

class ProfessionalCommission {
  final String professionalId;
  final String professionalName;
  final double totalRevenue; // Faturamento total gerado
  final double commissionBase; // Faturamento após descontos (taxas)
  final double commissionAmount; // Valor da comissão Líquida (R$)
  final double commissionAmountBruta; // NOVO: Valor da comissão Bruta (R$)
  final double percentage; // Porcentagem média ou fixa
  final int appointmentsCount;
  final int productsCount;

  ProfessionalCommission({
    required this.professionalId,
    required this.professionalName,
    required this.totalRevenue,
    required this.commissionBase,
    required this.commissionAmount,
    required this.commissionAmountBruta,
    required this.percentage,
    required this.appointmentsCount,
    required this.productsCount,
  });
}


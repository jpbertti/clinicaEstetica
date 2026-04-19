import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/report_repository.dart';

class SupabaseReportRepository implements IReportRepository {
  final _supabase = Supabase.instance.client;

  @override
  Future<FinancialReport> getFinancialReport(DateTimeRange range) async {
    try {
      // 1. Fetch current period data (Appointments)
      final currentData = await _supabase
          .from('agendamentos')
          .select('valor_total, data_hora, status, forma_pagamento, parcelas, valor_comissao, convenio_nome, profissional:perfis!profissional_id(nome_completo), servicos:servicos!servico_id(nome)')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      // 2. Fetch Package Sales
      final packagesData = await _supabase
          .from('pacotes_contratados')
          .select('valor_pago, criado_em, status, template:pacotes_templates(comissao_percentual)')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());


      // 3. Fetch Product Sales
      final productsData = await _supabase
          .from('vendas_produtos')
          .select('valor_total, criado_em, forma_pagamento, valor_comissao_liquida')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      // 4. Fetch previous period for growth
      final duration = range.end.difference(range.start);
      final prevStart = range.start.subtract(duration);
      final prevEnd = range.start.subtract(const Duration(seconds: 1));
      
      final previousData = await _supabase
          .from('agendamentos')
          .select('valor_total')
          .eq('status', 'concluido')
          .gte('data_hora', prevStart.toUtc().toIso8601String())
          .lte('data_hora', prevEnd.toUtc().toIso8601String());

      double totalRevenue = 0;
      double totalTaxes = 0;
      double totalCommissions = 0;
      
      Map<String, double> revByDay = {};
      Map<String, double> revByProf = {};
      Map<String, double> revByServ = {};
      Map<String, double> revByMethod = {};
      Map<String, double> revByConvenio = {};
      int concluidos = 0;

      // Process Appointments
      for (var row in (currentData as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        if (row['status'] == 'concluido') {
          final val = (row['valor_total'] as num?)?.toDouble() ?? 0;
          final comm = (row['valor_comissao'] as num?)?.toDouble() ?? 0;
          final method = row['forma_pagamento'] as String?;
          final parcelas = (row['parcelas'] as num?)?.toInt() ?? 1;
          
          final tax = _calculateTaxes(val, method, parcelas);
          
          totalRevenue += val;
          totalTaxes += tax;
          totalCommissions += comm;
          concluidos++;

          final date = DateTime.parse(row['data_hora']).toLocal();
          final dayKey = DateFormat('yyyy-MM-dd').format(date);
          revByDay[dayKey] = (revByDay[dayKey] ?? 0) + val;

          final profName = row['profissional']?['nome_completo'] ?? 'Desconhecido';
          revByProf[profName] = (revByProf[profName] ?? 0) + val;

          final srvName = row['servicos']?['nome'] ?? 'Desconhecido';
          revByServ[srvName] = (revByServ[srvName] ?? 0) + val;

          final methodDisplay = method ?? 'Não Informado';
          revByMethod[methodDisplay] = (revByMethod[methodDisplay] ?? 0) + val;

          if (method == 'convenio' && row['convenio_nome'] != null) {
            final convName = row['convenio_nome'];
            revByConvenio[convName] = (revByConvenio[convName] ?? 0) + val;
          }
        }
      }

      // Process Packages
      for (var row in (packagesData as List?) ?? []) {
        if (row is! Map<String, dynamic> || row['status'] == 'cancelado') continue;
        final val = (row['valor_pago'] as num?)?.toDouble() ?? 0;
        final templateData = row['template'] as Map<String, dynamic>?;
        final commPercent = (templateData?['comissao_percentual'] as num?)?.toDouble() ?? 0;
        final comm = val * (commPercent / 100);

        totalRevenue += val;
        totalCommissions += comm;
        
        final date = DateTime.parse(row['criado_em']).toLocal();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        revByDay[dayKey] = (revByDay[dayKey] ?? 0) + val;
      }

      // Process Products
      for (var row in (productsData as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final val = (row['valor_total'] as num?)?.toDouble() ?? 0;
        final comm = (row['valor_comissao_liquida'] as num?)?.toDouble() ?? 0; // NOVO: Persistido
        final method = row['forma_pagamento'] as String?;
        final tax = _calculateTaxes(val, method, 1);

        totalRevenue += val;
        totalTaxes += tax;
        totalCommissions += comm; // Agora incluído no total de comissões!
        
        final date = DateTime.parse(row['criado_em']).toLocal();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        revByDay[dayKey] = (revByDay[dayKey] ?? 0) + val;
      }

      double prevRevenue = 0;
      for (var row in (previousData as List?) ?? []) {
        if (row is Map<String, dynamic>) {
          prevRevenue += (row['valor_total'] as num?)?.toDouble() ?? 0;
        }
      }

      final timeSeries = revByDay.entries.map((e) => TimeSeriesData(DateTime.parse(e.key), e.value)).toList();
      timeSeries.sort((a, b) => a.date.compareTo(b.date));

      return FinancialReport(
        totalRevenue: totalRevenue,
        totalTaxes: totalTaxes,
        totalCommissions: totalCommissions,
        previousPeriodRevenue: prevRevenue,
        revenueByDay: timeSeries,
        revenueByProfessional: revByProf,
        revenueByService: revByServ,
        revenueByPaymentMethod: revByMethod,
        revenueByConvenio: revByConvenio,
        totalAppointments: concluidos,
      );
    } catch (e) {
      rethrow;
    }
  }

  double _calculateTaxes(double valorTotal, String? formaPagamento, int parcelas) {
    if (formaPagamento == null) return 0;
    
    switch (formaPagamento) {
      case 'pix':
        return valorTotal * (AppConfig.taxaPix / 100);
      case 'cartao_debito':
        return valorTotal * (AppConfig.taxaDebito / 100);
      case 'cartao_credito':
        if (parcelas > 1) {
          return valorTotal * (AppConfig.taxaCreditoParcelado / 100);
        } else {
          return valorTotal * (AppConfig.taxaCredito / 100);
        }
      default:
        return 0;
    }
  }

  @override
  Future<PatientReport> getPatientReport(DateTimeRange range) async {
    try {
      // 1. Total patients
      final totalRes = await _supabase.from('perfis').select('count').eq('tipo', 'cliente').single();
      final totalPatients = (totalRes['count'] ?? 0) as int;

      // 2. New patients in range
      final newPatientsData = await _supabase
          .from('perfis')
          .select('id, criado_em')
          .eq('tipo', 'cliente')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      Map<String, int> newsByDay = {};
      for (var row in (newPatientsData as List?) ?? []) {
        if (row is! Map<String, dynamic> || row['criado_em'] == null) continue;
        final date = DateTime.parse(row['criado_em']).toLocal();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        newsByDay[dayKey] = (newsByDay[dayKey] ?? 0) + 1;
      }

      final timeSeries = newsByDay.entries.map((e) => TimeSeriesData(DateTime.parse(e.key), e.value.toDouble())).toList();
      timeSeries.sort((a, b) => a.date.compareTo(b.date));

      // 3. Retention Rate & Recurring Patients
      // Patients who have more than 1 appointment in the period
      final recurringData = await _supabase
          .from('agendamentos')
          .select('cliente_id, status')
          .eq('status', 'concluido');
      
      Map<String, int> clientAppts = {};
      for (var row in (recurringData as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final cid = row['cliente_id'];
        if (cid != null) {
          clientAppts[cid.toString()] = (clientAppts[cid.toString()] ?? 0) + 1;
        }
      }
      final recurringCount = clientAppts.values.where((c) => c > 1).length;
      final retention = totalPatients == 0 ? 0.0 : (recurringCount / totalPatients) * 100;

      // 4. Inactive (no login for 90 days)
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final inactiveRes = await _supabase
          .from('perfis')
          .select('count')
          .eq('tipo', 'cliente')
          .lt('ultimo_login', threeMonthsAgo.toUtc().toIso8601String())
          .single();
      
      return PatientReport(
        totalPatients: totalPatients,
        newPatients: (newPatientsData as List).length,
        inactivePatients: (inactiveRes['count'] ?? 0) as int,
        retentionRate: retention,
        newPatientsByDay: timeSeries,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<OperationalReport> getOperationalReport(DateTimeRange range) async {
    try {
      final data = await _supabase
          .from('agendamentos')
          .select('status, data_hora')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      int concluidos = 0;
      int cancelados = 0;
      int ausentes = 0;
      Map<String, int> countByDay = {};

      for (var row in (data as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final status = row['status'];
        if (status == 'concluido') concluidos++;
        if (status == 'cancelado') cancelados++;
        if (status == 'ausente') ausentes++;

        final dateStr = row['data_hora'];
        if (dateStr != null) {
          final date = DateTime.parse(dateStr).toLocal();
          final dayKey = DateFormat('yyyy-MM-dd').format(date);
          countByDay[dayKey] = (countByDay[dayKey] ?? 0) + 1;
        }
      }

      final timeSeries = countByDay.entries.map((e) => TimeSeriesData(DateTime.parse(e.key), e.value.toDouble())).toList();
      timeSeries.sort((a, b) => a.date.compareTo(b.date));

      return OperationalReport(
        totalAgendamentos: (data as List).length,
        concluidos: concluidos,
        cancelados: cancelados,
        ausentes: ausentes,
        taxaOcupacao: 0, // Would need metadata about business hours
        appointmentsByDay: timeSeries,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ProfessionalPerformance>> getProfessionalPerformance(DateTimeRange range) async {
    try {
      final data = await _supabase
          .from('agendamentos')
          .select('valor_total, status, profissional:perfis!profissional_id(id, nome_completo)')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      Map<String, Map<String, dynamic>> stats = {};

      for (var row in (data as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final prof = row['profissional'];
        if (prof is! Map<String, dynamic>) continue;
        final profId = prof['id']?.toString();
        final profNome = prof['nome_completo']?.toString() ?? 'Desconhecido';

        if (profId == null) continue;

        if (!stats.containsKey(profId)) {
          stats[profId] = {'id': profId, 'nome': profNome, 'fat': 0.0, 'atend': 0};
        }

        if (row['status'] == 'concluido') {
          stats[profId]!['fat'] += (row['valor_total'] as num?)?.toDouble() ?? 0;
          stats[profId]!['atend'] += 1;
        }
      }

      return stats.values.map((s) => ProfessionalPerformance(
        id: s['id'],
        nome: s['nome'],
        faturamento: s['fat'],
        atendimentos: s['atend'],
        taxaOcupacao: 0,
      )).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServicePerformance>> getServicePerformance(DateTimeRange range) async {
    try {
      final data = await _supabase
          .from('agendamentos')
          .select('valor_total, status, servicos:servicos!servico_id(id, nome)')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      Map<String, Map<String, dynamic>> stats = {};

      for (var row in (data as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final srv = row['servicos'];
        if (srv is! Map<String, dynamic>) continue;
        final srvId = srv['id']?.toString();
        final srvNome = srv['nome']?.toString() ?? 'Desconhecido';

        if (srvId == null) continue;

        if (!stats.containsKey(srvId)) {
          stats[srvId] = {'id': srvId, 'nome': srvNome, 'count': 0, 'fat': 0.0};
        }

        if (row['status'] == 'concluido') {
          stats[srvId]!['count'] += 1;
          stats[srvId]!['fat'] += (row['valor_total'] as num?)?.toDouble() ?? 0;
        }
      }

      return stats.values.map((s) => ServicePerformance(
        id: s['id'],
        nome: s['nome'],
        count: s['count'],
        totalRevenue: s['fat'],
      )).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<FinancialStatement> getFinancialStatement(DateTimeRange range) async {
    try {
      // 1. Income (Agendamentos, Pacotes, Produtos)
      final appointmentsData = await _supabase
          .from('agendamentos')
          .select('valor_total, data_hora, forma_pagamento, parcelas, valor_comissao, status')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      final packagesData = await _supabase
          .from('pacotes_contratados')
          .select('valor_pago, criado_em, status, template:pacotes_templates(comissao_percentual)')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      final productsData = await _supabase
          .from('vendas_produtos')
          .select('valor_total, criado_em, forma_pagamento')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      // 2. Expenses (Tabela Contas)
      final expenseData = await _supabase
          .from('contas')
          .select('valor, data_vencimento, categoria, tipo_conta')
          .eq('tipo_conta', 'pagar')
          .gte('data_vencimento', range.start.toIso8601String())
          .lte('data_vencimento', range.end.toIso8601String());

      double totalIncome = 0;
      double totalTaxes = 0;
      double totalCommissions = 0;
      Map<String, double> incomeByDay = {};
      
      // Process Appointments
      for (var row in (appointmentsData as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        if (row['status'] == 'concluido') {
          final val = (row['valor_total'] as num?)?.toDouble() ?? 0;
          final comm = (row['valor_comissao'] as num?)?.toDouble() ?? 0;
          final method = row['forma_pagamento'] as String?;
          final parcelas = (row['parcelas'] as num?)?.toInt() ?? 1;
          final tax = _calculateTaxes(val, method, parcelas);
          
          totalIncome += val;
          totalTaxes += tax;
          totalCommissions += comm;

          final date = DateTime.parse(row['data_hora']).toLocal();
          final key = DateFormat('yyyy-MM-dd').format(date);
          incomeByDay[key] = (incomeByDay[key] ?? 0) + val;
        }
      }

      // Process Packages
      for (var row in (packagesData as List?) ?? []) {
        if (row is! Map<String, dynamic> || row['status'] == 'cancelado') continue;
        final val = (row['valor_pago'] as num?)?.toDouble() ?? 0;
        final templateData = row['template'] as Map<String, dynamic>?;
        final commPercent = (templateData?['comissao_percentual'] as num?)?.toDouble() ?? 0;
        final comm = val * (commPercent / 100);

        totalIncome += val;
        totalCommissions += comm;
        
        final date = DateTime.parse(row['criado_em']).toLocal();
        final key = DateFormat('yyyy-MM-dd').format(date);
        incomeByDay[key] = (incomeByDay[key] ?? 0) + val;
      }

      // Process Products
      for (var row in (productsData as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final val = (row['valor_total'] as num?)?.toDouble() ?? 0;
        final method = row['forma_pagamento'] as String?;
        final tax = _calculateTaxes(val, method, 1);

        totalIncome += val;
        totalTaxes += tax;
        
        final date = DateTime.parse(row['criado_em']).toLocal();
        final key = DateFormat('yyyy-MM-dd').format(date);
        incomeByDay[key] = (incomeByDay[key] ?? 0) + val;
      }

      double totalExpenses = 0;
      Map<String, double> expenseByDay = {};
      Map<String, double> expenseByCat = {};
      for (var row in (expenseData as List?) ?? []) {
        if (row is! Map<String, dynamic>) continue;
        final val = (row['valor'] as num?)?.toDouble() ?? 0;
        totalExpenses += val;
        final dateStr = row['data_vencimento'];
        if (dateStr != null) {
          final date = DateTime.parse(dateStr).toLocal();
          final key = DateFormat('yyyy-MM-dd').format(date);
          expenseByDay[key] = (expenseByDay[key] ?? 0) + val;
        }
        final cat = row['categoria'] ?? 'Outros';
        expenseByCat[cat] = (expenseByCat[cat] ?? 0) + val;
      }

      // Generate cash flow data (merging keys)
      final allDays = {...incomeByDay.keys, ...expenseByDay.keys}.toList();
      allDays.sort();
      final cashFlow = allDays.map((day) => CashFlowData(
        DateTime.parse(day),
        incomeByDay[day] ?? 0,
        expenseByDay[day] ?? 0,
      )).toList();

      return FinancialStatement(
        income: totalIncome,
        expenses: totalExpenses,
        totalTaxes: totalTaxes,
        totalCommissions: totalCommissions,
        cashFlow: cashFlow,
        expensesByCategory: expenseByCat,
      );
    } catch (e) {
      rethrow;
    }
  }


  @override
  Future<StockReport> getStockReport(DateTimeRange range) async {
    try {
      // 1. Buscar Vendas no período (incluindo comissão persistida)
      final salesData = await _supabase
          .from('vendas_produtos')
          .select('''
            id, quantidade, valor_total, criado_em, 
            valor_comissao_bruta, valor_comissao_liquida, comissao_aplicada,
            produtos(nome), 
            cliente:perfis!cliente_id(nome_completo),
            profissional:perfis!profissional_id(nome_completo)
          ''')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      // 2. Buscar Todos os Produtos para verificar estoque baixo
      final productsData = await _supabase
          .from('produtos')
          .select('nome, estoque_atual, estoque_minimo')
          .eq('ativo', true);

      double totalRevenue = 0;
      double totalCommissions = 0;
      int totalSalesCount = 0;
      List<StockMovementData> movements = [];
      Map<String, double> salesByProduct = {};
      Map<String, double> commissionsByProfessional = {};

      for (var row in (salesData as List?) ?? []) {
        final qty = (row['quantidade'] as num?)?.toInt() ?? 0;
        final val = (row['valor_total'] as num?)?.toDouble() ?? 0.0;
        final prodData = row['produtos'] as Map<String, dynamic>?;
        final prodName = prodData?['nome'] ?? 'Desconhecido';
        
        // Usar valores persistidos
        final rawComm = (row['valor_comissao_bruta'] as num?)?.toDouble() ?? 0.0;
        final netComm = (row['valor_comissao_liquida'] as num?)?.toDouble() ?? 0.0;
        
        final clientName = row['cliente']?['nome_completo'];
        final profName = row['profissional']?['nome_completo'];
        final date = DateTime.parse(row['criado_em']).toLocal();

        totalRevenue += val;
        totalCommissions += netComm; // Mudamos para liquidar no total do relatório de estoque
        totalSalesCount += qty;
        salesByProduct[prodName] = (salesByProduct[prodName] ?? 0) + val;
        
        if (profName != null) {
          commissionsByProfessional[profName] = (commissionsByProfessional[profName] ?? 0) + netComm;
        }

        movements.add(StockMovementData(
          productName: prodName,
          type: 'venda',
          quantity: qty,
          value: val,
          commissionValue: rawComm,
          commissionValueLiquido: netComm,
          date: date,
          clientName: clientName,
          professionalName: profName,
        ));
      }

      // Ordenar movimentos por data decrescente
      movements.sort((a, b) => b.date.compareTo(a.date));

      List<ProductAlert> lowStock = [];
      for (var row in (productsData as List?) ?? []) {
        final atual = (row['estoque_atual'] as num?)?.toInt() ?? 0;
        final min = (row['estoque_minimo'] as num?)?.toInt() ?? 0;
        if (atual <= min) {
          lowStock.add(ProductAlert(
            name: row['nome'],
            currentStock: atual,
            minStock: min,
          ));
        }
      }

      return StockReport(
        totalSalesCount: totalSalesCount,
        totalRevenue: totalRevenue,
        totalCommissions: totalCommissions,
        movements: movements,
        salesByProduct: salesByProduct,
        commissionsByProfessional: commissionsByProfessional,
        lowStockProducts: lowStock,
      );
    } catch (e) {
      debugPrint('Erro getStockReport: $e');
      rethrow;
    }
  }

  @override
  Future<PeakTimeReport> getPeakTimeReport(DateTimeRange range) async {
    try {
      final res = await _supabase
          .from('agendamentos')
          .select('data_hora, valor_total, valor_comissao, status')
          .gte('data_hora', range.start.toIso8601String())
          .lte('data_hora', range.end.toIso8601String())
          .not('status', 'eq', 'cancelado');

      final data = (res as List?) ?? [];

      final Map<int, PeakTimeData> hourlyMap = {};
      final Map<int, PeakTimeData> dailyMap = {};

      final weekDays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

      for (var row in data) {
        final dt = DateTime.parse(row['data_hora']).toLocal();
        final revenue = (row['valor_total'] as num?)?.toDouble() ?? 0.0;
        final commission = (row['valor_comissao'] as num?)?.toDouble() ?? 0.0;
        final profit = revenue - commission;

        // Horários
        final hour = dt.hour;
        if (!hourlyMap.containsKey(hour)) {
          hourlyMap[hour] = PeakTimeData(
            label: '${hour.toString().padLeft(2, '0')}:00',
            appointmentsCount: 0,
            totalRevenue: 0,
            grossProfit: 0,
          );
        }
        final hData = hourlyMap[hour]!;
        hourlyMap[hour] = PeakTimeData(
          label: hData.label,
          appointmentsCount: hData.appointmentsCount + 1,
          totalRevenue: hData.totalRevenue + revenue,
          grossProfit: hData.grossProfit + profit,
        );

        // Dias (dt.weekday 1-7)
        final day = dt.weekday;
        if (!dailyMap.containsKey(day)) {
          dailyMap[day] = PeakTimeData(
            label: weekDays[day - 1],
            appointmentsCount: 0,
            totalRevenue: 0,
            grossProfit: 0,
          );
        }
        final dData = dailyMap[day]!;
        dailyMap[day] = PeakTimeData(
          label: dData.label,
          appointmentsCount: dData.appointmentsCount + 1,
          totalRevenue: dData.totalRevenue + revenue,
          grossProfit: dData.grossProfit + profit,
        );
      }

      final hourlyList = hourlyMap.values.toList()..sort((a, b) => a.label.compareTo(b.label));
      
      // Criar lista de dias na ordem da semana, preenchendo vazios se necessário
      final List<PeakTimeData> dailyList = [];
      for (int i = 0; i < weekDays.length; i++) {
        final dayIndex = i + 1; // 1 = Monday
        if (dailyMap.containsKey(dayIndex)) {
          dailyList.add(dailyMap[dayIndex]!);
        } else {
          dailyList.add(PeakTimeData(
            label: weekDays[i],
            appointmentsCount: 0,
            totalRevenue: 0,
            grossProfit: 0,
          ));
        }
      }

      return PeakTimeReport(hourlyData: hourlyList, dailyData: dailyList);
    } catch (e) {
      debugPrint('Erro getPeakTimeReport: $e');
      rethrow;
    }
  }

  @override
  Future<List<ProductSale>> getProductSales(DateTimeRange range, {String? professionalId}) async {
    try {
      var query = _supabase
          .from('vendas_produtos')
          .select('''
            id, quantidade, valor_unitario, valor_total, criado_em, forma_pagamento,
            comissao_aplicada, valor_comissao_bruta, valor_comissao_liquida,
            produtos(nome),
            cliente:perfis!cliente_id(nome_completo),
            profissional:perfis!profissional_id(nome_completo)
          ''')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      if (professionalId != null) {
        query = query.eq('profissional_id', professionalId);
      }

      final response = await query.order('criado_em', ascending: false);
      final dataList = (response as List?) ?? [];

      return dataList.map((row) {
        final productMap = row['produtos'] as Map<String, dynamic>?;
        final clientMap = row['cliente'] as Map<String, dynamic>?;
        final profMap = row['profissional'] as Map<String, dynamic>?;

        return ProductSale(
          id: row['id']?.toString() ?? '',
          productName: productMap?['nome']?.toString() ?? 'Produto Removido',
          clientName: clientMap?['nome_completo']?.toString() ?? 'Consumidor Final',
          professionalName: profMap?['nome_completo']?.toString() ?? 'Não Vinculado',
          quantity: (row['quantidade'] as num?)?.toInt() ?? 0,
          unitPrice: (row['valor_unitario'] as num?)?.toDouble() ?? 0.0,
          totalPrice: (row['valor_total'] as num?)?.toDouble() ?? 0.0,
          paymentMethod: row['forma_pagamento']?.toString() ?? 'Não Informado',
          comissaoAplicada: (row['comissao_aplicada'] as num?)?.toDouble(),
          valorComissaoBruta: (row['valor_comissao_bruta'] as num?)?.toDouble(),
          valorComissaoLiquida: (row['valor_comissao_liquida'] as num?)?.toDouble(),
          date: DateTime.parse(row['criado_em']).toLocal(),
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceSale>> getServiceSales(DateTimeRange range, {String? professionalId}) async {
    try {
      var query = _supabase
          .from('agendamentos')
          .select('''
            id, valor_total, data_hora, status, forma_pagamento,
            servicos(nome),
            cliente:perfis!cliente_id(nome_completo),
            profissional:perfis!profissional_id(nome_completo)
          ''')
          .eq('status', 'concluido')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      if (professionalId != null) {
        query = query.eq('profissional_id', professionalId);
      }

      final response = await query.order('data_hora', ascending: false);
      final dataList = (response as List?) ?? [];

      return dataList.map((row) {
        final serviceMap = row['servicos'] as Map<String, dynamic>?;
        final clientMap = row['cliente'] as Map<String, dynamic>?;
        final profMap = row['profissional'] as Map<String, dynamic>?;

        return ServiceSale(
          id: row['id']?.toString() ?? '',
          serviceName: serviceMap?['nome']?.toString() ?? 'Serviço Removido',
          clientName: clientMap?['nome_completo']?.toString() ?? 'Consumidor',
          professionalName: profMap?['nome_completo']?.toString() ?? 'Não Vinculado',
          price: (row['valor_total'] as num?)?.toDouble() ?? 0.0,
          status: row['status']?.toString() ?? 'concluido',
          paymentMethod: row['forma_pagamento']?.toString() ?? 'Não Informado',
          date: DateTime.parse(row['data_hora']).toLocal(),
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CommissionReport> getCommissionsReport(DateTimeRange range) async {
    try {
      // 1. Buscar Profissionais
      final professionalsData = await _supabase
          .from('perfis')
          .select('id, nome_completo, comissao_agendamentos_percentual, comissao_produtos_percentual')
          .eq('tipo', 'profissional')
          .eq('ativo', true);

      // 2. Buscar Agendamentos Concluídos
      final appointmentsData = await _supabase
          .from('agendamentos')
          .select('valor_total, forma_pagamento, profissional_id, data_hora')
          .eq('status', 'concluido')
          .gte('data_hora', range.start.toUtc().toIso8601String())
          .lte('data_hora', range.end.toUtc().toIso8601String());

      // 3. Buscar Vendas de Produtos
      final productSalesData = await _supabase
          .from('vendas_produtos')
          .select('valor_total, forma_pagamento, profissional_id, criado_em')
          .gte('criado_em', range.start.toUtc().toIso8601String())
          .lte('criado_em', range.end.toUtc().toIso8601String());

      double totalCommissionedRevenue = 0;
      double totalCommissionPayout = 0;

      // Helper to determine tax rate
      double getTaxa(String? forma, int? parcelas) {
        if (forma == 'cartao_debito') return AppConfig.taxaDebito;
        if (forma == 'cartao_credito') {
          return (parcelas ?? 1) > 1 ? AppConfig.taxaCreditoParcelado : AppConfig.taxaCredito;
        }
        if (forma == 'pix') return AppConfig.taxaPix;
        return 0.0;
      }
      Map<String, double> payoutsByDay = {};
      Map<String, ProfessionalCommission> profStats = {};

      // Inicializar estatísticas por profissional
      for (var p in (professionalsData as List)) {
        final id = p['id'].toString();
        profStats[id] = ProfessionalCommission(
          professionalId: id,
          professionalName: p['nome_completo'] ?? 'Desconhecido',
          totalRevenue: 0,
          commissionBase: 0,
          commissionAmount: 0,
          commissionAmountBruta: 0,
          percentage: ((p['comissao_agendamentos_percentual'] as num?)?.toDouble() ?? 0), // Base inicial
          appointmentsCount: 0,
          productsCount: 0,
        );
      }

      // Processar Agendamentos
      for (var appt in (appointmentsData as List)) {
        final profId = appt['profissional_id']?.toString();
        if (profId == null || !profStats.containsKey(profId)) continue;

        final valorTotal = (appt['valor_total'] as num?)?.toDouble() ?? 0.0;
        final parcelas = (appt['parcelas'] as num?)?.toInt() ?? 1;
        final taxa = getTaxa(appt['forma_pagamento']?.toString(), parcelas);
        final valorBase = valorTotal * (1 - taxa / 100);
        
        final prof = professionalsData.firstWhere((p) => p['id'].toString() == profId);
        final perc = (prof['comissao_agendamentos_percentual'] as num?)?.toDouble() ?? 0.0;
        final commission = valorBase * (perc / 100);

        final stats = profStats[profId]!;
        profStats[profId] = ProfessionalCommission(
          professionalId: stats.professionalId,
          professionalName: stats.professionalName,
          totalRevenue: stats.totalRevenue + valorTotal,
          commissionBase: stats.commissionBase + valorBase,
          commissionAmount: stats.commissionAmount + commission,
          commissionAmountBruta: stats.commissionAmountBruta + (valorTotal * (perc / 100)),
          percentage: stats.percentage,
          appointmentsCount: stats.appointmentsCount + 1,
          productsCount: stats.productsCount,
        );

        totalCommissionedRevenue += valorBase;
        totalCommissionPayout += commission;

        final date = DateTime.parse(appt['data_hora']).toLocal();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        payoutsByDay[dayKey] = (payoutsByDay[dayKey] ?? 0) + commission;
      }

      // Processar Vendas de Produtos
      for (var sale in (productSalesData as List)) {
        final profId = sale['profissional_id']?.toString();
        if (profId == null || !profStats.containsKey(profId)) continue;

        final valorTotal = (sale['valor_total'] as num?)?.toDouble() ?? 0.0;
        final parcelas = (sale['parcelas'] as num?)?.toInt() ?? 1;
        final taxa = getTaxa(sale['forma_pagamento']?.toString(), parcelas);
        final valorBase = valorTotal * (1 - taxa / 100);
        
        final prof = professionalsData.firstWhere((p) => p['id'].toString() == profId);
        final perc = (prof['comissao_produtos_percentual'] as num?)?.toDouble() ?? 0.0;
        final commission = valorBase * (perc / 100);

        final stats = profStats[profId]!;
        profStats[profId] = ProfessionalCommission(
          professionalId: stats.professionalId,
          professionalName: stats.professionalName,
          totalRevenue: stats.totalRevenue + valorTotal,
          commissionBase: stats.commissionBase + valorBase,
          commissionAmount: stats.commissionAmount + commission,
          commissionAmountBruta: stats.commissionAmountBruta + (valorTotal * (perc / 100)),
          percentage: stats.percentage,
          appointmentsCount: stats.appointmentsCount,
          productsCount: stats.productsCount + 1,
        );

        totalCommissionedRevenue += valorBase;
        totalCommissionPayout += commission;

        final date = DateTime.parse(sale['criado_em']).toLocal();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        payoutsByDay[dayKey] = (payoutsByDay[dayKey] ?? 0) + commission;
      }

      final timeSeries = payoutsByDay.entries.map((e) => TimeSeriesData(DateTime.parse(e.key), e.value)).toList();
      timeSeries.sort((a, b) => a.date.compareTo(b.date));

      return CommissionReport(
        totalCommissionedRevenue: totalCommissionedRevenue,
        totalCommissionPayout: totalCommissionPayout,
        professionals: profStats.values.toList(),
        payoutsByDay: timeSeries,
      );
    } catch (e) {
      debugPrint('Erro getCommissionsReport: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProfessionals() async {
    try {
      final response = await _supabase.from('perfis').select('id, nome_completo').eq('tipo', 'profissional').eq('ativo', true).order('nome_completo');
      return (response as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      rethrow;
    }
  }
}


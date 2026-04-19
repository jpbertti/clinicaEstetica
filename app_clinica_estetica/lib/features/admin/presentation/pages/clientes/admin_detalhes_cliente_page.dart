import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';

class AdminDetalhesClientePage extends StatefulWidget {
  final String clientId;

  const AdminDetalhesClientePage({super.key, required this.clientId});

  @override
  State<AdminDetalhesClientePage> createState() => _AdminDetalhesClientePageState();
}

class _AdminDetalhesClientePageState extends State<AdminDetalhesClientePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _clientData;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _evaluations = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _productPurchases = [];
  bool _isLoading = true;

  final Color primaryGreen = const Color(0xFF2D5A46);
  final Color goldColor = const Color(0xFFC7A36B);
  final Color bgColor = const Color(0xFFF6F4EF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Busca dados do perfil
      final profileResponse = await _supabase
          .from('perfis')
          .select()
          .eq('id', widget.clientId)
          .single();
      
      // Busca agendamentos
      final appointmentsResponse = await _supabase
          .from('agendamentos')
          .select('*, servicos(nome), perfis!profissional_id(nome_completo)')
          .eq('cliente_id', widget.clientId)
          .order('data_hora', ascending: false);

      // Busca avaliações
      final evaluationsResponse = await _supabase
          .from('avaliacoes')
          .select('*, agendamentos(servicos(nome))')
          .eq('cliente_id', widget.clientId)
          .order('criado_em', ascending: false);

      // Busca pacotes contratados
      final packagesResponse = await _supabase
          .from('pacotes_contratados')
          .select('*, pacotes_templates!template_id(titulo)')
          .eq('cliente_id', widget.clientId)
          .order('criado_em', ascending: false);

      // Busca vendas de produtos
      final productsResponse = await _supabase
          .from('vendas_produtos')
          .select('*, produtos(nome, imagem_url)')
          .eq('cliente_id', widget.clientId)
          .order('criado_em', ascending: false);

      setState(() {
        _clientData = profileResponse;
        _appointments = List<Map<String, dynamic>>.from(appointmentsResponse);
        _evaluations = List<Map<String, dynamic>>.from(evaluationsResponse);
        _packages = List<Map<String, dynamic>>.from(packagesResponse);
        _productPurchases = List<Map<String, dynamic>>.from(productsResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar detalhes: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_clientData == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: Text('Cliente não encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho de Perfil (Alinhado à esquerda)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: [
                   Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor, width: 2),
                      image: _clientData!['avatar_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(_clientData!['avatar_url']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _clientData!['avatar_url'] == null
                        ? Icon(Icons.person, size: 32, color: goldColor)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _clientData!['nome_completo'],
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        Text(
                          'Informações do Perfil',
                          style: TextStyle(
                            fontSize: 12,
                            color: goldColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Superior de Abas (Direto no layout)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: primaryGreen.withOpacity(0.1))),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: primaryGreen,
                unselectedLabelColor: primaryGreen.withOpacity(0.5),
                indicatorColor: goldColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Informações'),
                  Tab(text: 'Agendamentos'),
                  Tab(text: 'Produtos'),
                  Tab(text: 'Pacotes'),
                  Tab(text: 'Avaliações'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPerfilTab(),
                  _buildAgendamentosTab(),
                  _buildProdutosTab(),
                  _buildPacotesTab(),
                  _buildAvaliacoesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfilTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: goldColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _buildInfoItem('Nome Completo', _clientData!['nome_completo'], showCopy: true),
          _buildInfoItem('E-mail', _clientData!['email'], showCopy: true),
          _buildInfoItem('Telefone', _clientData!['telefone'] ?? 'Não informado', showCopy: true),
          _buildInfoItem('Desde', DateFormat('dd/MM/yyyy').format(DateTime.parse(_clientData!['criado_em']).toLocal())),
          const SizedBox(height: 16),
          Text(
            'Observações Internas',
            style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryGreen.withOpacity(0.1)),
            ),
            child: Text(
              _clientData!['observacoes_internas'] ?? 'Nenhuma observação registrada.',
              style: TextStyle(fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAgendamentosTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: goldColor,
      child: _appointments.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Text(
                    'Nenhum agendamento encontrado',
                    style: TextStyle(color: primaryGreen.withOpacity(0.5)),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
        final appt = _appointments[index];
        final DateTime date = DateTime.parse(appt['data_hora']).toLocal();
        final status = (appt['status'] ?? 'pendente').toString();
        
        Color statusColor = Colors.grey;
        if (status == 'concluido') statusColor = primaryGreen;
        if (status == 'cancelado') statusColor = Colors.red;
        if (status == 'pendente') statusColor = goldColor;
        if (status == 'confirmado') statusColor = primaryGreen; // Use Green for confirmed as well
        if (status == 'ausente') statusColor = Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryGreen.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F4EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: primaryGreen.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(date),
                      style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt['servicos']?['nome'] ?? 'Serviço Removido',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                    Text(
                      'Prof: ${appt['perfis']?['nome_completo'] ?? '-'}',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'ausente'
                                ? Icons.person_off
                                : (status == 'cancelado'
                                    ? Icons.cancel
                                    : (status == 'concluido' || status == 'confirmado'
                                        ? Icons.check_circle
                                        : Icons.info)),
                            size: 10,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appt['pago'] == true && status != 'ausente'
                                ? 'PAGO - ${status.toUpperCase()}'
                                : status.toUpperCase(),
                            style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _buildProdutosTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: goldColor,
      child: _productPurchases.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 48, color: primaryGreen.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum produto adquirido',
                        style: TextStyle(color: primaryGreen.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: _productPurchases.length,
              itemBuilder: (context, index) {
                final sale = _productPurchases[index];
                final product = sale['produtos'] as Map<String, dynamic>?;
                final String nome = product?['nome'] ?? 'Produto';
                final String? imgUrl = product?['imagem_url'];
                final int qtd = sale['quantidade'] ?? 0;
                final double total = (sale['valor_total'] ?? 0.0).toDouble();
                final DateTime data = DateTime.parse(sale['criado_em']).toLocal();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryGreen.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: imgUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(imgUrl, fit: BoxFit.cover),
                              )
                            : Icon(Icons.inventory_2_outlined, color: primaryGreen.withOpacity(0.3)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
                            ),
                            Text(
                              'Qtd: $qtd • ${DateFormat('dd/MM/yyyy HH:mm').format(data)}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        NumberFormat.simpleCurrency(locale: 'pt_BR').format(total),
                        style: TextStyle(fontWeight: FontWeight.bold, color: goldColor),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPacotesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: goldColor,
      child: _packages.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: primaryGreen.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum pacote encontrado',
                        style: TextStyle(color: primaryGreen.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final package = _packages[index];
                final String titulo = package['pacotes_templates']?['titulo'] ?? 'Pacote';
                final int total = (package['sessoes_totais'] ?? 0) as int;
                final int realizadas = (package['sessoes_realizadas'] ?? 0) as int;
                final double progresso = total > 0 ? realizadas / total : 0;
                final String status = (package['status'] ?? 'ativo').toString();
                final DateTime data = DateTime.parse(package['criado_em']).toLocal();

                Color statusColor = goldColor;
                if (status == 'finalizado') statusColor = primaryGreen;
                if (status == 'cancelado') statusColor = Colors.red;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryGreen.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status == 'ativo' ? 'EM ANDAMENTO' : status.toUpperCase(),
                              style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progresso das Sessões',
                            style: TextStyle(fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '$realizadas / $total',
                            style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progresso,
                          backgroundColor: primaryGreen.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Contratado em ${DateFormat('dd/MM/yyyy').format(data)}',
                            style: TextStyle(fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                          if (status == 'ativo')
                            TextButton(
                              onPressed: () => _showPackageAppointments(package['id'], titulo),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Ver Detalhes',
                                style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: goldColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAvaliacoesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: goldColor,
      child: _evaluations.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Text(
                    'Nenhuma avaliação registrada',
                    style: TextStyle(color: primaryGreen.withOpacity(0.5)),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: _evaluations.length,
              itemBuilder: (context, index) {
        final eval = _evaluations[index];
        final nota = (eval['nota'] ?? 0) as int;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryGreen.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    eval['agendamentos']?['servicos']?['nome'] ?? 'Serviço',
                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      Icons.star,
                      size: 14,
                      color: i < nota ? goldColor : Colors.grey[300],
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                eval['comentario'] ?? 'Sem comentário.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(DateTime.parse(eval['criado_em'])),
                style: TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _buildInfoItem(String label, String value, {bool showCopy = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: primaryGreen.withOpacity(0.6)),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              if (showCopy && value != 'Não informado')
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copiado com sucesso!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: primaryGreen,
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, size: 18, color: goldColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  tooltip: 'Copiar $label',
                ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  void _showPackageAppointments(String packageId, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<AppointmentModel>>(
              future: SupabaseAppointmentRepository().getAppointmentsByPackageId(packageId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar detalhes: ${snapshot.error}'));
                }

                final appointments = snapshot.data ?? [];

                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(fontFamily: 'Playfair Display', 
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                Text(
                                  'Histórico de Agendamentos',
                                  style: TextStyle(fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (appointments.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text('Nenhum agendamento encontrado para este pacote.'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: appointments.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final app = appointments[index];
                              final dateStr = DateFormat('dd/MM/yyyy').format(app.dataHora);
                              final timeStr = DateFormat('HH:mm').format(app.dataHora);
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        (index + 1).toString().padLeft(2, '0'),
                                        style: TextStyle(fontWeight: FontWeight.bold,
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$dateStr às $timeStr',
                                            style: TextStyle(fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (app.professionalName != null)
                                            Text(
                                              'Profissional: ${app.professionalName}',
                                              style: TextStyle(fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getAppointmentStatusColor(app.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        app.status.toUpperCase(),
                                        style: TextStyle(fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getAppointmentStatusColor(app.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getAppointmentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reservado':
        return goldColor;
      case 'confirmado':
        return Colors.blue;
      case 'finalizado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'falta':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}


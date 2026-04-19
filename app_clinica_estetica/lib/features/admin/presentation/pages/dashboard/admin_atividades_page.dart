import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'admin_atividade_detalhes_page.dart';
import '../../widgets/custom_date_range_picker.dart';

class AdminAtividadesPage extends StatefulWidget {
  const AdminAtividadesPage({super.key});

  @override
  State<AdminAtividadesPage> createState() => _AdminAtividadesPageState();
}

class _AdminAtividadesPageState extends State<AdminAtividadesPage> {
  final _repository = SupabaseDashboardRepository();
  List<DashboardAtividade> _activities = [];
  bool _loading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _newestFirst = true;
  List<Map<String, dynamic>> _adminUsers = [];
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
    _loadActivities();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final users = await _repository.getAdminUsers();
      setState(() => _adminUsers = users);
    } catch (e) {
      debugPrint('Erro ao carregar usuários: $e');
    }
  }

  Future<void> _loadActivities() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.getAllActivities(
        start: _startDate,
        end: _endDate,
        newestFirst: _newestFirst,
        userId: _selectedUserId,
      );
      if (mounted) {
        setState(() {
          _activities = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _marcarTodasComoLidas() async {
    try {
      await _repository.markAllAsRead();
      await _loadActivities();
    } catch (e) {
      debugPrint('Erro ao marcar todas como lidas: $e');
    }
  }

  Future<void> _marcarComoLida(String id) async {
    // Atualização otimista na UI
    setState(() {
      final index = _activities.indexWhere((a) => a.id == id);
      if (index != -1) {
        final at = _activities[index];
        _activities[index] = DashboardAtividade(
          id: at.id,
          tipo: at.tipo,
          titulo: at.titulo,
          descricao: at.descricao,
          criadoEm: at.criadoEm,
          isLida: true, // Seta como lida imediatamente
          metadata: at.metadata,
        );
      }
    });

    try {
      await _repository.markAsRead(id);
    } catch (e) {
      debugPrint('Erro ao marcar como lida: $e');
      // Em caso de erro real, poderíamos recarregar para reverter a UI,
      // mas o fallback do Repo já cuida da maioria dos casos.
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;
    const accentColor = AppColors.accent;
    const backgroundColor = AppColors.background;

    // Separar novas (não lidas) de lidas
    final novas = _activities.where((n) => !n.isLida).toList();
    final anteriores = _activities.where((n) => n.isLida).toList();

    // Agrupar anteriores por data
    Map<String, List<DashboardAtividade>> anterioresAgrupadas = {};
    for (var n in anteriores) {
      final label = n.fullDateLabel;
      if (!anterioresAgrupadas.containsKey(label)) {
        anterioresAgrupadas[label] = [];
      }
      anterioresAgrupadas[label]!.add(n);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, primaryColor, accentColor),
            _buildFilterBar(primaryColor, accentColor),
            _buildUserFilterBar(primaryColor, accentColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _activities.isEmpty
                      ? _buildEmptyState(primaryColor, accentColor)
                      : RefreshIndicator(
                          onRefresh: _loadActivities,
                          color: primaryColor,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (novas.isNotEmpty) ...[
                                  _buildSectionLabel('Novas Atividades', primaryColor),
                                  const SizedBox(height: 16),
                                  ...novas.map((act) => _buildActivityCard(act, primaryColor, accentColor)),
                                  const SizedBox(height: 24),
                                ],
                                
                                if (anteriores.isNotEmpty) ...[
                                  if (novas.isNotEmpty) 
                                    _buildSectionLabel('Anteriores', primaryColor),
                                  const SizedBox(height: 16),
                                  ...anterioresAgrupadas.entries.expand((entry) => [
                                    if (novas.isEmpty && entry.key == anterioresAgrupadas.keys.first) 
                                       Padding(
                                         padding: const EdgeInsets.only(bottom: 16.0),
                                         child: _buildSectionLabel(entry.key, primaryColor),
                                       )
                                    else
                                       Padding(
                                         padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                                         child: Text(
                                           entry.key,
                                           style: TextStyle(
                                             fontFamily: 'Playfair Display',
                                             fontSize: 14,
                                             fontWeight: FontWeight.bold,
                                             color: primaryColor.withOpacity(0.4),
                                             letterSpacing: 1.0,
                                           ),
                                         ),
                                       ),
                                    ...entry.value.map((act) => _buildActivityCard(act, primaryColor, accentColor)),
                                    const SizedBox(height: 12),
                                  ]),
                                ],
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: primaryColor,
              ),
              Text(
                'Atividades',
                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              IconButton(
                icon: Icon(_newestFirst ? Icons.sort : Icons.sort_by_alpha, size: 20),
                color: primaryColor,
                onPressed: () {
                  setState(() => _newestFirst = !_newestFirst);
                  _loadActivities();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _marcarTodasComoLidas,
            child: Text(
              'Marcar Todas como Lidas',
              style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(Color primaryColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: () async {
          final picked = await showModalBottomSheet<DateTimeRange>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => CustomDateRangePicker(
              initialStartDate: _startDate,
              initialEndDate: _endDate,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          );
          if (picked != null) {
            setState(() {
              _startDate = picked.start;
              _endDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
            });
            _loadActivities();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: accentColor),
              const SizedBox(width: 12),
              Text(
                _startDate == null
                    ? 'Filtrar por período'
                    : '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const Spacer(),
              if (_startDate != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadActivities();
                  },
                  child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                )
              else
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserFilterBar(Color primaryColor, Color accentColor) {
    if (_adminUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.divider),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedUserId,
            isExpanded: true,
            hint: Row(
              children: [
                Icon(Icons.person_search_rounded, size: 18, color: accentColor),
                const SizedBox(width: 12),
                Text(
                  'Filtrar por Usuário',
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey[400]),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Todos os Usuários', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor)),
              ),
              ..._adminUsers.map((user) {
                final nome = (user['nome_completo'] != null && user['nome_completo'].toString().trim().isNotEmpty)
                    ? user['nome_completo']
                    : (user['email'] ?? 'Usuário sem nome');
                return DropdownMenuItem<String>(
                  value: user['id'],
                  child: Text(
                    '$nome (${user['tipo'] == 'admin' ? 'Admin' : 'Profissional'})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() => _selectedUserId = value);
              _loadActivities();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color primaryColor) {
    return Text(
      label,
      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
    );
  }

  Widget _buildEmptyState(Color primaryColor, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: accentColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma atividade encontrada',
            style: TextStyle(fontSize: 18, color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(DashboardAtividade act, Color primaryColor, Color accentColor) {
    return GestureDetector(
      onTap: () async {
        if (!act.isLida) {
          // Marca no banco e localmente
          _marcarComoLida(act.id);
        }
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminAtividadeDetalhesPage(atividade: act),
          ),
        );
        
        // Ao voltar, recarrega para garantir sincronia com o banco
        _loadActivities();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: !act.isLida
              ? const Border(left: BorderSide(color: AppColors.accent, width: 4))
              : Border.all(color: AppColors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getIconColor(act.tipo).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIconForTipo(act.tipo), color: _getIconColor(act.tipo), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act.titulo,
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: act.isLida ? primaryColor.withOpacity(0.6) : primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                Text(
                  act.displayDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                    color: AppColors.textLight,
                    height: 1.4,
                  ),
                ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${act.formattedTime} · ${act.actorName != null ? 'POR: ${act.actorName!.split(' ').first.toUpperCase()}' : 'SISTEMA'}',
                              style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: accentColor.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accentColor.withOpacity(0.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!act.isLida)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return Icons.calendar_today_rounded;
      case 'confirmacao': return Icons.check_circle_outline_rounded;
      case 'cancelamento': return Icons.cancel_outlined;
      case 'reagendamento': return Icons.history_rounded;
      case 'cliente': return Icons.person_add_outlined;
      case 'pagamento': return Icons.account_balance_wallet_outlined;
      case 'venda': return Icons.shopping_bag_outlined;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _getIconColor(String tipo) {
    switch (tipo) {
      case 'agendamento': return AppColors.primary;
      case 'confirmacao': return AppColors.primary;
      case 'cancelamento': return AppColors.error;
      case 'cliente': return AppColors.accent;
      case 'pagamento': return AppColors.accent;
      case 'venda': return AppColors.accent;
      default: return AppColors.accent;
    }
  }

  String _getLabelForTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return 'Agendamento';
      case 'confirmacao': return 'Confirmação';
      case 'cancelamento': return 'Cancelamento';
      case 'reagendamento': return 'Reagendamento';
      case 'cliente': return 'Novo Cliente';
      case 'pagamento': return 'Pagamento';
      case 'venda': return 'Venda de Produto';
      default: return 'Sistema';
    }
  }
}


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';

class AdminConfiguracoesPage extends StatefulWidget {
  const AdminConfiguracoesPage({super.key});

  @override
  State<AdminConfiguracoesPage> createState() => _AdminConfiguracoesPageState();
}

class _AdminConfiguracoesPageState extends State<AdminConfiguracoesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _dashboardRepo = SupabaseDashboardRepository();
  
  bool _isLoading = true;
  int? _configId;
  String _nomeComercial = AppConfig.nomeComercial;
  String _endereco = AppConfig.endereco;
  String _telefoneFixo = AppConfig.telefoneFixo;
  String _whatsapp = AppConfig.whatsapp;
  String _emailContato = AppConfig.emailContato ?? '';
  String _mapaIframe = AppConfig.mapaIframe ?? '';
  String _descricao = '';
  bool _telefoneFixoAtivo = AppConfig.telefoneFixoAtivo;
  String _logoUrl = AppConfig.logoUrl ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuAG6eToNB53GWJOF5DexUJMipxbI4hfAlT5u6s3x4STGZ5qk4T9-1itCJK2VmxQJSBl_Mt87gwqua4rsaIr3j8FhwznYpH3vh-WJ6nPHo9N1zXHQc6U8VyzZtc0b-O7hbsNnkyRnHU2mJB1xOI1E8Zj_ScCgOAPbQ7QXyAGom8g_IX1TR2JRWM6n7_ip7_E5ReUNq40p-robjC7WMTzB1MFdjUqhzflr4sZ9bRRmUu7txtLcS74UOgfnQ2UBuyYeaW5rRpx1hvVgOTv';

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }


  Future<void> _carregarConfiguracoes() async {
    try {
      final response = await _supabase.from('configuracoes_clinica').select().maybeSingle();
      if (response != null) {
        setState(() {
          _configId = response['id'];
          _nomeComercial = response['nome_comercial'] ?? _nomeComercial;
          _endereco = response['endereco'] ?? _endereco;
          _telefoneFixo = response['telefone_fixo'] ?? _telefoneFixo;
          _whatsapp = response['whatsapp'] ?? _whatsapp;
          _emailContato = response['email_contato'] ?? _emailContato;
          _mapaIframe = response['mapa_iframe'] ?? _mapaIframe;
          _descricao = response['descricao'] ?? _descricao;
          _telefoneFixoAtivo = response['telefone_fixo_ativo'] ?? _telefoneFixoAtivo;
          _logoUrl = response['logo_url'] ?? _logoUrl;
          _logoUrl = response['logo_url'] ?? _logoUrl;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarConfiguracao(String campo, String dbField, String novoValor) async {
    try {
      // Get old value for notification
      String? oldVal;
      if (dbField == 'nome_comercial') oldVal = _nomeComercial;
      if (dbField == 'endereco') oldVal = _endereco;
      if (dbField == 'telefone_fixo') oldVal = _telefoneFixo;
      if (dbField == 'whatsapp') oldVal = _whatsapp;
      if (dbField == 'email_contato') oldVal = _emailContato;
      if (dbField == 'mapa_iframe') oldVal = _mapaIframe;
      if (dbField == 'descricao') oldVal = _descricao;
      if (dbField == 'logo_url') oldVal = _logoUrl;

      if (_configId == null) {
        // Insere primeiro registro
        final res = await _supabase.from('configuracoes_clinica').insert({
          dbField: novoValor,
          // Preenche os obrigatorios
          'nome_comercial': dbField == 'nome_comercial' ? novoValor : _nomeComercial,
          'endereco': dbField == 'endereco' ? novoValor : _endereco,
          'telefone_fixo': dbField == 'telefone_fixo' ? novoValor : _telefoneFixo,
          'whatsapp': dbField == 'whatsapp' ? novoValor : _whatsapp,
          'email_contato': dbField == 'email_contato' ? novoValor : _emailContato,
          'mapa_iframe': dbField == 'mapa_iframe' ? novoValor : _mapaIframe,
          'descricao': dbField == 'descricao' ? novoValor : _descricao,
        }).select().single();
        _configId = res['id'];
      } else {
        await _supabase.from('configuracoes_clinica').update({
          dbField: novoValor,
        }).eq('id', _configId as Object);
      }

      // Notify clients about the change
      if (oldVal != novoValor) {
        // Log activity for admin dashboard
        await _dashboardRepo.logActivity(
          tipo: 'configuracao',
          titulo: 'Configuração da Clínica Alterada',
          descricao: 'O campo $campo foi atualizado de "${oldVal ?? 'Não informado'}" para "$novoValor"',
          userId: _supabase.auth.currentUser?.id,
          metadata: {
            'changes': [
              {
                'campo': campo,
                'antigo': oldVal ?? 'Não informado',
                'novo': novoValor,
              }
            ]
          },
        );

        final repo = SupabaseNotificationRepository();
        await repo.notifyAllClients(
          titulo: 'Configuração Alterada',
          mensagem: 'O administrador atualizou informações da clínica: $campo',
          tipo: 'config_change',
          metadata: {
            'changes': [
              {
                'field': campo,
                'old': oldVal ?? 'Não informado',
                'new': novoValor,
              }
            ]
          },
        );
      }
      
      setState(() {
        if (dbField == 'nome_comercial') _nomeComercial = novoValor;
        if (dbField == 'endereco') _endereco = novoValor;
        if (dbField == 'telefone_fixo') _telefoneFixo = novoValor;
        if (dbField == 'whatsapp') _whatsapp = novoValor;
        if (dbField == 'email_contato') _emailContato = novoValor;
        if (dbField == 'mapa_iframe') _mapaIframe = novoValor;
        if (dbField == 'descricao') _descricao = novoValor;
        if (dbField == 'logo_url') _logoUrl = novoValor;
        if (dbField == 'logo_url') _logoUrl = novoValor;
      });
      
      // Update global config
      await AppConfig.loadConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$campo atualizado com sucesso!'),
            backgroundColor: const Color(0xFF2F5E46),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar $campo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTelefoneFixoAtivo(bool valor) async {
    try {
      if (_configId == null) {
        // Tenta carregar config se não tiver ID
        await _carregarConfiguracoes();
        if (_configId == null) return;
      }

      await _supabase.from('configuracoes_clinica').update({
        'telefone_fixo_ativo': valor,
      }).eq('id', _configId as Object);

      // Log activity
      await _dashboardRepo.logActivity(
        tipo: 'configuracao',
        titulo: 'Visibilidade de Telefone Alterada',
        descricao: 'A visibilidade do telefone fixo foi ${valor ? 'ativada' : 'desativada'}',
        userId: _supabase.auth.currentUser?.id,
        metadata: {
          'changes': [
            {
              'campo': 'Visibilidade Telefone Fixo',
              'antigo': _telefoneFixoAtivo ? 'Ativado' : 'Desativado',
              'novo': valor ? 'Ativado' : 'Desativado',
            }
          ]
        },
      );

      setState(() {
        _telefoneFixoAtivo = valor;
      });

      // Update global config
      await AppConfig.loadConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visibilidade do telefone fixo ${valor ? 'ativada' : 'desativada'}!'),
            backgroundColor: const Color(0xFF2F5E46),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar visibilidade.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _alterarFoto(Color primaryColor) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final fileName = 'logo_clinica_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'public/$fileName';

      // Salva no bucket de 'perfis'
      await _supabase.storage.from('perfis').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(cacheControl: '3600', upsert: true),
      );

      final url = _supabase.storage.from('perfis').getPublicUrl(storagePath);
      await _salvarConfiguracao('Logo', 'logo_url', url);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar imagem.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const goldColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);
    const softGreen = Color(0xFF6E8F7B);
    const premiumGray = Color(0xFF2B2B2B);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Perfil
              _buildProfileHeader(primaryColor, goldColor, premiumGray, softGreen),
              
              const SizedBox(height: 24),
              
              // Seções de Configuração
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Card Dados da Clínica
                    _buildConfigCard(
                      goldColor: goldColor,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.business,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Dados da clínica',
                              style: TextStyle(fontSize: 18,
                                fontFamily: 'Playfair Display',
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildListItem(
                          label: 'Nome comercial',
                          value: _nomeComercial,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'nome comercial',
                            'nome_comercial',
                            _nomeComercial,
                            primaryColor,
                            goldColor,
                          ),
                        ),
                        _buildListItem(
                          label: 'Endereço',
                          value: _endereco,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'Endereço',
                            'endereco',
                            _endereco,
                            primaryColor,
                            goldColor,
                          ),
                        ),
                        _buildListItem(
                          label: 'Telefone fixo',
                          value: _telefoneFixo,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'telefone fixo',
                            'telefone_fixo',
                            _telefoneFixo,
                            primaryColor,
                            goldColor,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        // Switch para Ativar/Inativar Fixo (Alinhado à direita final)
                        Padding(
                          padding: const EdgeInsets.only(left: 40, bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mostrar telefone fixo ao cliente',
                                      style: TextStyle(fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: softGreen,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _telefoneFixoAtivo ? 'Ativado' : 'Desativado',
                                      style: TextStyle(fontSize: 14, 
                                        color: premiumGray
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Switch para Ativar/Inativar Fixo (100% alinhado à direita)
                              Transform.translate(
                                offset: const Offset(12, 0), // Nudge para compensar o padding interno do Switch e alinhar com 'Editar'
                                child: SizedBox(
                                  height: 28,
                                  width: 48,
                                  child: Transform.scale(
                                    scale: 0.75,
                                    child: Switch(
                                      value: _telefoneFixoAtivo,
                                      onChanged: _toggleTelefoneFixoAtivo,
                                      activeThumbColor: goldColor,
                                      activeTrackColor: goldColor.withOpacity(0.3),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildListItem(
                          label: 'WhatsApp',
                          value: _whatsapp,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'WhatsApp',
                            'whatsapp',
                            _whatsapp,
                            primaryColor,
                            goldColor,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        _buildListItem(
                          label: 'E-mail de contato',
                          value: _emailContato.isEmpty ? 'Nenhum e-mail informado' : _emailContato,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'e-mail de contato',
                            'email_contato',
                            _emailContato,
                            primaryColor,
                            goldColor,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          isLast: false,
                        ),
                        _buildListItem(
                          label: 'Descrição',
                          value: _descricao.isEmpty ? 'Nenhuma descrição informada' : _descricao,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'Descrição',
                            'descricao',
                            _descricao,
                            primaryColor,
                            goldColor,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                          ),
                          isLast: false,
                        ),
                        _buildListItem(
                          label: 'Link do mapa (URL da imagem)',
                          value: _mapaIframe.isEmpty ? 'Nenhuma URL informada' : _mapaIframe,
                          premiumGray: premiumGray,
                          softGreen: softGreen,
                          goldColor: goldColor,
                          onEdit: () => _showEditDialog(
                            'link do mapa',
                            'mapa_iframe',
                            _mapaIframe,
                            primaryColor,
                            goldColor,
                            maxLines: null,
                            keyboardType: TextInputType.url,
                          ),
                          isLast: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),
                    _buildSectionHeader('Configurações globais', primaryColor),
                    const SizedBox(height: 8),
                    _buildActionItem(
                      onTap: () => context.push('/admin/horarios'),
                      icon: Icons.access_time_rounded,
                      title: 'Dias de funcionamento',
                      subtitle: 'Horários e bloqueio de agenda',
                      pColor: primaryColor,
                      gColor: goldColor,
                      softGreen: softGreen,
                    ),
                    const SizedBox(height: 24),
                    _buildActionItem(
                      onTap: () => context.push('/admin/promocoes'),
                      icon: Icons.campaign_rounded,
                      title: 'Gerenciar promoções',
                      subtitle: 'Banners e cards da tela inicial',
                      pColor: primaryColor,
                      gColor: goldColor,
                      softGreen: softGreen,
                    ),
                    const SizedBox(height: 24),
                    _buildActionItem(
                      icon: Icons.credit_card_rounded,
                      title: 'Taxas dos cartões',
                      subtitle: 'Débito, Crédito, Parcelado e PIX',
                      pColor: primaryColor,
                      gColor: goldColor,
                      softGreen: softGreen,
                      onTap: () => context.push('/admin/configuracoes/taxas'),
                    ),

                    const SizedBox(height: 48),
                    _buildSectionHeader('Segurança', primaryColor),
                    const SizedBox(height: 8),
                    _buildActionItem(
                      onTap: () => context.push('/alterar-senha'),
                      icon: Icons.lock_outline,
                      title: 'Alterar senha',
                      subtitle: 'Mantenha sua conta segura',
                      pColor: primaryColor,
                      gColor: goldColor,
                      softGreen: softGreen,
                    ),
                    const SizedBox(height: 24),

                    // Logout
                    _buildActionItem(
                      onTap: () => context.push('/admin/confirmacao-logout'),
                      icon: Icons.logout_rounded,
                      title: 'Sair da conta',
                      subtitle: 'Encerrar sessão no painel admin',
                      pColor: primaryColor,
                      gColor: goldColor,
                      softGreen: softGreen,
                    ),

                    const SizedBox(height: 48),
                    Text(
                      '${AppConfig.nomeComercial.toUpperCase()} V2.4.0',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: softGreen.withOpacity(0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String title, String dbField, String initialValue, Color primaryColor, Color goldColor, {int? maxLines = 1, TextInputType? keyboardType}) {
    final controller = TextEditingController(text: initialValue);
    final errorNotifier = ValueNotifier<bool>(false);
    
    final phoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Editar ${title.toLowerCase()}',
          style: TextStyle(fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: ValueListenableBuilder<bool>(
          valueListenable: errorNotifier,
          builder: (context, hasError, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  inputFormatters: keyboardType == TextInputType.phone ? [phoneFormatter] : null,
                  style: TextStyle(color: const Color(0xFF2B2B2B)),
                  onChanged: (val) {
                    if (val.isNotEmpty && errorNotifier.value) {
                      errorNotifier.value = false;
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Digite o novo $title',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.03),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: hasError ? Colors.red : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: hasError ? Colors.red : goldColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Este campo é obrigatório',
                      style: TextStyle(color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppButtonStyles.cancelButtonStyle(),
                  child: Text(
                    'Cancelar',
                    style: AppButtonStyles.cancelTextStyle(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final newValue = keyboardType == TextInputType.phone 
                        ? phoneFormatter.getUnmaskedText() 
                        : controller.text.trim();
                    if (newValue.isEmpty) {
                      errorNotifier.value = true;
                      return;
                    }
                    _salvarConfiguracao(title, dbField, newValue);
                    Navigator.pop(context);
                  },
                  style: AppButtonStyles.primary(),
                  child: const Text(
                    'Salvar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildProfileHeader(Color primaryColor, Color goldColor, Color premiumGray, Color softGreen) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: goldColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: DecorationImage(
                  image: NetworkImage(_logoUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _alterarFoto(primaryColor),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: goldColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nomeComercial.split(' ').take(2).join(' '),
          style: TextStyle(fontFamily: 'Playfair Display', 
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTag('Administrador', primaryColor.withOpacity(0.1), primaryColor),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color primaryColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFC7A36B),
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard({required List<Widget> children, required Color goldColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListItem({
    required String label,
    required String value,
    required Color premiumGray,
    required Color softGreen,
    Color? goldColor,
    bool isLast = false,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 40, bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: softGreen,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: premiumGray),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Text(
                'Editar',
                style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: goldColor ?? const Color(0xFFC7A36B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color pColor,
    required Color gColor,
    required Color softGreen,
    bool hasSubtitle = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: pColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: pColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: pColor,
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: softGreen),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: gColor),
          ],
        ),
      ),
    );
  }

}


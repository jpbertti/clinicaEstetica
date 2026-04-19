import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:go_router/go_router.dart';

// ─── Taxa Input Formatter (Eating Zeros) ───────────────────────────────────
class _TaxaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '0,00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    // Pega apenas os números
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // Converte para double e divide por 100 para ter 2 casas decimais
    double value = double.tryParse(digits) ?? 0;
    final String formatted = (value / 100).toStringAsFixed(2).replaceAll('.', ',');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AdminTaxasFinanceirasPage extends StatefulWidget {
  const AdminTaxasFinanceirasPage({super.key});

  @override
  State<AdminTaxasFinanceirasPage> createState() => _AdminTaxasFinanceirasPageState();
}

class _AdminTaxasFinanceirasPageState extends State<AdminTaxasFinanceirasPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseDashboardRepository _dashboardRepo = SupabaseDashboardRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  int? _configId;

  final TextEditingController _debitoController = TextEditingController();
  final TextEditingController _creditoController = TextEditingController();
  final TextEditingController _parceladoController = TextEditingController();
  final TextEditingController _pixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _debitoController.dispose();
    _creditoController.dispose();
    _parceladoController.dispose();
    _pixController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final response = await _supabase.from('configuracoes_clinica').select().maybeSingle();
      if (response != null) {
        setState(() {
          _configId = response['id'];
          _debitoController.text = ((response['taxa_debito'] as num?) ?? 0).toStringAsFixed(2).replaceAll('.', ',');
          _creditoController.text = ((response['taxa_credito'] as num?) ?? 0).toStringAsFixed(2).replaceAll('.', ',');
          _parceladoController.text = ((response['taxa_credito_parcelado'] as num?) ?? 0).toStringAsFixed(2).replaceAll('.', ',');
          _pixController.text = ((response['taxa_pix'] as num?) ?? 0).toStringAsFixed(2).replaceAll('.', ',');
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar taxas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvar() async {
    if (_configId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuração base não encontrada.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double debito = double.tryParse(_debitoController.text.replaceAll(',', '.')) ?? 0;
      final double credito = double.tryParse(_creditoController.text.replaceAll(',', '.')) ?? 0;
      final double parcelado = double.tryParse(_parceladoController.text.replaceAll(',', '.')) ?? 0;
      final double pix = double.tryParse(_pixController.text.replaceAll(',', '.')) ?? 0;

      // Buscar valores antigos ANTES do update
      final oldData = await _supabase.from('configuracoes_clinica').select().eq('id', _configId!).single();
      
      await _supabase.from('configuracoes_clinica').update({
        'taxa_debito': debito,
        'taxa_credito': credito,
        'taxa_credito_parcelado': parcelado,
        'taxa_pix': pix,
      }).eq('id', _configId!);

      await AppConfig.loadConfig();

      // Log the activity
      List<Map<String, dynamic>> structuredChanges = [];
      String descChanges = "";
      
      void addChange(String label, dynamic oldValNum, dynamic newValNum) {
        final double oldVal = (oldValNum as num?)?.toDouble() ?? 0.0;
        final double newVal = (newValNum as num?)?.toDouble() ?? 0.0;
        
        if (oldVal != newVal) {
          structuredChanges.add({
            'campo': label,
            'antigo': "${oldVal.toStringAsFixed(2).replaceAll('.', ',')}%",
            'novo': "${newVal.toStringAsFixed(2).replaceAll('.', ',')}%",
          });
          descChanges += "$label: ${newVal.toStringAsFixed(2).replaceAll('.', ',')}% (era ${oldVal.toStringAsFixed(2).replaceAll('.', ',')}%), ";
        }
      }

      addChange('Taxa Débito', oldData['taxa_debito'], debito);
      addChange('Taxa Crédito', oldData['taxa_credito'], credito);
      addChange('Taxa Parcelado', oldData['taxa_credito_parcelado'], parcelado);
      addChange('Taxa PIX', oldData['taxa_pix'], pix);
      
      if (structuredChanges.isNotEmpty) {
        descChanges = descChanges.substring(0, descChanges.length - 2); // Remove last comma
        await _dashboardRepo.logActivity(
          tipo: 'financeiro',
          titulo: 'Taxas de Cartão Alteradas',
          descricao: descChanges,
          userId: _supabase.auth.currentUser?.id,
          metadata: {
            'changes': structuredChanges
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Taxas dos cartões atualizadas com sucesso!'),
            backgroundColor: Color(0xFF2F5E46),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar taxas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const goldColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);
    const premiumGray = Color(0xFF2B2B2B);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure as taxas aplicadas às formas de pagamento. '
              'Esses valores serão usados no cálculo automático de comissões e faturamento líquido.',
              style: TextStyle(fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'CARTÕES E PIX',
              primaryColor: primaryColor,
              goldColor: goldColor,
              children: [
                _buildTaxInput(
                  label: 'Taxa Débito',
                  controller: _debitoController,
                  icon: Icons.credit_card_rounded,
                  goldColor: goldColor,
                ),
                _buildTaxInput(
                  label: 'Taxa Crédito (à vista)',
                  controller: _creditoController,
                  icon: Icons.credit_card_rounded,
                  goldColor: goldColor,
                ),
                _buildTaxInput(
                  label: 'Taxa Crédito Parcelado',
                  controller: _parceladoController,
                  icon: Icons.credit_score_rounded,
                  goldColor: goldColor,
                ),
                _buildTaxInput(
                  label: 'Taxa PIX',
                  controller: _pixController,
                  icon: Icons.pix_rounded,
                  goldColor: goldColor,
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => context.pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.bold,
                        color: goldColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.4),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Salvar Taxas',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color primaryColor,
    required Color goldColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: goldColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primaryColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }

  Widget _buildTaxInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color goldColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2F5E46), // Green
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _TaxaInputFormatter(),
            ],
            style: TextStyle(fontSize: 16,
              color: const Color(0xFF2B2B2B),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: goldColor.withOpacity(0.6), size: 20),
              suffixText: '%',
              suffixStyle: TextStyle(color: Colors.black38,
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.03),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: goldColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

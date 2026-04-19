import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  static final ValueNotifier<String> nomeComercialNotifier = 
      ValueNotifier('Clínica Estética Lumière Premium');
  
  static final ValueNotifier<String?> logoUrlNotifier = ValueNotifier(null);
  static final ValueNotifier<String> telefoneFixoNotifier = ValueNotifier('(11) 3456-7890');
  static final ValueNotifier<String> whatsappNotifier = ValueNotifier('(11) 99876-5432');
  static final ValueNotifier<String> enderecoNotifier = ValueNotifier('Avenida São Sebastião, 357, São Paulo');
  static final ValueNotifier<String> emailContatoNotifier = ValueNotifier('contato@clinicapremium.com');
  static final ValueNotifier<String?> mapaIframeNotifier = ValueNotifier(null);
  static final ValueNotifier<bool> telefoneFixoAtivoNotifier = ValueNotifier(true);
  static final ValueNotifier<double> taxaDebitoNotifier = ValueNotifier(0.0);
  static final ValueNotifier<double> taxaCreditoNotifier = ValueNotifier(0.0);
  static final ValueNotifier<double> taxaCreditoParceladoNotifier = ValueNotifier(0.0);
  static final ValueNotifier<double> taxaPixNotifier = ValueNotifier(0.0);
  
  static String get nomeComercial => nomeComercialNotifier.value;
  static String? get logoUrl => logoUrlNotifier.value;
  static String get telefoneFixo => telefoneFixoNotifier.value;
  static bool get telefoneFixoAtivo => telefoneFixoAtivoNotifier.value;
  static String get whatsapp => whatsappNotifier.value;
  static String get endereco => enderecoNotifier.value;
  static String get emailContato => emailContatoNotifier.value;
  static String? get mapaIframe => mapaIframeNotifier.value;
  static double get taxaDebito => taxaDebitoNotifier.value;
  static double get taxaCredito => taxaCreditoNotifier.value;
  static double get taxaCreditoParcelado => taxaCreditoParceladoNotifier.value;
  static double get taxaPix => taxaPixNotifier.value;

  static Future<void> loadConfig() async {
    try {
      final response = await Supabase.instance.client
          .from('configuracoes_clinica')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        if (response['nome_comercial'] != null) {
          nomeComercialNotifier.value = response['nome_comercial'];
        }
        if (response['logo_url'] != null) {
          logoUrlNotifier.value = response['logo_url'];
        }
        if (response['telefone_fixo'] != null) {
          telefoneFixoNotifier.value = response['telefone_fixo'];
        }
        if (response['telefone_fixo_ativo'] != null) {
          telefoneFixoAtivoNotifier.value = response['telefone_fixo_ativo'];
        }
        if (response['whatsapp'] != null) {
          whatsappNotifier.value = response['whatsapp'];
        }
        if (response['endereco'] != null) {
          enderecoNotifier.value = response['endereco'];
        }
        if (response['email_contato'] != null) {
          emailContatoNotifier.value = response['email_contato'];
        }
        if (response['mapa_iframe'] != null) {
          mapaIframeNotifier.value = response['mapa_iframe'];
        }
        if (response['taxa_debito'] != null) {
          taxaDebitoNotifier.value = (response['taxa_debito'] as num).toDouble();
        }
        if (response['taxa_credito'] != null) {
          taxaCreditoNotifier.value = (response['taxa_credito'] as num).toDouble();
        }
        if (response['taxa_credito_parcelado'] != null) {
          taxaCreditoParceladoNotifier.value = (response['taxa_credito_parcelado'] as num).toDouble();
        }
        if (response['taxa_pix'] != null) {
          taxaPixNotifier.value = (response['taxa_pix'] as num).toDouble();
        }
      }

    } catch (e) {
      debugPrint('Erro ao carregar configuracoes da clinica: $e');
    }
  }

  /// Limpa a string do iframe para extrair apenas a URL do src
  static String? getMapaUrl() {
    final value = mapaIframe?.trim();
    if (value == null || value.isEmpty) return null;
    
    // Se for um link completo de iframe, tenta extrair o src primeiro
    if (value.contains('<iframe')) {
      final regex = RegExp(r'src="([^"]+)"');
      final match = regex.firstMatch(value);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }

    // Se começar com http (ou for o que sobrou após falha na extração de iframe), retorna
    if (value.startsWith('http')) {
      return value;
    }
    
    return null;
  }

  /// Gera uma URL de busca no Google Maps baseada no endereço físico
  static String getSearchUrl() {
    final query = Uri.encodeComponent(endereco);
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }
}


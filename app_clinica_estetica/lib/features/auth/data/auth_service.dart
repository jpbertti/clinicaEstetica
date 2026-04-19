import 'package:flutter/foundation.dart';
// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
// import 'package:google_sign_in/google_sign_in.dart'; // Removido
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:intl/intl.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String? currentUserNome;
  static String? currentUserEmail;
  static String? currentUserTelefone;
  static String? currentUserCriadoEm;
  static String? currentUserAvatarUrl;
  static String? currentUserId; // Mudado para String (UUID)
  static String? currentUserTipo; // 'cliente', 'profissional', 'admin'
  static String? currentUserCargo; // Para profissionais
  // static bool isGoogleUser = false; // Removido
  static final authStateNotifier = ValueNotifier<bool>(false);
  static final recoveryNotifier = ValueNotifier<bool>(false);

  // URL padrão de "boneco" (silhueta genérica) para usuários sem foto
  static const String defaultAvatarUrl = 'https://cdn-icons-png.flaticon.com/512/149/149071.png';

  static bool get isAuthenticated =>
      _supabase.auth.currentSession != null;

  static bool get isAdmin =>
      currentUserTipo?.toLowerCase() == 'admin' ||
      currentUserTipo?.toLowerCase() == 'administrador';

  static bool get isProfissional =>
      currentUserTipo?.toLowerCase() == 'profissional';

  // Método para inicializar os dados se já houver sessão
  static Future<void> initialize() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _instance._updateLocalUserVars(user);
    }
    authStateNotifier.value = isAuthenticated;

    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        recoveryNotifier.value = true;
      } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        if (data.session?.user != null) {
          await _instance._updateLocalUserVars(data.session!.user);
        }
        authStateNotifier.value = true;
      } else if (event == AuthChangeEvent.signedOut) {
        // Garantir que as variáveis sejam limpas antes de notificar
        currentUserNome = null;
        currentUserEmail = null;
        currentUserTelefone = null;
        currentUserAvatarUrl = null;
        currentUserId = null;
        currentUserCriadoEm = null;
        currentUserTipo = null;
        currentUserCargo = null;
        authStateNotifier.value = false;
      }
    });
  }

  static final AuthService _instance = AuthService._internal();
  AuthService._internal();
  factory AuthService() => _instance;

  Future<AuthResponse> register({
    required String nome,
    required String email,
    required String telefone,
    required String password,
    String tipo = 'cliente',
    String? cargo,
  }) async {
    try {
      debugPrint('Tentando registrar usuário: $email');
      // 1. Criar usuário no Auth do Supabase
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': nome,
          'user_type': tipo,
          'telefone': telefone,
          'cargo': cargo,
        },
      );

      debugPrint('Resposta signUp: User ID = ${response.user?.id}');

      if (response.user != null) {
        // O trigger handle_new_user no banco de dados já criou o perfil com telefone e nome.
        // Não precisamos fazer update manual aqui, o que evita erros de RLS/Concorrência.
        debugPrint('Perfil criado automaticamente pelo trigger.');

        await _updateLocalUserVars(response.user!);

        if (tipo == 'cliente') {
          // Notificação interna (usuário)
          final notifRepo = SupabaseNotificationRepository();
          await notifRepo.notifyAllAdmins(
            titulo: 'Novo Cliente',
            mensagem: 'O usuário $nome se cadastrou no aplicativo.',
            tipo: 'novo_usuario',
          );

          // Atividade do Dashboard (admin)
          await SupabaseDashboardRepository().logActivity(
            tipo: 'cliente',
            titulo: 'Novo Cliente',
            descricao: '$nome se cadastrou como novo cliente em ${DateFormat('dd/MM \'às\' HH:mm').format(DateTime.now().toLocal())}.',
            metadata: {
              'nome': nome,
              'email': email,
              'telefone': telefone,
              'data_cadastro': DateTime.now().toLocal().toIso8601String(),
              'data_hora': DateTime.now().toLocal().toIso8601String(), // Dual key for compatibility
            },
          );
        }
      }
      return response;
    } catch (e) {
      debugPrint('ERRO NO REGISTRO: $e');
      rethrow;
    }
  }

  /// Registra um profissional sem deslogar o admin (via RPC)
  Future<void> registerProfessionalAsAdmin({
    required String nome,
    required String email,
    required String password,
    required String cargo,
    String? telefone,
    String? tipo,
    String? avatarUrl,
    String? observacoes,
    bool ativo = true,
    double comissaoProdutosPercentual = 0,
    double comissaoAgendamentosPercentual = 0,
  }) async {
    try {
      final String userType = tipo ?? 'profissional';
      final bool isClient = userType == 'cliente';
      
      debugPrint('Tentando registrar $userType via RPC: $email');
      await _supabase.rpc(
        'registrar_usuario_admin',
        params: {
          'p_email': email,
          'p_password': password,
          'p_nome': nome,
          'p_cargo': cargo,
          'p_telefone': telefone,
          'p_tipo': userType,
          'p_avatar_url': avatarUrl,
          'p_comissao_produtos': comissaoProdutosPercentual,
          'p_comissao_agendamentos': comissaoAgendamentosPercentual,
          'p_ativo': ativo,
        },
      );
      
      final notifRepo = SupabaseNotificationRepository();
      if (isClient) {
        await notifRepo.notifyAllAdmins(
          titulo: 'Novo Cliente',
          mensagem: 'O cliente $nome foi cadastrado no sistema.',
          tipo: 'novo_cliente',
        );
      } else {
        await notifRepo.notifyAllAdmins(
          titulo: 'Novo Profissional',
          mensagem: 'O profissional $nome foi cadastrado na equipe.',
          tipo: 'novo_profissional',
        );
      }
      
      debugPrint('$userType registrado com sucesso via RPC.');

      // Log da ação
      await SupabaseAdminLogRepository().logAction(
        acao: isClient ? 'Cadastrar Cliente' : 'Cadastrar Profissional',
        detalhes: '${isClient ? 'Cliente' : 'Profissional'}: $nome, Email: $email',
        tabelaAfetada: 'perfis',
      );
    } catch (e) {
      debugPrint('ERRO NO REGISTRO via RPC: $e');
      rethrow;
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      debugPrint('Tentando login para: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('Login Auth Sucesso: User ID = ${response.user?.id}');

      if (response.user != null) {
        // Atualizar data de último login e verificar se está ativo
        await _supabase.rpc('atualizar_ultimo_login', params: {'p_user_id': response.user!.id});
        
        // Chamar o cleanup de inativos para garantir a regra dos 30 dias
        await _supabase.rpc('limpar_usuarios_inativos_30_dias');

        await _updateLocalUserVars(response.user!);
      }
      authStateNotifier.value = isAuthenticated;
      return response;
    } catch (e) {
      debugPrint('ERRO NO LOGIN: $e');
      rethrow;
    }
  }

  // loginWithGoogle e linkWithGoogle removidos.

  Future<bool> _checkIfProfileExists(String userId) async {
    try {
      final response = await _supabase
          .from('perfis')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateLocalUserVars(User user) async {
    try {
      debugPrint('Buscando dados do perfil para user.id: ${user.id}');
      
      // isGoogleUser = user.identities?.any((id) => id.provider == 'google') ?? false; // Removido

      // Uso maybeSingle() para evitar o erro PGRST116 (0 rows)
      final profile = await _supabase
          .from('perfis')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint('Aviso: Perfil ainda não encontrado para ${user.id}. Pode haver um delay no trigger.');
        // Fallback para metadados se o perfil ainda não existir
        currentUserNome = user.userMetadata?['full_name'] ?? 'Usuário';
        currentUserEmail = user.email;
        currentUserId = user.id;
        currentUserTipo = 'cliente';
        return;
      }

      if (profile['ativo'] == false && profile['tipo'] != 'cliente') {
        await logout();
        throw Exception('Sua conta de profissional está inativa. Entre em contato com o administrador.');
      }

      debugPrint('Perfil encontrado: ${profile['nome_completo']}');
      currentUserNome = profile['nome_completo'];
      currentUserEmail = profile['email'];
      currentUserTelefone = profile['telefone'];
      currentUserAvatarUrl = profile['avatar_url'];
      currentUserId = profile['id'];
      currentUserCriadoEm = profile['criado_em'];
      currentUserTipo = profile['tipo'];
      currentUserCargo = profile['cargo'];
    } catch (e) {
      debugPrint('Erro ao atualizar variáveis do usuário: $e');
      if (e.toString().contains('inativa')) rethrow;
    }
  }

  Future<void> updateProfile({
    String? email,
    String? telefone,
    String? nome,
    String? avatarUrl,
    String? cargo,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{};
    if (email != null) updates['email'] = email;
    if (telefone != null) updates['telefone'] = telefone;
    if (nome != null) updates['nome_completo'] = nome;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (cargo != null) updates['cargo'] = cargo;

    if (updates.isEmpty) return;

    await _supabase.from('perfis').update(updates).eq('id', user.id);

    // Atualiza Auth se o email ou nome mudar
    if (email != null || nome != null) {
      await _supabase.auth.updateUser(UserAttributes(
        email: email,
        data: nome != null ? {'full_name': nome} : null,
      ));
    }

    if (email != null) currentUserEmail = email;
    if (telefone != null) currentUserTelefone = telefone;
    if (nome != null) currentUserNome = nome;
    if (avatarUrl != null) currentUserAvatarUrl = avatarUrl;
    if (cargo != null) currentUserCargo = cargo;
  }

  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não logado');

    final fileName = 'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storagePath = 'public/$fileName';

    await _supabase.storage.from('perfis').uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );

    final url = _supabase.storage.from('perfis').getPublicUrl(storagePath);
    
    // Atualiza a tabela de perfis com a nova URL
    await updateProfile(avatarUrl: url);
    
    return url;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://reset-callback/',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Primeiro tentamos fazer login com a senha atual para validar
      await _supabase.auth.signInWithPassword(
        email: currentUserEmail!,
        password: currentPassword,
      );
      
      // Se o login funcionou, então alteramos a senha
      await updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    await _supabase.auth.signOut();
    currentUserNome = null;
    currentUserEmail = null;
    currentUserTelefone = null;
    currentUserId = null;
    currentUserCriadoEm = null;
    currentUserTipo = null;
    currentUserCargo = null;
    authStateNotifier.value = false;
  }
}


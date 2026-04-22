import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';
import 'package:app_clinica_estetica/features/auth/presentation/pages/login_page.dart';
import 'package:app_clinica_estetica/features/auth/presentation/pages/cadastro_page.dart';
import 'package:app_clinica_estetica/features/auth/presentation/pages/confirmacao_logout_page.dart';
import 'package:app_clinica_estetica/features/auth/presentation/pages/esqueci_senha_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/home/inicio_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/servicos/servicos_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/perfil/perfil_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/perfil/meus_pacotes_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/agenda_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/agendamento_page.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/servicos/pacote_detalhes_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/servicos/servico_detalhes_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/servicos/pacote_confirmacao_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/servicos/pacote_sessao_selecao_page.dart';
import 'package:app_clinica_estetica/core/data/models/profile_model.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/detalhes_agendamento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/cancelar_agendamento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/sucesso_cancelamento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/sucesso_manter_agendamento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/confirmacao_agendamento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/sucesso_agendamento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/reagendamento_sucesso_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/avaliar_atendimento_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/agenda/avaliacao_sucesso_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/perfil/ajuda_suporte_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/perfil/historico_avaliacoes_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/perfil/meus_produtos_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/notificacoes/notificacoes_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/perfil/alterar_senha_page.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/features/auth/presentation/pages/redefinir_senha_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/shell/admin_shell_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/dashboard/admin_dashboard_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/agendamentos/admin_agendamentos_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/servicos/admin_servicos_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/clientes/admin_clientes_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/profissionais/admin_profissionais_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/profissionais/admin_add_profissional_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/configuracoes/admin_horarios_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/configuracoes/admin_gerenciador_promocoes_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/auth/admin_confirmacao_logout_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/relatorios/admin_relatorios_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/relatorios/admin_detalhes_relatorio_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/shell/profissional_shell_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/agenda/profissional_agenda_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/relatorios/profissional_relatorios_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/perfil/profissional_perfil_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/notificacoes/profissional_notificacoes_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/auth/profissional_confirmacao_logout_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/perfil/profissional_config_agenda_page.dart';
import 'package:app_clinica_estetica/features/usuario/presentation/pages/shell/usuario_shell_page.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'package:app_clinica_estetica/features/admin/presentation/pages/servicos/admin_add_procedimento_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/configuracoes/admin_configuracoes_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/configuracoes/admin_taxas_financeiras_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/profissionais/admin_edit_profissional_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/profissionais/admin_vincular_servicos_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/profissionais/admin_vincular_pacotes_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/servicos/admin_edit_procedimento_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/clientes/admin_detalhes_cliente_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/clientes/admin_add_cliente_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/financeiro/admin_caixa_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/produtos/admin_produtos_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/produtos/admin_add_edit_produto_page.dart';
import 'package:app_clinica_estetica/core/data/models/product_model.dart';

import 'package:app_clinica_estetica/features/admin/presentation/pages/profissionais/admin_professional_lunch_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/servicos/admin_gerenciador_pacotes_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/servicos/admin_add_edit_pacote_page.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/agendamentos/admin_novo_agendamento_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: Listenable.merge([
    AuthService.authStateNotifier,
    AuthService.recoveryNotifier,
  ]),
  debugLogDiagnostics: true,
  onException: (context, state, router) {
    // debugPrint('ERRO DE ROTA: ${state.uri}');
  },
  redirect: (context, state) {
    if (AuthService.recoveryNotifier.value) {
      return '/redefinir-senha';
    }

    final bool isAuthenticated = AuthService.isAuthenticated;
    final bool isLoggingIn =
        state.uri.path == '/login' ||
        state.uri.path == '/cadastro' ||
        state.uri.path == '/esqueci-senha' ||
        state.uri.path == '/redefinir-senha';

    if (!isAuthenticated && !isLoggingIn) {
      return '/login';
    }

    if (isAuthenticated) {
      final bool isAdmin = AuthService.isAdmin;
      final bool isProfissional = AuthService.isProfissional;
      
      final bool enteringAdmin = state.uri.path.startsWith('/admin');
      final bool enteringProfissional = state.uri.path.startsWith('/profissional');

      final String userRole = isAdmin ? 'ADMIN' : (isProfissional ? 'PROFISSIONAL' : 'CLIENTE');

      // Debug para ajudar a rastrear redirecionamentos
      debugPrint(
        'NAVIGATION: path=${state.uri.path}, type=$userRole, isAdmin=$isAdmin, isProf=$isProfissional, enteringAdmin=$enteringAdmin',
      );

      // Se logado e em telas de login, vai pra home correta
      if (isLoggingIn && state.uri.path != '/redefinir-senha') {
        if (isAdmin) return '/admin';
        if (isProfissional) return '/profissional/agenda';
        return '/inicio';
      }

      // Proibir não-admins de entrarem no admin
      if (enteringAdmin && !isAdmin) {
        debugPrint('REDIRECT: Bloqueio admin -> redirecionando para home apropriada');
        if (isProfissional) return '/profissional/agenda';
        return '/inicio';
      }

      // Proibir não-profissionais de entrarem no painel profissional
      if (enteringProfissional && !isProfissional && !isAdmin) {
        debugPrint('REDIRECT: Bloqueio profissional -> redirecionando para /inicio');
        return '/inicio';
      }

      // Proibir admin de entrar na home de cliente (opcional, mas comum)
      if (!enteringAdmin && !enteringProfissional && (isAdmin || isProfissional) && state.uri.path == '/inicio') {
        debugPrint('REDIRECT: Admin/Prof no inicio -> redirecionando');
        return isAdmin ? '/admin' : '/profissional/agenda';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/inicio'),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/cadastro',
      builder: (context, state) => const CadastroPage(),
    ),
    GoRoute(
      path: '/esqueci-senha',
      builder: (context, state) => const EsqueciSenhaPage(),
    ),
    // --- PAINEL USUÁRIO (CLIENTE) ---
    ShellRoute(
      builder: (context, state, child) {
        return UsuarioShellPage(
          currentPath: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/inicio',
          builder: (context, state) => const InicioPage(),
        ),
        GoRoute(
          path: '/servicos',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>?;
            final initialCategory = data?['initialCategory'] as String?;
            final initialServiceId = data?['initialServiceId'] as String?;
            return ServicosPage(
              initialCategory: initialCategory,
              initialServiceId: initialServiceId,
            );
          },
        ),
        GoRoute(path: '/perfil', builder: (context, state) => const PerfilPage()),
        GoRoute(path: '/agenda', builder: (context, state) => const AgendaPage()),
        
        // Sub-páginas do usuário que mantém o Shell (Barra inferior)
        GoRoute(
          path: '/agendamento',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>?;
            final service = data?['service'];
            final pacote = data?['pacote'] as PacoteTemplateModel?;
            final profissional = data?['profissional'] as ProfileModel?;
            final sessaoNumero = data?['sessaoNumero'] as int?;
            final serviceId = data?['serviceId'] as String?;
            final serviceName = data?['serviceName'] as String?;
            final clientId = data?['clientId'] as String?;
            final clientName = data?['clientName'] as String?;
            
            return AgendamentoPage(
              service: service,
              pacote: pacote,
              profissional: profissional,
              sessaoNumero: sessaoNumero,
              serviceId: serviceId,
              serviceName: serviceName,
              clientId: clientId,
              clientName: clientName,
            );
          },
        ),
        GoRoute(
          path: '/pacote-detalhes',
          builder: (context, state) {
            final pacote = state.extra as PacoteTemplateModel;
            return PacoteDetalhesPage(pacote: pacote);
          },
        ),
        GoRoute(
          path: '/servico-detalhes',
          builder: (context, state) {
            final service = state.extra as ServiceModel;
            return ServicoDetalhesPage(service: service);
          },
        ),
        GoRoute(
          path: '/pacote-confirmacao',
          builder: (context, state) {
            final pacote = state.extra as PacoteTemplateModel;
            return PacoteConfirmacaoPage(pacote: pacote);
          },
        ),
        GoRoute(
          path: '/pacotes/confirmacao',
          builder: (context, state) {
            final pacote = state.extra as PacoteTemplateModel;
            return PacoteConfirmacaoPage(pacote: pacote);
          },
        ),
        GoRoute(
          path: '/pacote-sessao-selecao',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            return PacoteSessaoSelecaoPage(
              pacote: data['pacote'] as PacoteTemplateModel,
              profissional: data['profissional'] as ProfileModel,
              contratoId: data['contratoId'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/confirmacao-agendamento',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>?;
            return ConfirmacaoAgendamentoPage(bookingData: data);
          },
        ),
        GoRoute(path: '/meus-pacotes', builder: (context, state) => const MeusPacotesPage()),
        GoRoute(path: '/meus-produtos', builder: (context, state) => const MeusProdutosPage()),
        GoRoute(
          path: '/detalhes-agendamento',
          builder: (context, state) {
            final appointment = state.extra as AppointmentModel;
            return DetalhesAgendamentoPage(appointment: appointment);
          },
        ),
        GoRoute(
          path: '/cancelar-agendamento',
          builder: (context, state) {
            final appointment = state.extra as AppointmentModel;
            return CancelarAgendamentoPage(appointment: appointment);
          },
        ),
        GoRoute(
          path: '/sucesso-cancelamento',
          builder: (context, state) => const SucessoCancelamentoPage(),
        ),
        GoRoute(
          path: '/sucesso-manter-agendamento',
          builder: (context, state) => const SucessoManterAgendamentoPage(),
        ),
        GoRoute(
          path: '/sucesso-agendamento',
          builder: (context, state) => const SucessoAgendamentoPage(),
        ),
        GoRoute(
          path: '/reagendamento-sucesso',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            return ReagendamentoSucessoPage(
              appointment: data['appointment'] as AppointmentModel,
              newDateTime: data['newDateTime'] as DateTime,
            );
          },
        ),
        GoRoute(
          path: '/avaliar-atendimento',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            final appointment = data['appointment'] as AppointmentModel;
            final initialEvaluation = data['initialEvaluation'] as EvaluationModel?;
            return AvaliarAtendimentoPage(
              appointment: appointment,
              initialEvaluation: initialEvaluation,
            );
          },
        ),
        GoRoute(
          path: '/avaliar-sucesso',
          builder: (context, state) {
            final appointment = state.extra as AppointmentModel;
            return AvaliacaoSucessoPage(appointment: appointment);
          },
        ),
        GoRoute(
          path: '/ajuda-suporte',
          builder: (context, state) => const AjudaSuportePage(),
        ),
        GoRoute(
          path: '/historico-avaliacoes',
          builder: (context, state) => const HistoricoAvaliacoesPage(),
        ),
        GoRoute(
          path: '/notificacoes',
          builder: (context, state) => const NotificacoesPage(),
        ),
        GoRoute(
          path: '/alterar-senha',
          builder: (context, state) => const AlterarSenhaPage(),
        ),
        GoRoute(
          path: '/confirmacao-logout',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const ConfirmacaoLogoutPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            opaque: false,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/redefinir-senha',
      builder: (context, state) => const RedefinirSenhaPage(),
    ),

    // --- PAINEL ADMIN ---
    ShellRoute(
      builder: (context, state, child) {
        return AdminShellPage(
          currentPath: state.uri.path,
          extra: state.extra,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: '/admin/agendamentos',
          builder: (context, state) => const AdminAgendamentosPage(),
          routes: [
            GoRoute(
              path: 'novo',
              builder: (context, state) => const AdminNovoAgendamentoPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/admin/servicos',
          builder: (context, state) => const AdminServicosPage(),
          routes: [
            GoRoute(
              path: 'novo',
              builder: (context, state) => const AdminAddProcedimentoPage(),
            ),
            GoRoute(
              path: 'editar/:id',
              builder: (context, state) {
                final procedure = state.extra as Map<String, dynamic>;
                return AdminEditProcedimentoPage(procedure: procedure);
              },
            ),
            GoRoute(
              path: 'pacotes',
              builder: (context, state) => const AdminGerenciadorPacotesPage(),
            ),
            GoRoute(
              path: 'pacotes/novo',
              builder: (context, state) => const AdminAddEditPacotePage(),
            ),
            GoRoute(
              path: 'pacotes/editar',
              builder: (context, state) {
                final pacote = state.extra as PacoteTemplateModel;
                return AdminAddEditPacotePage(pacoteToEdit: pacote);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/admin/clientes',
          builder: (context, state) => const AdminClientesPage(),
          routes: [
            GoRoute(
              path: 'novo',
              builder: (context, state) => const AdminAddClientePage(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final String id = state.pathParameters['id']!;
                return AdminDetalhesClientePage(clientId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/admin/profissionais',
          builder: (context, state) => const AdminProfissionaisPage(),
          routes: [
            GoRoute(
              path: 'novo',
              builder: (context, state) => const AdminAddProfissionalPage(),
            ),
            GoRoute(
              path: 'editar',
              builder: (context, state) {
                final prof = state.extra as Map<String, dynamic>;
                return AdminEditProfissionalPage(professional: prof);
              },
            ),
            GoRoute(
              path: 'vincular',
              builder: (context, state) {
                final prof = state.extra as Map<String, dynamic>;
                return AdminVincularServicoPage(professional: prof);
              },
            ),
            GoRoute(
              path: 'vincular-pacotes/:id',
              builder: (context, state) {
                final prof = state.extra as Map<String, dynamic>;
                return AdminVincularPacotesPage(professional: prof);
              },
            ),
            GoRoute(
              path: 'almoco/:id',
              builder: (context, state) {
                final prof = state.extra as Map<String, dynamic>;
                return AdminProfessionalLunchPage(professional: prof);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/admin/configuracoes',
          builder: (context, state) => const AdminConfiguracoesPage(),
          routes: [
            GoRoute(
              path: 'taxas',
              builder: (context, state) => const AdminTaxasFinanceirasPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/admin/horarios',
          builder: (context, state) => const AdminHorariosPage(),
        ),
        GoRoute(
          path: '/admin/promocoes',
          builder: (context, state) => const AdminGerenciadorPromocoesPage(),
        ),
        GoRoute(
          path: '/admin/confirmacao-logout',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const AdminConfirmacaoLogoutPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            opaque: false,
          ),
        ),
        GoRoute(
          path: '/admin/reports-admin',
          builder: (context, state) => const AdminRelatoriosPage(),
          routes: [
            GoRoute(
              path: 'detalhes/:category',
              builder: (context, state) {
                final category = state.pathParameters['category']!;
                return AdminDetalhesRelatorioPage(reportCategory: category);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/admin/caixa',
          builder: (context, state) => const AdminCaixaPage(),
        ),
        GoRoute(
          path: '/admin/produtos',
          builder: (context, state) => const AdminProdutosPage(),
          routes: [
            GoRoute(
              path: 'novo',
              builder: (context, state) => const AdminAddEditProdutoPage(),
            ),
            GoRoute(
              path: 'editar',
              builder: (context, state) {
                final product = state.extra as ProductModel;
                return AdminAddEditProdutoPage(product: product);
              },
            ),
          ],
        ),

      ],
    ),

    // --- PAINEL PROFISSIONAL ---
    ShellRoute(
      builder: (context, state, child) {
        return ProfissionalShellPage(
          currentPath: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/profissional',
          redirect: (context, state) => '/profissional/agenda',
        ),
        GoRoute(
          path: '/profissional/agenda',
          builder: (context, state) => const ProfissionalAgendaPage(),
        ),
        GoRoute(
          path: '/profissional/relatorios',
          builder: (context, state) => const ProfissionalRelatoriosPage(),
        ),
        GoRoute(
          path: '/profissional/perfil',
          builder: (context, state) => const ProfissionalPerfilPage(),
        ),
        GoRoute(
          path: '/profissional/notificacoes',
          builder: (context, state) => const ProfissionalNotificacoesPage(),
        ),
        GoRoute(
          path: '/profissional/gerenciar-agenda',
          builder: (context, state) {
            final initialIndex = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return ProfissionalConfigAgendaPage(initialIndex: initialIndex);
          },
        ),
        GoRoute(
          path: '/profissional/clientes/:id',
          builder: (context, state) {
            final String id = state.pathParameters['id']!;
            return AdminDetalhesClientePage(clientId: id);
          },
        ),
        GoRoute(
          path: '/profissional/confirmacao-logout',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const ProfissionalConfirmacaoLogoutPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            opaque: false,
          ),
        ),
      ],
    ),
  ],
);


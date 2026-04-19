import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';
import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/appointment_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class AvaliarAtendimentoPage extends StatefulWidget {
  final AppointmentModel appointment;
  final EvaluationModel? initialEvaluation;
  const AvaliarAtendimentoPage({
    super.key, 
    required this.appointment,
    this.initialEvaluation,
  });

  @override
  State<AvaliarAtendimentoPage> createState() => _AvaliarAtendimentoPageState();
}

class _AvaliarAtendimentoPageState extends State<AvaliarAtendimentoPage> {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  final IAppointmentRepository _appointmentRepo = SupabaseAppointmentRepository();
  final _notificationRepo = SupabaseNotificationRepository();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEvaluation != null) {
      _rating = widget.initialEvaluation!.nota;
      _commentController.text = widget.initialEvaluation!.comentario ?? '';
      if (widget.initialEvaluation!.tags.isNotEmpty) {
        _selectedTags.addAll(widget.initialEvaluation!.tags);
      }
    }
  }

  final List<String> _tags = [
    'Atendimento Excelente',
    'Ambiente Acolhedor',
    'Profissionalismo',
    'Resultados Imediatos',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(image);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitEvaluation() async {
    setState(() => _isLoading = true);
    try {
      // 1. Upload das fotos se houver
      List<String> imageUrls = [];
      if (_images.isNotEmpty) {
        imageUrls = await _appointmentRepo.uploadEvaluationPhotos(_images);
      }

      // 2. Criar modelo de avaliação
      final evaluation = EvaluationModel(
        id: widget.initialEvaluation?.id,
        agendamentoId: widget.appointment.id,
        clienteId: widget.appointment.clienteId,
        profissionalId: widget.appointment.profissionalId,
        nota: _rating,
        comentario: _commentController.text,
        tags: _selectedTags.toList(),
        fotos: imageUrls.isNotEmpty ? imageUrls : (widget.initialEvaluation?.fotos ?? []),
      );

      // 3. Salvar ou Atualizar avaliação
      if (widget.initialEvaluation != null) {
        await _appointmentRepo.updateEvaluation(evaluation);
      } else {
        await _appointmentRepo.saveEvaluation(evaluation);

        // Enviar notificação de agradecimento
        try {
          final notification = NotificationModel(
            userId: widget.appointment.clienteId,
            titulo: 'Avaliação Recebida! ✨',
            mensagem: 'Obrigado por compartilhar sua opinião sobre o atendimento de ${widget.appointment.serviceName} do dia ${DateFormat('dd/MM', 'pt_BR').format(widget.appointment.dataHora)} às ${DateFormat('HH:mm').format(widget.appointment.dataHora)}. Sua experiência é muito importante para nós!',
            tipo: 'avaliacao',
            isLida: false,
            dataCriacao: DateTime.now(),
          );
          await _notificationRepo.saveNotification(notification);
        } catch (e) {
          debugPrint('Erro ao enviar notificação de avaliação: $e');
        }
      }

      if (mounted) {
        if (widget.initialEvaluation != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avaliação atualizada com sucesso!')),
          );
          context.pop();
        } else {
          context.pushReplacement('/avaliar-sucesso', extra: widget.appointment);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar avaliação: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  bool get _canSubmit => _rating > 0;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);
    const softGreen = Color(0xFF6E8F7B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _construirCabecalho(context, primaryColor),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Professional Card
                    _construirCardContexto(
                      primaryColor,
                      accentColor,
                      softGreen,
                    ),

                    const SizedBox(height: 40),
                    // Rating Section
                    _construirSecaoAvaliacao(
                      primaryColor,
                      accentColor,
                      softGreen,
                    ),

                    const SizedBox(height: 32),
                    // Tags Section
                    _construirSecaoTags(primaryColor, accentColor, softGreen),

                    const SizedBox(height: 32),
                    // Comment Section
                    _construirSecaoComentario(primaryColor, softGreen),

                    const SizedBox(height: 32),
                    // Photos Section
                    _construirSecaoFotos(primaryColor, accentColor, softGreen),

                    const SizedBox(height: 40),
                    // Submit Button
                    _construirBotaoEnvio(context, primaryColor, accentColor),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCabecalho(BuildContext context, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: primaryColor,
            style: IconButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              overlayColor: Colors.transparent,
            ),
          ),
          Text(
            'Avaliar Atendimento',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 48), // Equalizer
        ],
      ),
    );
  }

  Widget _construirCardContexto(
    Color primaryColor,
    Color accentColor,
    Color softGreen,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 2,
              ),
              image: DecorationImage(
                image: NetworkImage(
                  widget.appointment.professionalAvatarUrl ??
                      'https://images.unsplash.com/photo-1559839734-2b71ef1536783?auto=format&fit=crop&q=80&w=200',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROCEDIMENTO',
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  widget.appointment.serviceName ?? 'Procedimento',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  widget.appointment.professionalName ?? 'Profissional',
                  style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: softGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSecaoAvaliacao(
    Color primaryColor,
    Color accentColor,
    Color softGreen,
  ) {
    return Column(
      children: [
        Text(
          'Como foi sua experiência?',
          style: TextStyle(fontFamily: 'Playfair Display', 
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sua opinião é fundamental para nossa excelência.',
          style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w500,
            color: softGreen,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isFilled = index < _rating;
            return GestureDetector(
              onTap: () => setState(() => _rating = index + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_outline,
                  size: 48,
                  color: isFilled
                      ? accentColor
                      : accentColor.withOpacity(0.6),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _construirSecaoTags(
    Color primaryColor,
    Color accentColor,
    Color softGreen,
  ) {
    return Column(
      children: [
        Text(
          'DESTAQUES DO ATENDIMENTO',
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800,
            color: primaryColor.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _tags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => _toggleTag(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor
                        : primaryColor.withOpacity(0.1),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tag,
                  style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : primaryColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _construirSecaoComentario(Color primaryColor, Color softGreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Deixe um comentário (opcional)',
            style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Conte-nos mais sobre os detalhes que tornaram sua visita especial...',
            hintStyle: TextStyle(fontSize: 14,
              color: softGreen.withOpacity(0.5),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
          style: TextStyle(fontSize: 14, color: primaryColor),
        ),
      ],
    );
  }

  Widget _construirSecaoFotos(
    Color primaryColor,
    Color accentColor,
    Color softGreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Compartilhe fotos do seu resultado (opcional)',
            style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._images.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(image.path) as ImageProvider
                            : FileImage(File(image.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (_images.length < 3)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: accentColor,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ADICIONAR',
                        style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_images.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Você pode adicionar até 3 fotos do antes e depois.',
              style: TextStyle(fontSize: 11,
                fontStyle: FontStyle.italic,
                color: softGreen,
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirBotaoEnvio(
    BuildContext context,
    Color primaryColor,
    Color accentColor,
  ) {
    return ElevatedButton(
      onPressed: _canSubmit && !_isLoading
          ? _submitEvaluation
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primaryColor.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ENVIAR AVALIAÇÃO',
            style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.auto_awesome,
            color: _canSubmit
                ? accentColor
                : Colors.white.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}


import '../models/pacote_contratado_model.dart';
import '../models/pacote_template_model.dart';

abstract class PackageRepository {
  Future<List<PacoteTemplateModel>> getTemplates();
  Future<PacoteTemplateModel> getTemplateById(String id);
  Future<PacoteTemplateModel> createTemplate(PacoteTemplateModel template);
  Future<void> updateTemplate(PacoteTemplateModel template);
  Future<void> deleteTemplate(String id);

  Future<List<PacoteContratadoModel>> getContratados({String? clienteId});
  Future<PacoteContratadoModel> getContratadoById(String id);
  Future<PacoteContratadoModel> createContratado(PacoteContratadoModel pacote);
  Future<void> updateContratoStatus(String id, String status);
  Future<void> cancelContract(String id);
}


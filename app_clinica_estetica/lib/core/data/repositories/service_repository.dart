import 'package:app_clinica_estetica/core/data/models/service_model.dart';

abstract class IServiceRepository {
  Future<List<ServiceModel>> getActiveServices();
  Future<List<ServiceModel>> searchServices(String query);
  Future<bool> canDeleteService(String serviceId);
  Future<List<Map<String, dynamic>>> getCategories();
}


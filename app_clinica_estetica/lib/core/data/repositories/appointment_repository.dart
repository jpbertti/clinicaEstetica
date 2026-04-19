import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';
import 'package:image_picker/image_picker.dart';

abstract class IAppointmentRepository {
  Future<List<AppointmentModel>> getUserAppointments(String userId);
  Future<List<AppointmentModel>> getUpcomingAppointments(String userId);
  Future<List<AppointmentModel>> getPastAppointments(String userId);
  Future<void> cancelAppointment(String id);
  Future<void> rescheduleAppointment(String id, DateTime newDateTime);
  Future<void> saveEvaluation(EvaluationModel evaluation);
  Future<void> updateEvaluation(EvaluationModel evaluation);
  Future<List<EvaluationModel>> getUserEvaluations(String userId);
  Future<List<String>> uploadEvaluationPhotos(List<XFile> files);
  Future<void> autoCompletePastAppointments(String userId);
  Future<void> updateAppointmentStatus(String id, String status);
  Future<bool> checkClientHasOtherAppOnDate({
    required String clientId,
    required DateTime date,
    required String? excludedAppointmentId,
  });
  Future<Map<String, dynamic>?> getClientConflictAtTime({
    required String clientId,
    required DateTime dateTime,
    required String? excludedAppointmentId,
  });
  Future<Map<String, dynamic>?> getProfessionalConflictAtTime({
    required String professionalId,
    required DateTime dateTime,
    required String? excludedAppointmentId,
  });
  Future<List<AppointmentModel>> getAppointmentsByPackageId(String packageId);
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/error/exceptions.dart';
import '../models/reminder_model.dart';

/// Contrato del Data Source Remoto
abstract class ReminderRemoteDataSource {
  Future<List<ReminderModel>> getReminders();
  Future<ReminderModel> getReminderById(String id);
  Future<ReminderModel> createReminder(ReminderModel reminder);
  Future<ReminderModel> updateReminder(ReminderModel reminder);
  Future<void> deleteReminder(String id);
  Stream<List<ReminderModel>> watchReminders();
}

/// Implementación con Firebase
class ReminderRemoteDataSourceImpl implements ReminderRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  ReminderRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  String get _userId {
    final user = auth.currentUser;
    if (user == null) {
      throw ServerException('Usuario no autenticado');
    }
    return user.uid;
  }

  CollectionReference get _remindersCollection =>
      firestore.collection('users').doc(_userId).collection('reminders');

  @override
  Future<List<ReminderModel>> getReminders() async {
    try {
      final snapshot = await _remindersCollection
          .orderBy('dateTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) =>
              ReminderModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('Error de Firebase: ${e.message}');
    } catch (e) {
      throw ServerException('Error al obtener recordatorios remotos: $e');
    }
  }

  @override
  Future<ReminderModel> getReminderById(String id) async {
    try {
      final snapshot = await _remindersCollection.doc(id).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw ServerException('Recordatorio remoto no encontrado');
      }
      return ReminderModel.fromJson(data as Map<String, dynamic>);
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException('Error de Firebase: ${e.message}');
    } catch (e) {
      throw ServerException('Error al obtener recordatorio remoto: $e');
    }
  }

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    try {
      await _remindersCollection.doc(reminder.id).set(reminder.toJson());
      return reminder;
    } on FirebaseException catch (e) {
      throw ServerException('Error de Firebase: ${e.message}');
    } catch (e) {
      throw ServerException('Error al crear recordatorio remoto: $e');
    }
  }

  @override
  Future<ReminderModel> updateReminder(ReminderModel reminder) async {
    try {
      await _remindersCollection.doc(reminder.id).set(reminder.toJson());
      return reminder;
    } on FirebaseException catch (e) {
      throw ServerException('Error de Firebase: ${e.message}');
    } catch (e) {
      throw ServerException('Error al actualizar recordatorio remoto: $e');
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    try {
      await _remindersCollection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException('Error de Firebase: ${e.message}');
    } catch (e) {
      throw ServerException('Error al eliminar recordatorio remoto: $e');
    }
  }

  @override
  Stream<List<ReminderModel>> watchReminders() {
    try {
      return _remindersCollection
          .orderBy('dateTime', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) =>
                  ReminderModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList());
    } on FirebaseException catch (e) {
      throw ServerException('Error de Firebase: ${e.message}');
    } catch (e) {
      throw ServerException('Error al observar recordatorios remotos: $e');
    }
  }
}

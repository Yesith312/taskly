import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

/// Firestore ya trae caché offline activada por defecto en móvil:
/// si el usuario no tiene internet, las lecturas usan la última copia
/// local y las escrituras se guardan en cola y se sincronizan solas
/// cuando vuelve la conexión. No hay que programar nada extra para eso,
/// solo evitar bloquear la UI esperando la red.
class TaskService {
  final CollectionReference<Map<String, dynamic>> _tasksRef =
      FirebaseFirestore.instance.collection('tasks');

  Stream<List<TaskModel>> watchTasksForUser(String userId) {
    return _tasksRef
        .where('ownerId', isEqualTo: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<String> createTask(TaskModel task) async {
    final doc = await _tasksRef.add(task.toMap());
    return doc.id;
  }

  Future<void> updateTask(TaskModel task) {
    return _tasksRef.doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String taskId) {
    return _tasksRef.doc(taskId).delete();
  }

  Future<void> setDone(String taskId, bool isDone) {
    return _tasksRef.doc(taskId).update({'isDone': isDone});
  }
}

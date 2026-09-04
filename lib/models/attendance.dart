class Attendance {
  final int? id;
  final int workerId;
  final int projectId;
  final String attendanceDate;
  final String status;

  Attendance({
    this.id,
    required this.workerId,
    required this.projectId,
    required this.attendanceDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'worker_id': workerId,
      'project_id': projectId,
      'attendance_date': attendanceDate,
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      workerId: map['worker_id'],
      projectId: map['project_id'],
      attendanceDate: map['attendance_date'],
      status: map['status'],
    );
  }
}

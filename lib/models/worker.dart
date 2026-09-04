class Worker {
  final int? id;
  final String reference;
  final int companyId;
  final int? projectId;
  final String fullName;
  final String phone;
  final double dailySalary;
  final String position;
  final String hireDate;

  Worker({
    this.id,
    required this.reference,
    required this.companyId,
    this.projectId,
    required this.fullName,
    required this.phone,
    required this.dailySalary,
    required this.position,
    required this.hireDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'company_id': companyId,
      'project_id': projectId,
      'full_name': fullName,
      'phone': phone,
      'daily_salary': dailySalary,
      'position': position,
      'hire_date': hireDate,
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['id'] as int?,
      reference: map['reference'] as String,
      companyId: map['company_id'] as int,
      projectId: map['project_id'] as int?,
      fullName: map['full_name'] as String,
      phone: (map['phone'] as String?) ?? '',
      dailySalary: (map['daily_salary'] as num).toDouble(),
      position: (map['position'] as String?) ?? '',
      hireDate: (map['hire_date'] as String?) ?? '',
    );
  }
}

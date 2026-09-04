class Project {
  final int? id;
  final String reference;
  final int companyId;
  final String name;
  final String location;
  final String startDate;
  final String endDate;
  final String status;

  Project({
    this.id,
    required this.reference,
    required this.companyId,
    required this.name,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'company_id': companyId,
      'name': name,
      'location': location,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int?,
      reference: map['reference'],
      companyId: map['company_id'] as int,
      name: map['name'] as String,
      location: map['location'] ?? '',
      startDate: map['start_date'] ?? '',
      endDate: map['end_date'] ?? '',
      status: map['status'] ?? 'Active',
    );
  }
}

class Company {
  final int? id;
  final String reference;
  final String name;
  final String address;
  final String phone;

  Company({
    this.id,
    required this.reference,
    required this.name,
    required this.address,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'name': name,
      'address': address,
      'phone': phone,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      reference: map['reference'],
      name: map['name'],
      address: map['address'],
      phone: map['phone'],
    );
  }
}

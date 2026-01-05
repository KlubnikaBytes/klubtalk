class ContactModel {
  final String id;
  final String name;
  final String about;
  final String avatarUrl;
  bool isSelected; // UI state, mutable for this mock implementation if needed, but preferred handled by controller

  ContactModel({
    required this.id,
    required this.name,
    required this.about,
    required this.avatarUrl,
    this.isSelected = false,
  });
}

class Contact {
  final String name;
  final String profileImage;
  final bool isOnline;

  const Contact({
    required this.name,
    required this.profileImage,
    this.isOnline = false,
  });
}

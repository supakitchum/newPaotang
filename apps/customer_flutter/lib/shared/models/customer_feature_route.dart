enum CustomerFeatureGroup {
  storefront,
  lottery,
  wallet,
  account,
  content,
  system,
}

class CustomerFeatureRoute {
  const CustomerFeatureRoute({
    required this.path,
    required this.key,
    required this.group,
    this.descriptionKey,
    this.public = false,
    this.sensitive = false,
  });

  final String path;
  final String key;
  final CustomerFeatureGroup group;
  final String? descriptionKey;
  final bool public;
  final bool sensitive;
}

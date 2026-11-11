import 'package:flutter/material.dart';

/// A pair of Material icons representing the idle (outlined) and active (filled)
/// states of a financial category.
class CuratedIconPair {
  final String id;
  final String label;
  final String domain;
  final IconData outlined;
  final IconData filled;

  const CuratedIconPair({
    required this.id,
    required this.label,
    required this.domain,
    required this.outlined,
    required this.filled,
  });

  IconData getIcon({required bool isSelected}) => isSelected ? filled : outlined;
}

/// Offline catalog of exactly 100 curated Material icon pairs across 10 functional domains.
/// Zero asset overhead, zero font bundling, pure offline native MaterialIcons.
abstract final class CuratedIconsCatalog {
  static const List<CuratedIconPair> allIcons = [
    // -------------------------------------------------------------
    // Domain 1: Food & Dining (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'restaurant', label: 'Restaurant', domain: 'Food & Dining', outlined: Icons.restaurant_outlined, filled: Icons.restaurant),
    CuratedIconPair(id: 'fastfood', label: 'Fast Food', domain: 'Food & Dining', outlined: Icons.fastfood_outlined, filled: Icons.fastfood),
    CuratedIconPair(id: 'cafe', label: 'Coffee & Cafe', domain: 'Food & Dining', outlined: Icons.local_cafe_outlined, filled: Icons.local_cafe),
    CuratedIconPair(id: 'bar', label: 'Drinks & Bar', domain: 'Food & Dining', outlined: Icons.local_bar_outlined, filled: Icons.local_bar),
    CuratedIconPair(id: 'pizza', label: 'Pizza', domain: 'Food & Dining', outlined: Icons.local_pizza_outlined, filled: Icons.local_pizza),
    CuratedIconPair(id: 'bakery', label: 'Bakery', domain: 'Food & Dining', outlined: Icons.bakery_dining_outlined, filled: Icons.bakery_dining),
    CuratedIconPair(id: 'lunch', label: 'Lunch', domain: 'Food & Dining', outlined: Icons.lunch_dining_outlined, filled: Icons.lunch_dining),
    CuratedIconPair(id: 'dinner', label: 'Dining', domain: 'Food & Dining', outlined: Icons.dinner_dining_outlined, filled: Icons.dinner_dining),
    CuratedIconPair(id: 'icecream', label: 'Dessert', domain: 'Food & Dining', outlined: Icons.icecream_outlined, filled: Icons.icecream),
    CuratedIconPair(id: 'ramen', label: 'Ramen & Noodles', domain: 'Food & Dining', outlined: Icons.ramen_dining_outlined, filled: Icons.ramen_dining),

    // -------------------------------------------------------------
    // Domain 2: Shopping & Retail (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'shopping_bag', label: 'Shopping', domain: 'Shopping', outlined: Icons.shopping_bag_outlined, filled: Icons.shopping_bag),
    CuratedIconPair(id: 'shopping_cart', label: 'Groceries', domain: 'Shopping', outlined: Icons.shopping_cart_outlined, filled: Icons.shopping_cart),
    CuratedIconPair(id: 'store', label: 'Store', domain: 'Shopping', outlined: Icons.store_outlined, filled: Icons.store),
    CuratedIconPair(id: 'local_mall', label: 'Mall', domain: 'Shopping', outlined: Icons.local_mall_outlined, filled: Icons.local_mall),
    CuratedIconPair(id: 'loyalty', label: 'Coupons', domain: 'Shopping', outlined: Icons.loyalty_outlined, filled: Icons.loyalty),
    CuratedIconPair(id: 'sell', label: 'Discounts', domain: 'Shopping', outlined: Icons.sell_outlined, filled: Icons.sell),
    CuratedIconPair(id: 'gift', label: 'Gifts', domain: 'Shopping', outlined: Icons.card_giftcard_outlined, filled: Icons.card_giftcard),
    CuratedIconPair(id: 'diamond', label: 'Luxury & Jewelry', domain: 'Shopping', outlined: Icons.diamond_outlined, filled: Icons.diamond),
    CuratedIconPair(id: 'watch', label: 'Accessories', domain: 'Shopping', outlined: Icons.watch_outlined, filled: Icons.watch),
    CuratedIconPair(id: 'checkroom', label: 'Clothing', domain: 'Shopping', outlined: Icons.checkroom_outlined, filled: Icons.checkroom),

    // -------------------------------------------------------------
    // Domain 3: Travel & Commute (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'directions_car', label: 'Car & Taxi', domain: 'Travel', outlined: Icons.directions_car_outlined, filled: Icons.directions_car),
    CuratedIconPair(id: 'flight', label: 'Flight', domain: 'Travel', outlined: Icons.flight_outlined, filled: Icons.flight),
    CuratedIconPair(id: 'directions_bus', label: 'Bus', domain: 'Travel', outlined: Icons.directions_bus_outlined, filled: Icons.directions_bus),
    CuratedIconPair(id: 'train', label: 'Train & Metro', domain: 'Travel', outlined: Icons.train_outlined, filled: Icons.train),
    CuratedIconPair(id: 'two_wheeler', label: 'Bike & Scooter', domain: 'Travel', outlined: Icons.two_wheeler_outlined, filled: Icons.two_wheeler),
    CuratedIconPair(id: 'directions_bike', label: 'Bicycle', domain: 'Travel', outlined: Icons.directions_bike_outlined, filled: Icons.directions_bike),
    CuratedIconPair(id: 'local_gas_station', label: 'Fuel & Petrol', domain: 'Travel', outlined: Icons.local_gas_station_outlined, filled: Icons.local_gas_station),
    CuratedIconPair(id: 'local_taxi', label: 'Cab Service', domain: 'Travel', outlined: Icons.local_taxi_outlined, filled: Icons.local_taxi),
    CuratedIconPair(id: 'hotel', label: 'Hotel & Stay', domain: 'Travel', outlined: Icons.hotel_outlined, filled: Icons.hotel),
    CuratedIconPair(id: 'navigation', label: 'Tolls & Trips', domain: 'Travel', outlined: Icons.navigation_outlined, filled: Icons.navigation),

    // -------------------------------------------------------------
    // Domain 4: Bills & Utilities (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'receipt', label: 'Bills', domain: 'Bills & Utilities', outlined: Icons.receipt_outlined, filled: Icons.receipt),
    CuratedIconPair(id: 'electric_bolt', label: 'Electricity', domain: 'Bills & Utilities', outlined: Icons.electric_bolt_outlined, filled: Icons.electric_bolt),
    CuratedIconPair(id: 'water_drop', label: 'Water', domain: 'Bills & Utilities', outlined: Icons.water_drop_outlined, filled: Icons.water_drop),
    CuratedIconPair(id: 'wifi', label: 'Internet & WiFi', domain: 'Bills & Utilities', outlined: Icons.wifi_outlined, filled: Icons.wifi),
    CuratedIconPair(id: 'phone_iphone', label: 'Mobile Recharge', domain: 'Bills & Utilities', outlined: Icons.phone_iphone_outlined, filled: Icons.phone_iphone),
    CuratedIconPair(id: 'tv', label: 'Cable & TV', domain: 'Bills & Utilities', outlined: Icons.tv_outlined, filled: Icons.tv),
    CuratedIconPair(id: 'cleaning_services', label: 'Maintenance', domain: 'Bills & Utilities', outlined: Icons.cleaning_services_outlined, filled: Icons.cleaning_services),
    CuratedIconPair(id: 'local_fire_department', label: 'Gas Cylinder', domain: 'Bills & Utilities', outlined: Icons.local_fire_department_outlined, filled: Icons.local_fire_department),
    CuratedIconPair(id: 'description', label: 'Subscriptions', domain: 'Bills & Utilities', outlined: Icons.description_outlined, filled: Icons.description),
    CuratedIconPair(id: 'receipt_long', label: 'Invoices', domain: 'Bills & Utilities', outlined: Icons.receipt_long_outlined, filled: Icons.receipt_long),

    // -------------------------------------------------------------
    // Domain 5: Housing & Home (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'home', label: 'Rent & Home', domain: 'Housing', outlined: Icons.home_outlined, filled: Icons.home),
    CuratedIconPair(id: 'apartment', label: 'Apartment', domain: 'Housing', outlined: Icons.apartment_outlined, filled: Icons.apartment),
    CuratedIconPair(id: 'cottage', label: 'Property', domain: 'Housing', outlined: Icons.cottage_outlined, filled: Icons.cottage),
    CuratedIconPair(id: 'bed', label: 'Furniture', domain: 'Housing', outlined: Icons.bed_outlined, filled: Icons.bed),
    CuratedIconPair(id: 'kitchen', label: 'Appliances', domain: 'Housing', outlined: Icons.kitchen_outlined, filled: Icons.kitchen),
    CuratedIconPair(id: 'plumbing', label: 'Plumbing', domain: 'Housing', outlined: Icons.plumbing_outlined, filled: Icons.plumbing),
    CuratedIconPair(id: 'handyman', label: 'Repairs', domain: 'Housing', outlined: Icons.handyman_outlined, filled: Icons.handyman),
    CuratedIconPair(id: 'yard', label: 'Garden & Plants', domain: 'Housing', outlined: Icons.yard_outlined, filled: Icons.yard),
    CuratedIconPair(id: 'lock', label: 'Security', domain: 'Housing', outlined: Icons.lock_outlined, filled: Icons.lock),
    CuratedIconPair(id: 'lightbulb', label: 'Lighting', domain: 'Housing', outlined: Icons.lightbulb_outlined, filled: Icons.lightbulb),

    // -------------------------------------------------------------
    // Domain 6: Entertainment & Leisure (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'movie', label: 'Entertainment', domain: 'Entertainment', outlined: Icons.movie_outlined, filled: Icons.movie),
    CuratedIconPair(id: 'sports_esports', label: 'Gaming', domain: 'Entertainment', outlined: Icons.sports_esports_outlined, filled: Icons.sports_esports),
    CuratedIconPair(id: 'music_note', label: 'Music & Audio', domain: 'Entertainment', outlined: Icons.music_note_outlined, filled: Icons.music_note),
    CuratedIconPair(id: 'theater_comedy', label: 'Events & Theatre', domain: 'Entertainment', outlined: Icons.theater_comedy_outlined, filled: Icons.theater_comedy),
    CuratedIconPair(id: 'sports_soccer', label: 'Sports', domain: 'Entertainment', outlined: Icons.sports_soccer_outlined, filled: Icons.sports_soccer),
    CuratedIconPair(id: 'fitness_center', label: 'Gym & Fitness', domain: 'Entertainment', outlined: Icons.fitness_center_outlined, filled: Icons.fitness_center),
    CuratedIconPair(id: 'pool', label: 'Swimming & Pool', domain: 'Entertainment', outlined: Icons.pool_outlined, filled: Icons.pool),
    CuratedIconPair(id: 'camera_alt', label: 'Photography', domain: 'Entertainment', outlined: Icons.camera_alt_outlined, filled: Icons.camera_alt),
    CuratedIconPair(id: 'palette', label: 'Art & Hobbies', domain: 'Entertainment', outlined: Icons.palette_outlined, filled: Icons.palette),
    CuratedIconPair(id: 'park', label: 'Parks & Outings', domain: 'Entertainment', outlined: Icons.park_outlined, filled: Icons.park),

    // -------------------------------------------------------------
    // Domain 7: Health & Medical (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'medical_services', label: 'Health', domain: 'Health & Medical', outlined: Icons.medical_services_outlined, filled: Icons.medical_services),
    CuratedIconPair(id: 'local_hospital', label: 'Hospital', domain: 'Health & Medical', outlined: Icons.local_hospital_outlined, filled: Icons.local_hospital),
    CuratedIconPair(id: 'medication', label: 'Medicines', domain: 'Health & Medical', outlined: Icons.medication_outlined, filled: Icons.medication),
    CuratedIconPair(id: 'health_and_safety', label: 'Insurance', domain: 'Health & Medical', outlined: Icons.health_and_safety_outlined, filled: Icons.health_and_safety),
    CuratedIconPair(id: 'spa', label: 'Spa & Wellness', domain: 'Health & Medical', outlined: Icons.spa_outlined, filled: Icons.spa),
    CuratedIconPair(id: 'healing', label: 'First Aid', domain: 'Health & Medical', outlined: Icons.healing_outlined, filled: Icons.healing),
    CuratedIconPair(id: 'monitor_heart', label: 'Diagnostics', domain: 'Health & Medical', outlined: Icons.monitor_heart_outlined, filled: Icons.monitor_heart),
    CuratedIconPair(id: 'psychology', label: 'Therapy', domain: 'Health & Medical', outlined: Icons.psychology_outlined, filled: Icons.psychology),
    CuratedIconPair(id: 'visibility', label: 'Eye Care & Optical', domain: 'Health & Medical', outlined: Icons.visibility_outlined, filled: Icons.visibility),
    CuratedIconPair(id: 'clean_hands', label: 'Sanitation', domain: 'Health & Medical', outlined: Icons.clean_hands_outlined, filled: Icons.clean_hands),

    // -------------------------------------------------------------
    // Domain 8: Education & Learning (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'school', label: 'Education', domain: 'Education', outlined: Icons.school_outlined, filled: Icons.school),
    CuratedIconPair(id: 'menu_book', label: 'Books', domain: 'Education', outlined: Icons.menu_book_outlined, filled: Icons.menu_book),
    CuratedIconPair(id: 'auto_stories', label: 'Tuition & Study', domain: 'Education', outlined: Icons.auto_stories_outlined, filled: Icons.auto_stories),
    CuratedIconPair(id: 'backpack', label: 'Stationery', domain: 'Education', outlined: Icons.backpack_outlined, filled: Icons.backpack),
    CuratedIconPair(id: 'science', label: 'Lab & Research', domain: 'Education', outlined: Icons.science_outlined, filled: Icons.science),
    CuratedIconPair(id: 'calculate', label: 'Accounting', domain: 'Education', outlined: Icons.calculate_outlined, filled: Icons.calculate),
    CuratedIconPair(id: 'draw', label: 'Courses', domain: 'Education', outlined: Icons.draw_outlined, filled: Icons.draw),
    CuratedIconPair(id: 'emoji_events', label: 'Competitions', domain: 'Education', outlined: Icons.emoji_events_outlined, filled: Icons.emoji_events),
    CuratedIconPair(id: 'language', label: 'Languages', domain: 'Education', outlined: Icons.language_outlined, filled: Icons.language),
    CuratedIconPair(id: 'laptop_chromebook', label: 'Online Degree', domain: 'Education', outlined: Icons.laptop_chromebook_outlined, filled: Icons.laptop_chromebook),

    // -------------------------------------------------------------
    // Domain 9: Work, Tech & Finance (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'work', label: 'Office & Work', domain: 'Work & Tech', outlined: Icons.work_outline, filled: Icons.work),
    CuratedIconPair(id: 'laptop', label: 'Freelance & Tech', domain: 'Work & Tech', outlined: Icons.laptop_outlined, filled: Icons.laptop),
    CuratedIconPair(id: 'business_center', label: 'Business', domain: 'Work & Tech', outlined: Icons.business_center_outlined, filled: Icons.business_center),
    CuratedIconPair(id: 'account_balance', label: 'Banking & Taxes', domain: 'Work & Tech', outlined: Icons.account_balance_outlined, filled: Icons.account_balance),
    CuratedIconPair(id: 'trending_up', label: 'Investments & SIP', domain: 'Work & Tech', outlined: Icons.trending_up_outlined, filled: Icons.trending_up),
    CuratedIconPair(id: 'credit_card', label: 'Credit Card', domain: 'Work & Tech', outlined: Icons.credit_card_outlined, filled: Icons.credit_card),
    CuratedIconPair(id: 'savings', label: 'Savings & Gold', domain: 'Work & Tech', outlined: Icons.savings_outlined, filled: Icons.savings),
    CuratedIconPair(id: 'handshake', label: 'Lend & Borrow', domain: 'Work & Tech', outlined: Icons.handshake_outlined, filled: Icons.handshake),
    CuratedIconPair(id: 'payments', label: 'Salaries & Wages', domain: 'Work & Tech', outlined: Icons.payments_outlined, filled: Icons.payments),
    CuratedIconPair(id: 'headset_mic', label: 'Client Support', domain: 'Work & Tech', outlined: Icons.headset_mic_outlined, filled: Icons.headset_mic),

    // -------------------------------------------------------------
    // Domain 10: Personal Care, Family & Pets (10)
    // -------------------------------------------------------------
    CuratedIconPair(id: 'pets', label: 'Pets & Animals', domain: 'Personal & Family', outlined: Icons.pets_outlined, filled: Icons.pets),
    CuratedIconPair(id: 'child_care', label: 'Baby & Kids', domain: 'Personal & Family', outlined: Icons.child_care_outlined, filled: Icons.child_care),
    CuratedIconPair(id: 'family_restroom', label: 'Family Care', domain: 'Personal & Family', outlined: Icons.family_restroom_outlined, filled: Icons.family_restroom),
    CuratedIconPair(id: 'face', label: 'Salon & Grooming', domain: 'Personal & Family', outlined: Icons.face_outlined, filled: Icons.face),
    CuratedIconPair(id: 'content_cut', label: 'Haircut', domain: 'Personal & Family', outlined: Icons.content_cut_outlined, filled: Icons.content_cut),
    CuratedIconPair(id: 'self_improvement', label: 'Meditation & Yoga', domain: 'Personal & Family', outlined: Icons.self_improvement_outlined, filled: Icons.self_improvement),
    CuratedIconPair(id: 'volunteer_activism', label: 'Charity & Donation', domain: 'Personal & Family', outlined: Icons.volunteer_activism_outlined, filled: Icons.volunteer_activism),
    CuratedIconPair(id: 'dry_cleaning', label: 'Laundry', domain: 'Personal & Family', outlined: Icons.dry_cleaning_outlined, filled: Icons.dry_cleaning),
    CuratedIconPair(id: 'celebration', label: 'Parties & Festivals', domain: 'Personal & Family', outlined: Icons.celebration_outlined, filled: Icons.celebration),
    CuratedIconPair(id: 'category', label: 'Other', domain: 'Personal & Family', outlined: Icons.category_outlined, filled: Icons.category),
  ];

  static final Map<String, CuratedIconPair> _index = {
    for (final pair in allIcons) pair.id: pair,
  };

  static final Map<int, IconData> _codePointIndex = {
    for (final pair in allIcons) ...{
      pair.outlined.codePoint: pair.outlined,
      pair.filled.codePoint: pair.filled,
    },
  };

  /// Lookup an icon pair by string identifier, falling back to 'category'.
  static CuratedIconPair get(String? id) {
    if (id == null || id.isEmpty) return _index['category']!;
    return _index[id] ?? _index['category']!;
  }

  /// Resolves a persisted Material codePoint to a compile-time constant [IconData]
  /// so Flutter release icon tree-shaking remains intact.
  static IconData resolveCodePoint(
    int codePoint, {
    IconData fallback = Icons.savings_outlined,
  }) =>
      _codePointIndex[codePoint] ?? fallback;

  /// Unique functional domains represented in the catalog.
  static List<String> get domains =>
      allIcons.map((i) => i.domain).toSet().toList(growable: false);

  /// Filter icons belonging to a specific domain.
  static List<CuratedIconPair> forDomain(String domain) =>
      allIcons.where((i) => i.domain == domain).toList(growable: false);
}


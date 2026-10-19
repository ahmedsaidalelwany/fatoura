import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:fatoura/features/shop_setup/domain/repositories/shop_profile_repository.dart';

class ShopProfileRepositoryImpl implements ShopProfileRepository {
  final HiveDatabase database;

  ShopProfileRepositoryImpl(this.database);

  static const String _key = 'current_profile';

  @override
  Future<ShopProfile?> getProfile() async {
    final box = database.shopProfileBox;
    final map = box.get(_key);
    if (map == null) return null;
    return ShopProfile.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  Future<void> saveProfile(ShopProfile profile) async {
    final box = database.shopProfileBox;
    await box.put(_key, profile.toMap());
  }

  @override
  Future<bool> hasCompletedSetup() async {
    final profile = await getProfile();
    return profile != null && profile.name.trim().isNotEmpty;
  }
}

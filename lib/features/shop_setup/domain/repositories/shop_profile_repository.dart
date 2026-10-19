import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';

abstract class ShopProfileRepository {
  Future<ShopProfile?> getProfile();
  Future<void> saveProfile(ShopProfile profile);
  Future<bool> hasCompletedSetup();
}

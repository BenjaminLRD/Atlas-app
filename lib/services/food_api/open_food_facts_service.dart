import 'package:http/http.dart' as http;
import '../../models/food_item.dart';
import '../food/openfoodfacts_service.dart' as new_off;

export '../food/openfoodfacts_service.dart' show OpenFoodFactsException;

/// Interface for external food database service.
abstract class OpenFoodFactsService {
  Future<FoodItem?> getProductByBarcode(String barcode);
}

/// HTTP implementation of OpenFoodFactsService delegating to new unified OpenFoodFactsService.
class HttpOpenFoodFactsService implements OpenFoodFactsService {
  final new_off.OpenFoodFactsService _service;

  HttpOpenFoodFactsService([http.Client? client])
    : _service = new_off.OpenFoodFactsService(httpClient: client);

  @override
  Future<FoodItem?> getProductByBarcode(String barcode) =>
      _service.getProductByBarcode(barcode);
}

import Foundation
import Observation

@Observable
@MainActor
final class GrocyAPIClient {
    private let baseURL: String
    private let apiKey: String
    
    private var urlSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    
    init(baseURL: String, apiKey: String) {
        // Normalise: strip trailing slash, ensure no /api suffix confusion
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") { url.removeLast() }
        self.baseURL = url
        self.apiKey = apiKey
    }
    
    // MARK: - Request Builder
    
    private func request(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/api\(path)") else { throw NetworkError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "GROCY-API-KEY")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }
    
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        switch http.statusCode {
        case 200...299: break
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        default:
            let msg = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(http.statusCode, msg)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    private func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        switch http.statusCode {
        case 200...299: break
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        default:
            let msg = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(http.statusCode, msg)
        }
    }
    
    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let data = try encoder.encode(body)
        let req = try request(path, method: "POST", body: data)
        return try await perform(req)
    }
    
    private func postVoid<Body: Encodable>(_ path: String, body: Body) async throws {
        let data = try encoder.encode(body)
        let req = try request(path, method: "POST", body: data)
        try await performVoid(req)
    }
    
    // MARK: - System
    
    func getSystemInfo() async throws -> SystemInfo {
        try await perform(try request("/system/info"))
    }
    
    func getDBChangedTime() async throws -> DBChangedTime {
        try await perform(try request("/system/db-changed-time"))
    }
    
    // MARK: - Stock
    
    func getStock() async throws -> [StockItem] {
        try await perform(try request("/stock"))
    }
    
    func getVolatileStock(dueSoonDays: Int = 5) async throws -> VolatileStock {
        try await perform(try request("/stock/volatile?due_soon_days=\(dueSoonDays)"))
    }
    
    func getProductDetails(id: Int) async throws -> ProductDetails {
        try await perform(try request("/stock/products/\(id)"))
    }
    
    func getProductEntries(id: Int) async throws -> [StockEntry] {
        try await perform(try request("/stock/products/\(id)/entries"))
    }
    
    func getProductPriceHistory(id: Int) async throws -> [ProductPriceHistory] {
        try await perform(try request("/stock/products/\(id)/price-history"))
    }
    
    func addStock(productId: Int, amount: Double, bestBeforeDate: String? = nil, price: Double? = nil, locationId: Int? = nil, note: String? = nil) async throws -> [StockLogEntry] {
        struct Body: Encodable {
            let amount: Double
            let bestBeforeDate: String?
            let price: Double?
            let locationId: Int?
            let note: String?
        }
        return try await post("/stock/products/\(productId)/add", body: Body(amount: amount, bestBeforeDate: bestBeforeDate, price: price, locationId: locationId, note: note))
    }
    
    func consumeStock(productId: Int, amount: Double, spoiled: Bool = false, locationId: Int? = nil) async throws -> [StockLogEntry] {
        struct Body: Encodable {
            let amount: Double
            let spoiled: Bool
            let locationId: Int?
        }
        return try await post("/stock/products/\(productId)/consume", body: Body(amount: amount, spoiled: spoiled, locationId: locationId))
    }
    
    func openStock(productId: Int, amount: Double = 1) async throws -> [StockLogEntry] {
        struct Body: Encodable { let amount: Double }
        return try await post("/stock/products/\(productId)/open", body: Body(amount: amount))
    }
    
    func transferStock(productId: Int, amount: Double, fromLocationId: Int, toLocationId: Int) async throws -> [StockLogEntry] {
        struct Body: Encodable {
            let amount: Double
            let locationIdFrom: Int
            let locationIdTo: Int
        }
        return try await post("/stock/products/\(productId)/transfer", body: Body(amount: amount, locationIdFrom: fromLocationId, locationIdTo: toLocationId))
    }
    
    func inventoryStock(productId: Int, newAmount: Double, bestBeforeDate: String? = nil, locationId: Int? = nil) async throws -> [StockLogEntry] {
        struct Body: Encodable {
            let newAmount: Double
            let bestBeforeDate: String?
            let locationId: Int?
        }
        return try await post("/stock/products/\(productId)/inventory", body: Body(newAmount: newAmount, bestBeforeDate: bestBeforeDate, locationId: locationId))
    }
    
    // MARK: - Products / Metadata
    
    func getProducts() async throws -> [Product] {
        try await perform(try request("/objects/products"))
    }
    
    func getLocations() async throws -> [Location] {
        try await perform(try request("/objects/locations"))
    }
    
    func getQuantityUnits() async throws -> [QuantityUnit] {
        try await perform(try request("/objects/quantity_units"))
    }
    
    func getProductGroups() async throws -> [ProductGroup] {
        try await perform(try request("/objects/product_groups"))
    }
    
    // MARK: - Shopping List
    
    func getShoppingLists() async throws -> [ShoppingList] {
        try await perform(try request("/objects/shopping_lists"))
    }
    
    func getShoppingListItems(listId: Int? = nil) async throws -> [ShoppingListItem] {
        let path = listId.map { "/objects/shopping_list?query[]=shopping_list_id%3D\($0)" } ?? "/objects/shopping_list"
        return try await perform(try request(path))
    }
    
    func addShoppingListItem(productId: Int?, note: String?, amount: Double = 1, shoppingListId: Int = 1, quId: Int? = nil) async throws -> CreatedObjectResponse {
        struct Body: Encodable {
            let productId: Int?
            let note: String?
            let amount: Double
            let shoppingListId: Int
            let quId: Int?
        }
        return try await post("/objects/shopping_list", body: Body(productId: productId, note: note, amount: amount, shoppingListId: shoppingListId, quId: quId))
    }
    
    func updateShoppingListItem(id: Int, done: Bool) async throws {
        struct Body: Encodable { let done: Int }
        let data = try encoder.encode(Body(done: done ? 1 : 0))
        let req = try request("/objects/shopping_list/\(id)", method: "PUT", body: data)
        try await performVoid(req)
    }
    
    func deleteShoppingListItem(id: Int) async throws {
        let req = try request("/objects/shopping_list/\(id)", method: "DELETE")
        try await performVoid(req)
    }
    
    func clearShoppingList(listId: Int = 1, doneItemsOnly: Bool = false) async throws {
        struct Body: Encodable {
            let listId: Int
            let doneItemsOnly: Bool
        }
        let data = try encoder.encode(Body(listId: listId, doneItemsOnly: doneItemsOnly))
        let req = try request("/shopping-list/clear", method: "POST", body: data)
        try await performVoid(req)
    }
    
    func addMissingProductsToShoppingList(listId: Int = 1) async throws {
        struct Body: Encodable { let listId: Int }
        let data = try encoder.encode(Body(listId: listId))
        let req = try request("/shopping-list/add-missing-products", method: "POST", body: data)
        try await performVoid(req)
    }
    
    // MARK: - Tasks
    
    func getTasks() async throws -> [GrocyTask] {
        try await perform(try request("/tasks"))
    }
    
    func getTaskCategories() async throws -> [TaskCategory] {
        try await perform(try request("/objects/task_categories"))
    }
    
    func completeTask(id: Int, doneTime: Date? = nil) async throws {
        struct Body: Encodable {
            let doneTime: String?
        }
        let timeStr = doneTime.map { DateFormatters.shared.apiDateTime.string(from: $0) }
        let data = try encoder.encode(Body(doneTime: timeStr))
        let req = try request("/tasks/\(id)/complete", method: "POST", body: data)
        try await performVoid(req)
    }
    
    func undoTask(id: Int) async throws {
        let req = try request("/tasks/\(id)/undo", method: "POST")
        try await performVoid(req)
    }
    
    // MARK: - Chores
    
    func getChores() async throws -> [ChoreDetails] {
        try await perform(try request("/chores"))
    }
    
    func executeChore(id: Int, trackedTime: Date? = nil, skipScheduleRescheduling: Bool = false) async throws {
        struct Body: Encodable {
            let trackedTime: String?
            let skipScheduleRescheduling: Bool
        }
        let timeStr = trackedTime.map { DateFormatters.shared.apiDateTime.string(from: $0) }
        let data = try encoder.encode(Body(trackedTime: timeStr, skipScheduleRescheduling: skipScheduleRescheduling))
        let req = try request("/chores/\(id)/execute", method: "POST", body: data)
        try await performVoid(req)
    }
    
    // MARK: - Recipes
    
    func getRecipes() async throws -> [Recipe] {
        try await perform(try request("/objects/recipes"))
    }
    
    func getRecipePositions(recipeId: Int) async throws -> [RecipePosition] {
        try await perform(try request("/objects/recipes_pos?query[]=recipe_id%3D\(recipeId)"))
    }
    
    func getRecipeFulfillment(recipeId: Int) async throws -> [RecipeFulfillment] {
        try await perform(try request("/recipes/\(recipeId)/fulfillment"))
    }
    
    func addRecipeMissingToShoppingList(recipeId: Int, servings: Double? = nil) async throws {
        struct Body: Encodable { let recipeId: Int; let servings: Double? }
        let data = try encoder.encode(Body(recipeId: recipeId, servings: servings))
        let req = try request("/recipes/\(recipeId)/add-not-fulfilled-products-to-shoppinglist", method: "POST", body: data)
        try await performVoid(req)
    }
    
    func consumeRecipe(recipeId: Int, servings: Double? = nil) async throws {
        struct Body: Encodable { let servings: Double? }
        let data = try encoder.encode(Body(servings: servings))
        let req = try request("/recipes/\(recipeId)/consume", method: "POST", body: data)
        try await performVoid(req)
    }
    
    // MARK: - Meal Plan
    
    func getMealPlan() async throws -> [MealPlanItem] {
        try await perform(try request("/objects/meal_plan"))
    }
    
    func addMealPlanItem(day: String, recipeId: Int, servings: Double = 1) async throws -> CreatedObjectResponse {
        struct Body: Encodable { let day: String; let recipeId: Int; let recipeServings: Double }
        return try await post("/objects/meal_plan", body: Body(day: day, recipeId: recipeId, recipeServings: servings))
    }
    
    func deleteMealPlanItem(id: Int) async throws {
        let req = try request("/objects/meal_plan/\(id)", method: "DELETE")
        try await performVoid(req)
    }
    
    // MARK: - Barcode
    
    func getProductByBarcode(_ barcode: String) async throws -> ProductDetails {
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        return try await perform(try request("/stock/products/by-barcode/\(encoded)"))
    }
    
    func addStockByBarcode(_ barcode: String, amount: Double = 1) async throws -> [StockLogEntry] {
        struct Body: Encodable { let amount: Double }
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        return try await post("/stock/products/by-barcode/\(encoded)/add", body: Body(amount: amount))
    }
    
    func consumeStockByBarcode(_ barcode: String, amount: Double = 1) async throws -> [StockLogEntry] {
        struct Body: Encodable { let amount: Double }
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        return try await post("/stock/products/by-barcode/\(encoded)/consume", body: Body(amount: amount))
    }
    
    func lookupExternalBarcode(_ barcode: String) async throws -> ExternalBarcodeLookup {
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        return try await perform(try request("/stock/barcodes/external-lookup/\(encoded)"))
    }

    // MARK: - Open Food Facts

    /// Fetches product info from Open Food Facts (free, no auth required).
    /// Returns nil if the barcode is not in the OFF database.
    func fetchOpenFoodFacts(barcode: String) async throws -> OFFProduct? {
        let fields = "product_name,product_name_en,brands,quantity,nutriments,image_front_url"
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.setValue("GrocyV2/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: req)
        let offDecoder = JSONDecoder()
        let response = try offDecoder.decode(OFFResponse.self, from: data)
        guard response.status == 1, let product = response.product,
              !product.displayName.isEmpty else { return nil }
        return product
    }

    /// Fetches product info from UPC Item DB — better coverage for US grocery products.
    /// Returns nil if not found or rate-limited.
    func fetchUPCItemDB(barcode: String) async throws -> OFFProduct? {
        guard let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(barcode)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("GrocyV2/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { return nil }
        let decoded = try JSONDecoder().decode(UPCItemDBResponse.self, from: data)
        guard decoded.code == "OK", let item = decoded.items?.first,
              let name = item.title, !name.isEmpty else { return nil }
        // Map to OFFProduct so the rest of the UI can treat it uniformly
        return OFFProduct(
            productName: name,
            productNameEn: nil,
            brands: item.brand,
            quantity: item.size,
            nutriments: nil,
            imageFrontUrl: item.images?.first
        )
    }

    // MARK: - Product Creation

    struct NewProductBody: Encodable {
        let name: String
        let locationId: Int
        let quIdPurchase: Int
        let quIdStock: Int
        let quIdConsume: Int
        let quIdPrice: Int
        let calories: Double?
        let description: String?
    }

    struct NewBarcodeBody: Encodable {
        let productId: Int
        let barcode: String
    }

    /// Creates a new product in Grocy, returns the new product id.
    func createProduct(name: String, calories: Double?, description: String?, defaultQuId: Int, defaultLocationId: Int) async throws -> Int {
        let body = NewProductBody(
            name: name,
            locationId: defaultLocationId,
            quIdPurchase: defaultQuId,
            quIdStock: defaultQuId,
            quIdConsume: defaultQuId,
            quIdPrice: defaultQuId,
            calories: calories,
            description: description
        )
        let result: CreatedObjectResponse = try await post("/objects/products", body: body)
        return result.createdObjectId
    }

    /// Links a barcode string to an existing Grocy product.
    func linkBarcode(productId: Int, barcode: String) async throws {
        let body = NewBarcodeBody(productId: productId, barcode: barcode)
        try await postVoid("/objects/product_barcodes", body: body)
    }

    // MARK: - Files
    
    func productPictureURL(filename: String, height: Int = 200) -> URL? {
        let b64 = Data(filename.utf8).base64EncodedString()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return URL(string: "\(baseURL)/api/files/productpictures/\(b64)?force_serve_as=picture&best_fit_height=\(height)&GROCY-API-KEY=\(apiKey)")
    }
}

import Foundation
import Observation

@Observable
@MainActor
final class StockViewModel {
    var stockItems: [StockItem] = []
    var products: [Product] = []
    var locations: [Location] = []
    var quantityUnits: [QuantityUnit] = []
    var productGroups: [ProductGroup] = []
    var isLoading = false
    var error: String?
    var searchText = ""
    var selectedGroupId: Int? = nil

    var filteredItems: [StockItem] {
        var items = stockItems
        if !searchText.isEmpty {
            items = items.filter { item in
                item.product?.name.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        if let gid = selectedGroupId {
            items = items.filter { $0.product?.productGroupId == gid }
        }
        return items.sorted { ($0.product?.name ?? "") < ($1.product?.name ?? "") }
    }

    var groupedItems: [(group: String, items: [StockItem])] {
        let grouped = Dictionary(grouping: filteredItems) { item -> String in
            if let gid = item.product?.productGroupId,
               let group = productGroups.first(where: { $0.id == gid }) {
                return group.name
            }
            return "Other"
        }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    func load(client: GrocyAPIClient) async {
        isLoading = true
        error = nil
        do {
            async let stockResult = client.getStock()
            async let productsResult = client.getProducts()
            async let locationsResult = client.getLocations()
            async let unitsResult = client.getQuantityUnits()
            async let groupsResult = client.getProductGroups()
            stockItems = try await stockResult
            products = try await productsResult
            locations = try await locationsResult
            quantityUnits = try await unitsResult
            productGroups = try await groupsResult
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addStock(client: GrocyAPIClient, productId: Int, amount: Double, bestBeforeDate: String? = nil, price: Double? = nil, locationId: Int? = nil) async throws {
        _ = try await client.addStock(productId: productId, amount: amount, bestBeforeDate: bestBeforeDate, price: price, locationId: locationId)
        await load(client: client)
    }

    func consumeStock(client: GrocyAPIClient, productId: Int, amount: Double, spoiled: Bool = false) async throws {
        _ = try await client.consumeStock(productId: productId, amount: amount, spoiled: spoiled)
        await load(client: client)
    }

    func quickAdd(client: GrocyAPIClient, productId: Int) async {
        do {
            _ = try await client.addStock(productId: productId, amount: 1)
            await load(client: client)
        } catch {}
    }

    func quickConsume(client: GrocyAPIClient, productId: Int) async {
        do {
            _ = try await client.consumeStock(productId: productId, amount: 1)
            await load(client: client)
        } catch {}
    }

    func unitName(for quId: Int?) -> String {
        guard let id = quId else { return "" }
        return quantityUnits.first(where: { $0.id == id })?.name ?? ""
    }

    func locationName(for locationId: Int?) -> String {
        guard let id = locationId else { return "" }
        return locations.first(where: { $0.id == id })?.name ?? ""
    }
}

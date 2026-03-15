import Foundation
import Observation

@Observable
@MainActor
final class ShoppingViewModel {
    var items: [ShoppingListItem] = []
    var shoppingLists: [ShoppingList] = []
    var selectedListId: Int = 1
    var isLoading = false
    var error: String?
    var searchText = ""
    var products: [Product] = []
    var productGroups: [ProductGroup] = []
    var quantityUnits: [QuantityUnit] = []

    var pendingItems: [ShoppingListItem] {
        items.filter { !$0.isDone }
    }

    var doneItems: [ShoppingListItem] {
        items.filter { $0.isDone }
    }

    var filteredPending: [ShoppingListItem] {
        searchText.isEmpty ? pendingItems : pendingItems.filter {
            $0.product?.name.localizedCaseInsensitiveContains(searchText) == true ||
            $0.note?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var groupedPending: [(group: String, items: [ShoppingListItem])] {
        let grouped = Dictionary(grouping: filteredPending) { item -> String in
            if let gid = item.product?.productGroupId,
               let group = productGroups.first(where: { $0.id == gid }) {
                return group.name
            }
            return item.note != nil ? "Notes" : "Other"
        }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    func load(client: GrocyAPIClient) async {
        isLoading = true
        error = nil
        do {
            async let listsResult = client.getShoppingLists()
            async let itemsResult = client.getShoppingListItems(listId: selectedListId)
            async let productsResult = client.getProducts()
            async let groupsResult = client.getProductGroups()
            async let unitsResult = client.getQuantityUnits()
            shoppingLists = try await listsResult
            items = try await itemsResult
            products = try await productsResult
            productGroups = try await groupsResult
            quantityUnits = try await unitsResult
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func toggleDone(client: GrocyAPIClient, item: ShoppingListItem) async {
        do {
            try await client.updateShoppingListItem(id: item.id, done: !item.isDone)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                let current = items[idx]
                let newDone: BoolOrInt = current.isDone ? .int(0) : .int(1)
                items[idx] = ShoppingListItem(
                    id: current.id, productId: current.productId, note: current.note,
                    amount: current.amount, rowCreatedTimestamp: current.rowCreatedTimestamp,
                    shoppingListId: current.shoppingListId, done: newDone, quId: current.quId,
                    product: current.product
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteItem(client: GrocyAPIClient, id: Int) async {
        do {
            try await client.deleteShoppingListItem(id: id)
            items.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addItem(client: GrocyAPIClient, productId: Int?, note: String?, amount: Double = 1) async {
        do {
            _ = try await client.addShoppingListItem(productId: productId, note: note, amount: amount, shoppingListId: selectedListId)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func autoFillMissing(client: GrocyAPIClient) async {
        do {
            try await client.addMissingProductsToShoppingList(listId: selectedListId)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearDone(client: GrocyAPIClient) async {
        do {
            try await client.clearShoppingList(listId: selectedListId, doneItemsOnly: true)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unitName(for quId: Int?) -> String {
        guard let id = quId else { return "" }
        return quantityUnits.first(where: { $0.id == id })?.name ?? ""
    }
}

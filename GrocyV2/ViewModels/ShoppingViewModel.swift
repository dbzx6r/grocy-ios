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
    var locations: [Location] = []

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
            async let productsResult = client.getProducts()
            async let groupsResult = client.getProductGroups()
            async let unitsResult = client.getQuantityUnits()
            async let locationsResult = client.getLocations()
            let (fetchedLists, fetchedProducts, fetchedGroups, fetchedUnits, fetchedLocations) = try await (listsResult, productsResult, groupsResult, unitsResult, locationsResult)
            shoppingLists = fetchedLists
            products = fetchedProducts
            productGroups = fetchedGroups
            quantityUnits = fetchedUnits
            locations = fetchedLocations

            // Correct selectedListId to a real list ID if the default (1) doesn't exist
            if !shoppingLists.isEmpty && !shoppingLists.contains(where: { $0.id == selectedListId }) {
                selectedListId = shoppingLists[0].id
            }

            items = try await client.getShoppingListItems(listId: selectedListId)
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

    func addItem(client: GrocyAPIClient, productId: Int?, note: String?, amount: Double = 1) async throws {
        try await client.addShoppingListItem(productId: productId, note: note, amount: amount, shoppingListId: selectedListId)
        await load(client: client)
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

    /// Called from PutAwayView: purchase each item into stock, then remove the done items from the list.
    func putAway(client: GrocyAPIClient, entries: [PutAwayEntry]) async throws {
        // Step 1: add all items to stock concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask {
                    _ = try await client.addStock(
                        productId: entry.productId,
                        amount: entry.amount,
                        bestBeforeDate: entry.bestBeforeDateString,
                        price: entry.priceDouble,
                        locationId: entry.locationId
                    )
                }
            }
            try await group.waitForAll()
        }
        // Step 2: delete each processed shopping list item by ID (more reliable than bulk clear)
        await withTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask { try? await client.deleteShoppingListItem(id: entry.id) }
            }
        }
        await load(client: client)
    }

    func unitName(for quId: Int?) -> String {
        guard let id = quId else { return "" }
        return quantityUnits.first(where: { $0.id == id })?.name ?? ""
    }

    func createList(client: GrocyAPIClient, name: String) async {
        do {
            try await client.createShoppingList(name: name)
            let updatedLists = try await client.getShoppingLists()
            shoppingLists = updatedLists
            // Switch to the newly created list
            if let newList = updatedLists.last(where: { $0.name == name }) {
                selectedListId = newList.id
                items = (try? await client.getShoppingListItems(listId: selectedListId)) ?? []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCurrentList(client: GrocyAPIClient) async {
        let idToDelete = selectedListId
        do {
            try await client.deleteShoppingList(id: idToDelete)
            shoppingLists.removeAll { $0.id == idToDelete }
            if let first = shoppingLists.first {
                selectedListId = first.id
                items = (try? await client.getShoppingListItems(listId: selectedListId)) ?? []
            } else {
                selectedListId = 1
                items = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

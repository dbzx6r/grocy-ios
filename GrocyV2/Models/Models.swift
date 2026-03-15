// Models.swift
import Foundation

// MARK: - System

struct SystemInfo: Codable {
    let grocyVersion: GrocyVersion
    let phpVersion: String
    let sqliteVersion: String
    
    struct GrocyVersion: Codable {
        let version: String
        let releaseDate: String
        
        enum CodingKeys: String, CodingKey {
            case version = "Version"
            case releaseDate = "ReleaseDate"
        }
    }
}

struct DBChangedTime: Codable {
    let changedTime: String
}

// MARK: - Product

struct Product: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let productGroupId: Int?
    let active: BoolOrInt
    let locationId: Int?
    let shoppingLocationId: Int?
    let quIdPurchase: Int?
    let quIdStock: Int?
    let quIdConsume: Int?
    let quIdPrice: Int?
    let minStockAmount: Double?
    let defaultBestBeforeDays: Int?
    let defaultBestBeforeDaysAfterOpen: Int?
    let defaultBestBeforeDaysAfterFreezing: Int?
    let defaultBestBeforeDaysAfterThawing: Int?
    let pictureFileName: String?
    let enableTareWeightHandling: BoolOrInt?
    let tareWeight: Double?
    let notCheckStockFulfillmentForRecipes: BoolOrInt?
    let calories: Double?
    let cumulateMinStockAmountOfSubProducts: BoolOrInt?
    let dueType: Int?
    let hideOnStockOverview: BoolOrInt?
    let noOwnStock: BoolOrInt?
    let rowCreatedTimestamp: String?
}

// Helper to decode both "0"/"1" strings and actual booleans from Grocy API
enum BoolOrInt: Codable, Equatable {
    case bool(Bool)
    case int(Int)
    
    var isTrue: Bool {
        switch self {
        case .bool(let b): return b
        case .int(let i): return i != 0
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let s = try? container.decode(String.self) {
            self = .int(s == "1" || s == "true" ? 1 : 0)
        } else {
            self = .int(0)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try container.encode(b ? 1 : 0)
        case .int(let i): try container.encode(i)
        }
    }
}

// MARK: - Stock

struct StockItem: Codable, Identifiable {
    let productId: Int
    let amount: Double
    let amountAggregated: Double?
    let bestBeforeDate: String?
    let amountOpened: Double?
    let amountOpenedAggregated: Double?
    let isAggregatedAmount: BoolOrInt?
    let dueScore: Int?
    let product: Product?
    
    var id: Int { productId }
    
    var expiryDate: Date? {
        guard let s = bestBeforeDate, s != "2999-12-31" else { return nil }
        return DateFormatters.shared.apiDate.date(from: s)
    }
    
    var daysUntilExpiry: Int? {
        guard let expiry = expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: expiry).day
    }
    
    var expiryStatus: ExpiryStatus {
        guard let days = daysUntilExpiry else { return .noDate }
        if days < 0 { return .expired }
        if days <= 3 { return .urgent }
        if days <= 7 { return .soon }
        return .fresh
    }
}

enum ExpiryStatus {
    case fresh, soon, urgent, expired, noDate
    
    var color: String {
        switch self {
        case .fresh: return "green"
        case .soon: return "orange"
        case .urgent, .expired: return "red"
        case .noDate: return "gray"
        }
    }
    
    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .soon: return "Soon"
        case .urgent: return "Urgent"
        case .expired: return "Expired"
        case .noDate: return "No date"
        }
    }
}

struct StockEntry: Codable, Identifiable {
    let id: Int
    let productId: Int
    let amount: Double
    let bestBeforeDate: String?
    let purchasedDate: String?
    let stockId: String?
    let price: Double?
    let open: BoolOrInt?
    let opened: BoolOrInt?
    let locationId: Int?
    let rowCreatedTimestamp: String?
    let note: String?
}

struct VolatileStock: Codable {
    let dueSoon: [StockItem]
    let overdue: [StockItem]
    let expired: [StockItem]
    let missing: [MissingProduct]
}

struct MissingProduct: Codable, Identifiable {
    let id: Int
    let name: String?
    let amountMissing: Double?
    let isPartlyInStock: BoolOrInt?
    let product: Product?
}

struct ProductDetails: Codable {
    let product: Product
    let stockAmount: Double?
    let stockAmountAggregated: Double?
    let lastPurchased: String?
    let lastUsed: String?
    let nextBestBeforeDate: String?
    let stockAmountOpened: Double?
    let stockAmountOpenedAggregated: Double?
    let quantityUnitPurchase: QuantityUnit?
    let quantityUnitStock: QuantityUnit?
    let quantityUnitPrice: QuantityUnit?
    let productGroupName: String?
    let locationName: String?
    let defaultDueDateType: String?
}

struct ProductPriceHistory: Codable, Identifiable {
    let date: String
    let price: Double
    let shoppingLocationName: String?
    var id: String { date }
}

// MARK: - Location

struct Location: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let isFreezer: BoolOrInt?
    let rowCreatedTimestamp: String?
}

// MARK: - Quantity Unit

struct QuantityUnit: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let namePlural: String?
    let pluralForms: String?
    let rowCreatedTimestamp: String?
}

// MARK: - Product Group

struct ProductGroup: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let rowCreatedTimestamp: String?
}

// MARK: - Shopping List

struct ShoppingList: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let rowCreatedTimestamp: String?
}

struct ShoppingListItem: Codable, Identifiable {
    let id: Int
    let productId: Int?
    let note: String?
    let amount: Double
    let rowCreatedTimestamp: String?
    let shoppingListId: Int?
    let done: BoolOrInt?
    let quId: Int?
    let product: Product?
    
    var isDone: Bool { done?.isTrue ?? false }
}

// MARK: - Task

struct GrocyTask: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let dueDate: String?
    let done: BoolOrInt?
    let doneTimestamp: String?
    let categoryId: Int?
    let assignedToUserId: Int?
    let userfields: String?
    let rowCreatedTimestamp: String?
    
    var isDone: Bool { done?.isTrue ?? false }
    
    var dueDateParsed: Date? {
        guard let s = dueDate else { return nil }
        return DateFormatters.shared.apiDate.date(from: s)
    }
    
    var isOverdue: Bool {
        guard let d = dueDateParsed, !isDone else { return false }
        return d < .now
    }
}

struct TaskCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let rowCreatedTimestamp: String?
}

// MARK: - Chore

struct Chore: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let periodType: String?
    let periodDays: Double?
    let periodConfig: String?
    let trackDateOnly: BoolOrInt?
    let rolloverPeriod: BoolOrInt?
    let assignmentType: String?
    let assignmentConfig: String?
    let nextExecutionAssignedToUserId: Int?
    let consumeProductOnExecution: BoolOrInt?
    let productId: Int?
    let productAmount: Double?
    let productQuId: Int?
    let startDate: String?
    let rowCreatedTimestamp: String?
    let rescheduledNextExecution: String?
    let rescheduledNextExecutionDate: String?
}

struct ChoreDetails: Codable, Identifiable {
    var id: Int { chore.id }
    let chore: Chore
    let lastTracked: String?
    let nextEstimatedExecutionTime: String?
    let trackCount: Int?
    let nextExecutionAssignedUser: GrocyUser?
    
    var nextDueDate: Date? {
        guard let s = nextEstimatedExecutionTime else { return nil }
        return DateFormatters.shared.apiDateTime.date(from: s)
    }
    
    var isOverdue: Bool {
        guard let d = nextDueDate else { return false }
        return d < .now
    }
}

// MARK: - Recipe

struct Recipe: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let baseServings: Double?
    let desiredServings: Double?
    let notCheckStockFulfillment: BoolOrInt?
    let pictureFileName: String?
    let prepResolutionDays: Int?
    let rowCreatedTimestamp: String?
    let type: String?
    let productId: Int?
}

struct RecipePosition: Codable, Identifiable {
    let id: Int
    let recipeId: Int
    let productId: Int
    let amount: Double
    let quantityUnitId: Int?
    let notCheckStockFulfillment: BoolOrInt?
    let note: String?
    let ingredientGroup: String?
    let onlyCheckSingleUnitInStock: BoolOrInt?
    let variableAmount: String?
    let rowCreatedTimestamp: String?
    let product: Product?
}

struct RecipeFulfillment: Codable, Identifiable {
    let id: Int
    let recipeId: Int?
    let productId: Int?
    let amount: Double?
    let amountInStock: Double?
    let satisfaction: Int?
    let needFulfilled: BoolOrInt?
    let needFulfilledWithShoppingList: BoolOrInt?
    let missingAmount: Double?
    let isNested: BoolOrInt?
    let isIgnored: BoolOrInt?
    let product: Product?
}

// MARK: - Meal Plan

struct MealPlanItem: Codable, Identifiable {
    let id: Int
    let day: String?
    let recipeId: Int?
    let recipeServings: Double?
    let note: String?
    let sectionId: Int?
    let rowCreatedTimestamp: String?
    let recipe: Recipe?
}

// MARK: - User

struct GrocyUser: Codable, Identifiable {
    let id: Int
    let username: String?
    let firstName: String?
    let lastName: String?
    let displayName: String?
    let email: String?
    let pictureFileName: String?
    let rowCreatedTimestamp: String?
}

// MARK: - Barcode

struct ProductBarcode: Codable, Identifiable {
    let id: Int
    let productId: Int
    let barcode: String
    let quId: Int?
    let amount: Double?
    let shoppingLocationId: Int?
    let lastPrice: Double?
    let rowCreatedTimestamp: String?
    let note: String?
    let product: Product?
}

struct ExternalBarcodeLookup: Codable {
    let name: String?
    let barcodes: [String]?
    let productGroup: String?
    let pictureUrl: String?
    let note: String?
    let calories: Double?
}

// MARK: - API Responses

struct CreatedObjectResponse: Codable {
    let createdObjectId: Int
}

struct StockLogEntry: Codable, Identifiable {
    let id: Int
    let productId: Int?
    let amount: Double?
    let bestBeforeDate: String?
    let purchasedDate: String?
    let usedDate: String?
    let spoiled: BoolOrInt?
    let stockId: String?
    let transactionType: String?
    let price: Double?
    let undone: BoolOrInt?
    let openedDate: String?
    let locationId: Int?
    let recipeName: String?
    let correlationId: String?
    let shoppingLocationId: String?
    let userId: Int?
    let rowCreatedTimestamp: String?
}

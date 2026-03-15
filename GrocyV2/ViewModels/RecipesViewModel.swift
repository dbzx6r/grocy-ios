import Foundation
import Observation

@Observable
@MainActor
final class RecipesViewModel {
    var recipes: [Recipe] = []
    var mealPlan: [MealPlanItem] = []
    var isLoading = false
    var error: String?
    var searchText = ""
    var selectedTab: RecipeTab = .recipes
    var selectedWeekOffset: Int = 0

    enum RecipeTab: String, CaseIterable {
        case recipes = "Recipes"
        case mealPlan = "Meal Plan"
    }

    var filteredRecipes: [Recipe] {
        searchText.isEmpty ? recipes : recipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var weekDays: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let monday = cal.date(
            byAdding: .day,
            value: -cal.component(.weekday, from: today) + 2 + (selectedWeekOffset * 7),
            to: today
        ) ?? today
        return (0..<7).compactMap { offset in
            let d = cal.date(byAdding: .day, value: offset, to: monday)
            return d.map { DateFormatters.shared.apiDate.string(from: $0) }
        }
    }

    func mealPlanItems(for day: String) -> [MealPlanItem] {
        mealPlan.filter { $0.day == day }
    }

    func load(client: GrocyAPIClient) async {
        isLoading = true
        error = nil
        do {
            async let recipesResult = client.getRecipes()
            async let mealPlanResult = client.getMealPlan()
            recipes = try await recipesResult
            mealPlan = try await mealPlanResult
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addToMealPlan(client: GrocyAPIClient, day: String, recipeId: Int, servings: Double = 1) async {
        do {
            _ = try await client.addMealPlanItem(day: day, recipeId: recipeId, servings: servings)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeFromMealPlan(client: GrocyAPIClient, id: Int) async {
        do {
            try await client.deleteMealPlanItem(id: id)
            mealPlan.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

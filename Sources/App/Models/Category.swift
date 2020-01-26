import Vapor
import FluentPostgreSQL


final class Category: Codable {
	
	var id: Int?
	var name: String
	
	init(name: String) {
		self.name = name
	}
	
}

extension Category: PostgreSQLModel {}
extension Category: Content {}
extension Category: Migration {}
extension Category: Parameter {}

//to get the category's acronyms
extension Category {
	
	var acronyms: Siblings<Category, Acronym, AcronymCategoryPivot> {
		return siblings()
	}
	
	static func addCategory(_ name: String, to acronym: Acronym, on req: Request) throws -> Future<Void> {
		
		return Category.query(on: req) //Creates a query for this model type on the supplied connection.
			.filter(\.name == name) //Search for a category with the parameter specified
			.first() //Fetch the first result
			.flatMap(to: Void.self) { foundCategory in
			
			if let existingCategory = foundCategory {
				return acronym.categories.attach(existingCategory, on: req).transform(to: ())
			} else { //the provided category doesn't exist
				let category = Category(name: name)
				return category.save(on: req).flatMap(to: Void.self) { savedCategory in
					return acronym.categories.attach(savedCategory, on: req).transform(to: ())
				}
			}
			
		}
		
	}
	
}


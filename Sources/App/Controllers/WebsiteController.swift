import Vapor
import Leaf

struct WebsiteController: RouteCollection {
	
	
	func boot(router: Router) throws {
		
		router.get(use: indexHandler) // "/"
		router.get("acronyms", Acronym.parameter, use: acronymHandler) // "/acronyms/<ACRONYM ID>"
		//router.get("users", User.parameter, use: userHandler) // "/users/<USER ID>"
		router.get("users", use: allUsersHandler) // "/users/"
		router.get("categories", use: allCategoriesHandler) // "/categories/"
		router.get("categories", Category.parameter, use: categoryHandler) // "/categories/<CATEGORY ID>"
		router.get("acronyms", "create", use: createAcronymHandler) // "/acronyms/create"
		router.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler) // "/acronyms/create"
		router.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler) // "/acronyms/<ACRONYM ID>/edit"
		router.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler) // "/acronyms/<ACRONYM ID>/edit"
		router.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler) // "/acronyms/<ACRONYM ID>/delete"
	}
	
	func indexHandler(_ req: Request) throws -> Future<View> {
		
		return Acronym.query(on: req)	//Creates a query for this model type on the supplied connection
			.all()	//Runs the query, collecting all of the results into an array.
			.flatMap(to: View.self) { acronyms in
				let context = IndexContext(title: "Home page", acronyms: acronyms)
				return try req.view().render("index", context)
		}
		
	}
	
	func acronymHandler(_ req: Request) throws -> Future<View> {
		
		return try req.parameters
			.next(Acronym.self) //Grabs the next parameter from the parameter bag.
			.flatMap(to: View.self) { acronym in
				return acronym.user.get(on: req)
					.flatMap(to: View.self) { user in
						let categories = try acronym.categories.query(on: req).all()
						let context = AcronymContext(title: acronym.short, acronym: acronym, user: user, categories: categories)
						return try req.view().render("acronym", context)
				}
		}
		
	}
	
	/*
	func userHandler(_ req: Request) throws -> Future<View> {
	
	return try req.parameters
		.next(User.self)
		.flatMap(to: View.self) { user in
		return try user.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
			let context = UserContext(title: user.name, user: user, acronyms: acronyms)
			return try req.view().render("user", context)
			}
		}
	
	}
	*/
	
	func allUsersHandler(_ req: Request) throws -> Future<View> {
		
		return User.query(on: req)
			.all()
			.flatMap(to: View.self) { users in
				let context = AllUsersContext(users: users)
				return try req.view().render("allUsers", context)
		}
		
	}
	
	func allCategoriesHandler(_ req: Request) throws -> Future<View> {
		
		let categories = Category.query(on: req).all()
		let context = AllCategoriesContext(categories: categories)
		return try req.view().render("allCategories", context)
		
	}
	
	
	func categoryHandler(_ req: Request) throws -> Future<View> {
		
		return try req.parameters
			.next(Category.self)
			.flatMap(to: View.self) { category in
				let acronyms = try category.acronyms.query(on: req).all()
				let context = CategoryContext(title: category.name, category: category, acronyms: acronyms)
				return try req.view().render("category", context)
		}
		
	}
	
	func createAcronymHandler(_ req: Request) throws -> Future<View> {
		
		let context = CreateAcronymContext(users: User.query(on: req).all())
		return try req.view().render("createAcronym", context)
		
	}
	
	
	func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
		
		let acronym = Acronym(short: data.short, long: data.long, userID: data.userID)
		return acronym.save(on: req)
			.flatMap(to: Response.self) { acronym in
				guard let id = acronym.id else { throw Abort(.internalServerError) }
				var categorySaves: [Future<Void>] = []
				for category in data.categories ?? [] {
					try categorySaves.append(
						Category.addCategory(category, to: acronym, on: req))
				}
				let redirect = req.redirect(to: "/acronyms/\(id)")
				return categorySaves.flatten(on: req).transform(to: redirect)
		}
		
	}
	
	func editAcronymHandler(_ req: Request) throws -> Future<View> {
		
		return try req.parameters
			.next(Acronym.self)
			.flatMap(to: View.self) { acronym in
				let users = User.query(on: req).all()
				let categories = try acronym.categories.query(on: req).all()
				let context = EditAcronymContext(acronym: acronym, users: users, categories: categories)
				return try req.view().render("createAcronym", context)
		}
		
	}
	
	func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
		
		return try flatMap(to: Response.self, req.parameters.next(Acronym.self),
						   req.content.decode(CreateAcronymData.self)) { acronym, data in
							acronym.short = data.short
							acronym.long = data.long
							acronym.userID = data.userID
							guard let id = acronym.id else { throw Abort(.internalServerError) }
							
							return acronym.save(on: req).flatMap(to: [Category].self) { _ in
								try acronym.categories.query(on: req).all()
								}.flatMap(to: Response.self) { existingCategories in
									let existingStringArray = existingCategories.map { $0.name }
									let existingSet = Set<String>(existingStringArray)
									let newSet = Set<String>(data.categories ?? [])
									let categoriesToAdd = newSet.subtracting(existingSet)
									let categoriesToRemove = existingSet.subtracting(newSet)
									var categoryResults: [Future<Void>] = []
									for newCategory in categoriesToAdd {
										categoryResults.append(try Category.addCategory(newCategory, to: acronym, on: req))
									}
									
									for categoryNameToRemove in categoriesToRemove {
										let categoryToRemove = existingCategories.first { $0.name == categoryNameToRemove }
										if let category = categoryToRemove {
											categoryResults.append(acronym.categories.detach(category, on: req))
										}
									}
									
									let redirect = req.redirect(to: "/acronyms/\(id)")
									return categoryResults.flatten(on: req).transform(to: redirect)
							}
		}
		
	}
	
	func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
		
		return try req.parameters
			.next(Acronym.self)
			.delete(on: req)
			.transform(to: req.redirect(to: "/"))
		
	}
	
	
}



struct IndexContext: Encodable {
	let title: String
	let acronyms: [Acronym]
}

struct AcronymContext: Encodable {
	let title: String
	let acronym: Acronym
	let user: User
	let categories: Future<[Category]>
}


struct UserContext {
	let title: String
	let user: User
	let acronyms: [Acronym] //created by the user
}

struct AllUsersContext: Encodable {
	let title = "All Users"
	let users: [User]
}

struct CategoryContext: Encodable {
	let title : String
	let category: Category
	let acronyms: Future<[Acronym]>
}

struct AllCategoriesContext: Encodable {
	let title = "All Categories"
	let categories: Future<[Category]>
}

struct CreateAcronymContext: Encodable {
	let title = "Create An Acronym"
	let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
	let title = "Edit Acronym"
	let acronym: Acronym
	let users: Future<[User]>
	let editing = true
	let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
	let userID: User.ID
	let short: String
	let long: String
	let categories: [String]?
}



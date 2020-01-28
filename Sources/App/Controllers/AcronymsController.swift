import Vapor
import Fluent
import Authentication


struct AcronymsController: RouteCollection {
	
	
	func boot(router: Router) throws {
		
		let acronymsRoutes = router.grouped("api", "acronyms") //creates a route group for the path "/api/acronyms"
	
		acronymsRoutes.get(use: getAllHandler) // "/api/acronyms"
		acronymsRoutes.get(Acronym.parameter, use: getHandler) // "/api/acronyms/<ACRONYM ID>"
		acronymsRoutes.get("search", use: searchHandler) // "/api/acronyms/search"
		acronymsRoutes.get("first", use: getFirstHandler) // "/api/acronyms/first"
		acronymsRoutes.get("sorted", use: sortedHandler) // "/api/acronyms/sorted"
		acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler) // "/api/acronyms/<ACRONYM ID>/user"
		acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler) // "api/acronyms/<ACRONYM ID>/categories"

		//protect the routes for creating, editing and deleting an acronym with token authentication
		let tokenAuthMiddleware =  User.tokenAuthMiddleware() //extracts the token out of the request and converts it into a logged user
		let guardAuthMiddleware =  User.guardAuthMiddleware() //ensures the request contains valid authorization
		let protected = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
		protected.post(AcronymCreateData.self, use: createHandler) // "/api/acronyms"
		protected.put(Acronym.parameter, use: updateHandler) // "/api/acronyms/<ACRONYM ID>"
		protected.delete(Acronym.parameter, use: deleteHandler) // "/api/acronyms/<ACRONYM ID>"
		protected.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler) // "/api/acronyms/<ACRONYM ID>/categories/<CATEGORY ID>"
		protected.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler) // "api/acronyms/<ACRONYM ID>/categories/<CATEGORY ID>"
		
	}
	
	//create a new acronym
	func createHandler(_ req: Request, data: AcronymCreateData) throws -> Future<Acronym> {
		
		let user = try req.requireAuthenticated(User.self)//Returns an instance of the supplied type or throws if no instance of that type has been authenticated
		let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())//Returns the model’s ID, throwing an error if the model does not yet have an ID.
		return acronym.save(on: req)//Saves the model, calling either create(...) or update(...) depending on whether the model already has an ID.
		
	}
	
	
	//get all the acronyms
	func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
		return Acronym.query(on: req).all()
	}
	
	
	
	//get a single acronym specified by the request's parameter
	func getHandler(_ req: Request) throws -> Future<Acronym> {
		return try req.parameters.next(Acronym.self)
	}
	

	func updateHandler(_ req: Request) throws -> Future<Acronym> {
		
		return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(AcronymCreateData.self))
		{ acronym, updateData in
			acronym.short = updateData.short
			acronym.long = updateData.long
			let user = try req.requireAuthenticated(User.self)
			acronym.userID = try user.requireID()
			return acronym.save(on: req)
		}
		
	}
	
	func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
		
		return try req.parameters
			.next(Acronym.self)
			.delete(on: req)
			.transform(to: .noContent)
		
	}
	
	func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
		
		guard let searchTerm = req.query[String.self, at: "term"] else {
			throw Abort(.badRequest)
		}
		return Acronym.query(on: req).group(.or) { or in
			or.filter(\.short == searchTerm)
			or.filter(\.long == searchTerm)
			}.all()
		
	}
	
	
	func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
		
		return Acronym.query(on: req)
			.first()
			.unwrap(or: Abort(.notFound))
		
	}
	
	
	func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
		
		return Acronym.query(on: req)
			.sort(\.short, .ascending)
			.all()
		
	}
	
	func getUserHandler(_ req: Request) throws -> Future<User.Public> {
		
		return try req.parameters
			.next(Acronym.self) //fetch the acronym specified in the request's parameter
			.flatMap(to: User.Public.self) { acronym in
			acronym.user.get(on: req).convertToPublic()
		}
		
	}
	
	
	func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
		
		return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self),req.parameters.next(Category.self))
		{ acronym, category in
			return acronym.categories.attach(category, on: req).transform(to: .created) //statut 201
		}
		
	}
	
	
	func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
		
		return try req.parameters
			.next(Acronym.self)
			.flatMap(to: [Category].self) { acronym in
			try acronym.categories.query(on: req).all()
		}
		
	}
	
	
	func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
		
		return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self),req.parameters.next(Category.self))
		{ acronym, category in
			return acronym.categories.detach(category, on: req).transform(to: .noContent) //statut 204
		}
		
	}


	
}


struct AcronymCreateData: Content {
	let short: String
	let long: String
}

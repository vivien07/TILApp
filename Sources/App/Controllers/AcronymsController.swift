import Vapor
import Fluent


struct AcronymsController: RouteCollection {
	
	
	func boot(router: Router) throws {
		
		let acronymsRoutes = router.grouped("api", "acronyms") //creates a route group for the path "/api/acronyms"
		acronymsRoutes.post(Acronym.self, use: createHandler) // "/api/acronyms"
		acronymsRoutes.get(use: getAllHandler) // "/api/acronyms"
		acronymsRoutes.get(Acronym.parameter, use: getHandler) // "/api/acronyms/<ACRONYM ID>"
		acronymsRoutes.put(Acronym.parameter, use: updateHandler) // "/api/acronyms/<ACRONYM ID>"
		acronymsRoutes.delete(Acronym.parameter, use: deleteHandler) // "/api/acronyms/<ACRONYM ID>"
		acronymsRoutes.get("search", use: searchHandler) // "/api/acronyms/search"
		acronymsRoutes.get("first", use: getFirstHandler) // "/api/acronyms/first"
		acronymsRoutes.get("sorted", use: sortedHandler) // "/api/acronyms/sorted"
		acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler) // "/api/acronyms/<ACRONYM ID>/user"
	
	}
	
	//create a new acronym
	func createHandler(_ req: Request, acronym: Acronym) throws -> Future<Acronym> {
			return acronym.save(on: req)
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
		
		return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(Acronym.self)) { acronym, updatedAcronym in
			acronym.short = updatedAcronym.short
			acronym.long = updatedAcronym.long
			acronym.userID = updatedAcronym.userID
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
	
	func getUserHandler(_ req: Request) throws -> Future<User> {
		
		return try req.parameters
			.next(Acronym.self)
			.flatMap(to: User.self) { acronym in
			acronym.user.get(on: req)
		}
		
	}

	
	

	
}

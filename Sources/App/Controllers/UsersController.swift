import Vapor
import Fluent

//the protocol groups collections of routes together for adding to a router
struct UsersController: RouteCollection {
	
	// Registers routes to the incoming router.
	func boot(router: Router) throws {
		
		let usersRoutes = router.grouped("api", "users")
		usersRoutes.post(User.self, use: createHandler) // "/api/users/"
		usersRoutes.get(use: getAllHandler) // "/api/users/"
		usersRoutes.get(User.parameter, use: getHandler) // "/api/users/<USER ID>"
		usersRoutes.get(User.parameter, "acronyms", use: getAcronymsHandler)

	}
	
	func createHandler(_ req: Request, user: User) throws -> Future<User> {
		return user.save(on: req) //saves the decoded user from the request
	}
	
	
	func getAllHandler(_ req: Request) throws -> Future<[User]> {
		return User.query(on: req).all()
	}
	
	
	func getHandler(_ req: Request) throws -> Future<User> {
		return try req.parameters.next(User.self)
	}
	
	
	func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
		
		return try req.parameters.next(User.self).flatMap(to: [Acronym].self) { user in
			try user.acronyms.query(on: req).all()
		}
		
	}
	
}

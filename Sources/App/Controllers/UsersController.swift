import Vapor
import Fluent
import Crypto

//the protocol groups collections of routes together for adding to a router
struct UsersController: RouteCollection {
	
	// Registers routes to the incoming router.
	func boot(router: Router) throws {
		
		let usersRoutes = router.grouped("api", "users")
		
		usersRoutes.get(use: getAllHandler) // "/api/users/"
		usersRoutes.get(User.parameter, use: getHandler) // "/api/users/<USER ID>"
		usersRoutes.get(User.parameter, "acronyms", use: getAcronymsHandler) // "/api/users/<USER ID>/acronyms"
		let basicAuthMiddleware =  User.basicAuthMiddleware(using: BCryptDigest())
		let basicAuthGroup = usersRoutes.grouped(basicAuthMiddleware)
		basicAuthGroup.post("login", use: loginHandler) // "/api/users/login"
		
		//only authenticated users can create other users
		let tokenAuthMiddleware = User.tokenAuthMiddleware()
		let guardAuthMiddleware = User.guardAuthMiddleware()
		let protected = usersRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
		protected.post(User.self, use: createHandler) // "/api/users/"

	}
	
	func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
		user.password = try BCrypt.hash(user.password) //hashes the user's password
		return user.save(on: req).convertToPublic() //saves the decoded user from the request in the DB
	}
	
	
	func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
		return User.query(on: req).decode(data: User.Public.self).all()
	}
	
	
	func getHandler(_ req: Request) throws -> Future<User.Public> {
		return try req.parameters.next(User.self).convertToPublic()
	}
	
	
	func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
		
		return try req.parameters.next(User.self).flatMap(to: [Acronym].self) { user in
			try user.acronyms.query(on: req).all()
		}
		
	}
	
	func loginHandler(_ req: Request) throws -> Future<Token> {
		
		let user = try req.requireAuthenticated(User.self) //Returns an instance of the supplied type. Throws if no instance of that type has been authenticated or if there was a problem.
		let token = try Token.generate(for: user)
		return token.save(on: req)
		
	}
	
}

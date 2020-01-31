import Vapor
import Leaf
import Authentication


struct WebsiteController: RouteCollection {
	
	
	func boot(router: Router) throws {
		
		let authSessionRoutes = router.grouped(User.authSessionsMiddleware()) //reads the cookie from the request and looks up the session ID in the app's session
		authSessionRoutes.get(use: indexHandler) // "/"
		authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler) // "/acronyms/<ACRONYM ID>"
		//router.get("users", User.parameter, use: userHandler) // "/users/<USER ID>"
		authSessionRoutes.get("users", use: allUsersHandler) // "/users/"
		authSessionRoutes.get("categories", use: allCategoriesHandler) // "/categories/"
		authSessionRoutes.get("categories", Category.parameter, use: categoryHandler) // "/categories/<CATEGORY ID>"
		authSessionRoutes.get("login", use: loginHandler)// "/login"
		authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler) // "/login"
		authSessionRoutes.post("logout", use: logoutHandler) // "/logout"
		authSessionRoutes.get("register", use: registerHandler) // "/register"
		authSessionRoutes.post(RegisterData.self, at: "register", use: registerPostHandler)
		
		let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))//unauthenticated users are redirected to "/login"
		protectedRoutes.get("acronyms", "create", use: createAcronymHandler) // "/acronyms/create"
		protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler) // "/acronyms/create"
		protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler) // "/acronyms/<ACRONYM ID>/edit"
		protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler) // "/acronyms/<ACRONYM ID>/edit"
		protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler) // "/acronyms/<ACRONYM ID>/delete"
		
	}
	
	func indexHandler(_ req: Request) throws -> Future<View> {
		
		return Acronym.query(on: req)	//Creates a query for this model type on the supplied connection
			.all()	//Runs the query, collecting all of the results into an array.
			.flatMap(to: View.self) { acronyms in
				let userLoggedIn = try req.isAuthenticated(User.self) //Returns true if the type has been authenticated.
				let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
				let context = IndexContext(title: "Home page", acronyms: acronyms, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage)
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
		
		let token = try CryptoRandom().generateData(count: 16).base64EncodedString()//create a random token
		let context = CreateAcronymContext(csrfToken: token)
		try req.session()["CSRF_TOKEN"] = token //saves the token into the request's session under the specified key
		return try req.view().render("createAcronym", context)
		
	}
	
	
	func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
		
		let expectedToken = try req.session()["CSRF_TOKEN"]//get the expected token from the session
		try req.session()["CSRF_TOKEN"] = nil
		guard let csrfToken = data.csrfToken, expectedToken == csrfToken else { throw Abort(.badRequest) }
		
		let user = try req.requireAuthenticated(User.self)
		let acronym =  try Acronym(short: data.short, long: data.long, userID: user.requireID())
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
				let categories = try acronym.categories.query(on: req).all()
				let context = EditAcronymContext(acronym: acronym, categories: categories)
				return try req.view().render("createAcronym", context)
		}
		
	}
	
	func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
		
		return try flatMap(to: Response.self, req.parameters.next(Acronym.self),
						   req.content.decode(CreateAcronymData.self)) { acronym, data in
							let user = try req.requireAuthenticated(User.self)
							acronym.short = data.short
							acronym.long = data.long
							acronym.userID = try user.requireID()
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
	
	
	//for authentication
	
	func loginHandler(_ req: Request) throws -> Future<View> {
		
		let context: LoginContext
		if req.query[Bool.self, at: "error"] != nil { //if the request contains an error parameter
			context = LoginContext(loginError: true)
		} else {
			context = LoginContext()
		}
		return try req.view().render("login", context)
		
	}
	
	
	func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
		
		return User.authenticate(username: userData.username, password: userData.password,using: BCryptDigest(), on: req)
			.map(to: Response.self) { user in
			guard let user = user else {
				return req.redirect(to: "/login?error")
			}
			try req.authenticateSession(user) //saves the authenticated User into the session so Vapor can retrieve it later
			return req.redirect(to: "/")
		}
		
	}
	
	
	func logoutHandler(_ req: Request) throws -> Response {
		
		try req.unauthenticateSession(User.self)//deletes the user from the session
		return req.redirect(to: "/")
		
	}
	
	func registerHandler(_ req: Request) throws -> Future<View> {
		
		let context: RegisterContext
		if let message = req.query[String.self, at: "message"] {
			context = RegisterContext(message: message)
		} else {
			context = RegisterContext() //message is nil by default
		}
		return try req.view().render("register", context)
		
	}
	
	func registerPostHandler(_ req: Request, data: RegisterData) throws -> Future<Response> {
		
		
		do {
			try data.validate() //Validates the model, throwing an error if any of the validations fail
		} catch (let error) {
			let redirect: String
			if let error = error as? ValidationError,
				let message = error.reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { //Returns the character set for characters allowed in a query URL component.
				redirect = "/register?message=\(message)"
			} else {
				redirect = "/register?message=Unknown+error"
			}
			return req.future(req.redirect(to: redirect)) //creates a new,succeeded Future
		}
		
		let password = try BCrypt.hash(data.password)
		let user = User(name: data.name, username: data.username, password: password)
		return user.save(on: req).map(to: Response.self) { user in
			try req.authenticateSession(user)//when they register, users are automatically logged in
			return req.redirect(to: "/")
		}
		
	}

	
	
}



struct IndexContext: Encodable {
	let title: String
	let acronyms: [Acronym]
	let userLoggedIn: Bool
	let showCookieMessage: Bool
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
	let csrfToken: String
}

struct EditAcronymContext: Encodable {
	let title = "Edit Acronym"
	let acronym: Acronym
	let editing = true
	let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
	let short: String
	let long: String
	let categories: [String]?
	let csrfToken: String?
}

struct LoginContext: Encodable {
	
	let title = "Log In"
	let loginError: Bool
	
	init(loginError: Bool = false) {
		self.loginError = loginError
	}
	
}


struct LoginPostData: Content {
	let username: String
	let password: String
}

struct RegisterContext: Encodable {
	
	let title = "Register"
	let message: String?
	init(message: String? = nil) {
		self.message = message
	}
	
}

struct RegisterData: Content {
	let name: String
	let username: String
	let password: String
	let confirmPassword: String
}


extension RegisterData: Validatable, Reflectable {
	
	static func validations() throws -> Validations<RegisterData> {
		
		var validations = Validations(RegisterData.self)
		try validations.add(\.name, .ascii) //ensure the name contains only ASCII characters
		try validations.add(\.username, .alphanumeric && .count(3...)) //ensure the username contains only alphanumerics characters
		try validations.add(\.password, .count(8...)) //ensure the password is at least 8 characters long
		//ensures the password matches with the confirmation
		validations.add("passwords match") { model in
			guard model.password == model.confirmPassword else {
				throw BasicValidationError("passwords don’t match")
			}
		}
		return validations
		
	}
	
}


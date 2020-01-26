import Vapor
import Fluent

public func routes(_ router: Router) throws {
	
	let acronymsController = AcronymsController()
	try router.register(collection: acronymsController)
	
	let usersController = UsersController()
	try router.register(collection: usersController)
	
	let websiteController = WebsiteController()
	try router.register(collection: websiteController)
	
	let categoriesController = CategoriesController()
	try router.register(collection: categoriesController)
	
}

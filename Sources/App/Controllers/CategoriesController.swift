import Vapor

struct CategoriesController: RouteCollection {
	
  func boot(router: Router) throws {
	
    let categoriesRoute = router.grouped("api", "categories")
    categoriesRoute.get(use: getAllHandler)
    categoriesRoute.get(Category.parameter, use: getHandler) //"/api/categories/<CATEGORY ID>"
    categoriesRoute.get(Category.parameter, "acronyms", use: getAcronymsHandler) //"/api/categories/<CATEGORY ID>/acronyms"
	
	//protect categories creation
	let tokenAuthMiddleware = User.tokenAuthMiddleware()
	let guardAuthMiddleware = User.guardAuthMiddleware()
	let protected = categoriesRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
	protected.post(Category.self, use: createHandler)
	
	
  }

  func createHandler(_ req: Request, category: Category) throws -> Future<Category> {
    return category.save(on: req)
  }

  func getAllHandler(_ req: Request) throws -> Future<[Category]> {
    return Category.query(on: req).all() //retrieves all the categories from the DB
  }

  func getHandler(_ req: Request) throws -> Future<Category> {
    return try req.parameters.next(Category.self) //retrieves the category extracted from the request's parameter
  }

	
  func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
	
    return try req.parameters
		.next(Category.self)
		.flatMap(to: [Acronym].self) { category in
      		try category.acronyms.query(on: req).all() //returns all the acronyms from the category
    	}
	
  }
	
	
}

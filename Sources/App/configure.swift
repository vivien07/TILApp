import FluentPostgreSQL
import Vapor
import Leaf
import Authentication



/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment,_ services: inout Services) throws {
	
	
    // Register providers first
    try services.register(FluentPostgreSQLProvider())
	try services.register(LeafProvider())
	try services.register(AuthenticationProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
	middlewares.use(FileMiddleware.self) // Serves files in the Public directory
	middlewares.use(SessionsMiddleware.self) //Uses HTTP cookies to save and restore sessions for connecting clients
    services.register(middlewares)
	
	// Register the configured database to the database config.
	var databases = DatabasesConfig()
	let dbConfig = PostgreSQLDatabaseConfig(hostname: "localhost", username: "vapor", database: "vapor", password: "password")
	let database = PostgreSQLDatabase(config: dbConfig)
    databases.add(database: database, as: .psql)
    services.register(databases)

	// Configure migrations; the tables in the DB are created at the app launch
	var migrations = MigrationConfig()
	migrations.add(model: User.self, database: .psql)
	migrations.add(model: Acronym.self, database: .psql)
	migrations.add(model: Category.self, database: .psql)
	migrations.add(model: AcronymCategoryPivot.self, database: .psql)
	migrations.add(model: Token.self, database: .psql)
	migrations.add(migration: AdminUser.self, database: .psql)
    services.register(migrations)
	var commandConfig = CommandConfig.default()
	commandConfig.useFluentCommands()
	services.register(commandConfig)
	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
	
}

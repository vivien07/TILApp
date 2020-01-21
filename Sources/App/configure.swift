import FluentPostgreSQL
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment,_ services: inout Services) throws {
	
    // Register providers first
    try services.register(FluentPostgreSQLProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
	
	// Register the configured database to the database config.
	var databases = DatabasesConfig()
	let dbConfig = PostgreSQLDatabaseConfig(hostname: "localhost", username: "vapor", database: "vapor", password: "password")
	let database = PostgreSQLDatabase(config: dbConfig)
    databases.add(database: database, as: .psql)
    services.register(databases)

    // Configure migrations
	var migrations = MigrationConfig()
	migrations.add(model: Acronym.self, database: .psql)
	migrations.add(model: User.self, database: .psql)
    services.register(migrations)
	
}

import Vapor
import FluentPostgreSQL
import Authentication


final class User: Codable { //A type that can convert itself into and out of an external representation.
	
	var id: UUID?
	var name: String
	var username: String
	var password: String
	
	init(name: String, username: String, password: String) {
		self.name = name
		self.username = username
		self.password = password
	}
	
	//inner class to represent a public view of User
	final class Public: Codable {
		
		var id: UUID?
		var name: String
		var username: String
		
		init(id: UUID?, name: String, username: String) {
			self.id = id
			self.name = name
			self.username = username
		}
		
	}
	
}


extension User: PostgreSQLUUIDModel {}
extension User: Content {} //Convertible to/from content in an HTTP message

extension User: Migration {
	
	//any attempt to create duplicate usernames result in an error
	static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
		
		return Database.create(self, on: connection) { builder in
			try addProperties(to: builder)
			builder.unique(on: \.username) //Adds a unique constraint to a field.
		}
		
	}
	
}

extension User: Parameter {}
extension User.Public: Content {}


//for getting the acronyms of the user
extension User {
	
	var acronyms: Children<User, Acronym> {
		return children(\.userID)
	}
	
}

extension User {
	
	func convertToPublic() -> User.Public {
		return User.Public(id: id, name: name, username: username)
	}
	
}

extension Future where T: User {
	
	func convertToPublic() -> Future<User.Public> {
		return self.map(to: User.Public.self) { user in
			return user.convertToPublic()
		}
	}
	
}

extension User: BasicAuthenticatable {
	
	static let usernameKey: UsernameKey = \User.username
	static let passwordKey: PasswordKey = \User.password
	
}

//Authenticatable via a token
extension User: TokenAuthenticatable {
	typealias TokenType = Token
}

//Types conforming to this protocol can be registered with MigrationConfig to prepare the database before your application runs
struct AdminUser: Migration {
	
	typealias Database = PostgreSQLDatabase
	
	//Runs this migration’s changes on the database
	static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
		
		let password = try? BCrypt.hash("password")
		guard let hashedPassword = password else { fatalError("Failed to create admin user") }
		let user = User(name: "Admin", username: "admin", password: hashedPassword)
		return user.save(on: connection).transform(to: ())
		
	}
	
	//Reverts this migration’s changes on the database. If it is not possible, complete the future with an error.
	static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
		return .done(on: connection)
	}
	
}


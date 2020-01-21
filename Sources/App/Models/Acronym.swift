import Vapor
import FluentPostgreSQL


final class Acronym: Codable {
	
	var id: Int?
	var short: String
	var long: String
	var userID: User.ID
	
	init(short: String, long: String, userID: User.ID) {
		self.short = short
		self.long = long
		self.userID = userID
	}
	
}

extension Acronym: PostgreSQLModel {}
extension Acronym: Migration {}
extension Acronym: Content {}
extension Acronym: Parameter {}

extension Acronym {
	
	var user: Parent<Acronym, User> {
		return parent(\.userID)
	}
	
}

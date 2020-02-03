import Vapor
import Imperial
import Authentication


struct ImperialController: RouteCollection {
	
	func boot(router: Router) throws {
		
		guard let googleCallbackURL = Environment.get("GOOGLE_CALLBACK_URL") else { fatalError("Google callback URL not set") }
		try router.oAuth(from: Google.self, authenticate: "login-google", callback: googleCallbackURL,
						 scope: ["profile", "email"], completion: processGoogleLogin)// "/login-google" is the route the app uses to allow users to log in via Google
		
		guard let githubCallbackURL = Environment.get("GITHUB_CALLBACK_URL") else { fatalError("GitHub callback URL not set") }
		try router.oAuth(from: GitHub.self, authenticate: "login-github", callback: githubCallbackURL, completion: processGitHubLogin)
	
	}
	
	
	func processGoogleLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
		
		return try Google.getUser(on: request).flatMap(to: ResponseEncodable.self) { userInfo in
			
			return User.query(on: request)
				.filter(\.username == userInfo.email)//checks if the user exists in the DB
				.first().flatMap(to: ResponseEncodable.self) { foundUser in
					guard let existingUser = foundUser else {
						//creates a new user and saves it in the session
						let user = User(name: userInfo.name, username: userInfo.email, password: UUID().uuidString)
						return user.save(on: request).map(to: ResponseEncodable.self) { user in
							try request.authenticateSession(user)
							return request.redirect(to: "/")
						}
					}
					try request.authenticateSession(existingUser)
					return request.future(request.redirect(to: "/"))
			}
			
		}
		
	}
	
	
	func processGitHubLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
		
		return try GitHub.getUser(on: request).flatMap(to: ResponseEncodable.self) { userInfo in
			
			return User.query(on: request)
				.filter(\.username == userInfo.login)//checks if the user exists in the DB
				.first().flatMap(to: ResponseEncodable.self) { foundUser in
					guard let existingUser = foundUser else {
						//creates a new user and saves it in the session
						let user = User(name: userInfo.name, username: userInfo.login, password: UUID().uuidString)
						return user.save(on: request).map(to: ResponseEncodable.self) { user in
							try request.authenticateSession(user)
							return request.redirect(to: "/")
						}
					}
					//if the user already exists, authenticate it in the session
					try request.authenticateSession(existingUser)
					return request.future(request.redirect(to: "/"))
			}
			
		}
		
	}
	
	
}


struct GoogleUserInfo: Content {
	let email: String
	let name: String
}

struct GitHubUserInfo: Content {
	let login: String
	let name: String
}


extension Google {
	
	//gets a user's details from the Google API
	static func getUser(on request: Request) throws -> Future<GoogleUserInfo> {
		
		var headers = HTTPHeaders()
		headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken()) //Gets the access token from the current session
		let googleAPIURL = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
		return try request.client().get(googleAPIURL, headers: headers).map(to: GoogleUserInfo.self) { response in
			guard response.http.status == .ok else {
				if response.http.status == .unauthorized {
					throw Abort.redirect(to: "/login-google")
				} else {
					throw Abort(.internalServerError)
				}
			}
			return try response.content.syncDecode(GoogleUserInfo.self) //Parses a Decodable type from this HTTP message
		}
		
	}
	
}

extension GitHub {
	
	//gets a user's details from the GitHub API
	static func getUser(on request: Request) throws -> Future<GitHubUserInfo> {
		
		var headers = HTTPHeaders()
		headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken()) //adds the OAuth token to the authorization header
		let githubUserAPIURL = "https://api.github.com/user"
		return try request.client().get(githubUserAPIURL, headers: headers).map(to: GitHubUserInfo.self) { response in
			guard response.http.status == .ok else {
				if response.http.status == .unauthorized {
					throw Abort.redirect(to: "/login-github")
				} else {
					throw Abort(.internalServerError)
				}
			}
			return try response.content.syncDecode(GitHubUserInfo.self) //Parses a Decodable type from this HTTP message
		}
		
	}
	
}


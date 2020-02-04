// swift-tools-version:4.0
import PackageDescription

let package = Package(
	
	name: "TILApp",
	dependencies: [
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
		.package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"), //templating language to generate dynamic HTML pages
		.package(url: "https://github.com/vapor/auth.git", from: "2.0.0"), //framework for adding authentication
		.package(url: "https://github.com/vapor-community/Imperial.git", from: "0.7.1"), //integrations with Google, Facebook and GitHub
		.package(url: "https://github.com/vapor-community/sendgrid-provider.git", from: "3.0.0") //for emails
	],
	targets: [
		.target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Leaf", "Authentication", "Imperial", "SendGrid"]),
		.target(name: "Run", dependencies: ["App"]),
		.testTarget(name: "AppTests", dependencies: ["App"])
	]
	
)


//
//  apnsManager.swift
//  https://github.com/magnolialogic/swiftui-apnsManager
//
//  Created by Chris Coffin on 7/24/20.
//

import os
import SwiftUI

public class apnsManager: ObservableObject {
	
	
	
	// MARK: Initialization
	
	
	
	// Private init to prevent clients from creating another instance
	private init() {}
	
	// Create shared singleton
	static let shared: apnsManager = apnsManager()
	
	// Create shared background DispatchQueue and shared DispatchGroup
	let serialQueue = DispatchQueue(label: "apnsManager.shared.staticQueue", qos: .userInteractive, target: .global())
	let dispatchGroup = DispatchGroup()
	
	// Root URL for python-apns_server API
	let apiRoute = ProcessInfo.processInfo.environment["apiRoute"]! // If this isn't set we should crash, #@$&! it
	
	
	
	// MARK: User info properties
	
	
	
	// Push Sign In With Apple user credentials to remote notification server
	var userID = UserDefaults.standard.string(forKey: "userID") ?? "" {
		didSet {
			os_log(.debug, "apnsManager.shared.userID set: \(self.userID)")
			UserDefaults.standard.setValue(userID, forKey: "userID")
		}
	}
	
	// Tracks whether user has admin flag set in DB
	@Published var userIsAdmin = false {
		didSet {
			os_log(.debug, "apnsManager.shared.userIsAdmin set: \(self.userIsAdmin)")
		}
	}
	
	// If deviceToken is valid and remoteNotificationServerRegistrationSuccess, update userName on remote notification server if local userName changes
	@Published var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "no name provided" {
		didSet {
			os_log(.debug, "apnsManager.shared.userName set: \(self.userName)")
			UserDefaults.standard.setValue(userName, forKey: "userName")
			if self.signInWithAppleSuccess && self.remoteNotificationServerRegistrationSuccess {
				os_log(.debug, "apnsManager.shared.userName: updating remote notification server")
				updateRemoteNotificationServer()
			}
		}
	}
	
	// Attempt to update remote notification server when deviceToken is changed
	var deviceToken = UserDefaults.standard.string(forKey: "deviceToken") ?? "" {
		didSet {
			os_log(.debug, "apnsManager.shared.deviceToken set: \(self.deviceToken)")
			UserDefaults.standard.setValue(deviceToken, forKey: "deviceToken")
			if self.signInWithAppleSuccess && self.remoteNotificationServerRegistrationSuccess {
				os_log(.debug, "apnsManager.shared.deviceToken: updating remote notification server")
				updateRemoteNotificationServer()
			}
		}
	}
	
	
	
	// MARK: Server interaction tracking
	
	
	
	// Tracks whether APNS registration completed successfully
	@Published var apnsRegistrationSuccess = false {
		didSet {
			os_log(.debug, "apnsManager.shared.apnsRegistrationSuccess set: \(self.apnsRegistrationSuccess)")
		}
	}
	
	// Tracks whether updateRemoteNotificationServer received HTTP response indicating success
	@Published var remoteNotificationServerRegistrationSuccess = UserDefaults.standard.bool(forKey: "remoteNotificationServerRegistrationSuccess") {
		didSet {
			os_log(.debug, "apnsManager.shared.remoteNotificationServerRegistrationSuccess set: \(self.remoteNotificationServerRegistrationSuccess)")
			UserDefaults.standard.setValue(remoteNotificationServerRegistrationSuccess, forKey: "remoteNotificationServerRegistrationSuccess")
			checkForAdminFlag()
		}
	}
	
	// Tracks whether we've completed the Sign In With Apple process
	@Published var signInWithAppleSuccess = UserDefaults.standard.bool(forKey: "signInWithAppleSuccess") {
		didSet {
			os_log(.debug, "apnsManager.shared.signInWithAppleSuccess set: \(self.signInWithAppleSuccess)")
			UserDefaults.standard.setValue(signInWithAppleSuccess, forKey: "signInWithAppleSuccess")
		}
	}
	
	
	
	// MARK: Notification permission methods and properties
	
	
	
	// Request notification permissions
	func requestNotificationsPermission() {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (allowed, error) in
			if allowed {
				os_log(.debug, "appDelegate: User granted permissions for notifications, registering with APNS")
				DispatchQueue.main.async {
					UIApplication.shared.registerForRemoteNotifications()
				}
			} else if (error != nil) {
				os_log(.error, "appDelegate: Error requesting permissions: \(error!.localizedDescription)")
			} else {
				os_log(.default, "appDelegate: Notifications not allowed!")
				DispatchQueue.main.async {
					apnsManager.shared.notificationPermissionStatus = "Denied"
				}
			}
		}
	}
	
	// Get current notification authorization status
	func checkNotificationAuthorizationStatus() {
		UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
			var status: String
			switch settings.authorizationStatus {
			case .notDetermined:
				status = "NotDetermined"
			case .denied:
				status = "Denied"
			case .authorized, .provisional, .ephemeral:
				status = "Allowed"
			@unknown default:
				fatalError("apnsManager.shared.checkNotificationAuthorizationStatus(): Got unexpected value for getNotificationSettings \(settings.authorizationStatus.rawValue.description)")
			}
			DispatchQueue.main.async {
				self.notificationPermissionStatus = status
			}
		})
	}
	
	// Track whether user granted permission for notifications
	@Published var notificationPermissionStatus = "Unknown" {
		didSet {
			os_log(.debug, "apnsManager.shared.notificationPermissionStatus set: \(self.notificationPermissionStatus)")
			if self.notificationPermissionStatus == "Allowed" && !self.apnsRegistrationSuccess {
				os_log(.debug, "apnsManager.shared.notificationPermissionStatus: registering with APNS")
				UIApplication.shared.registerForRemoteNotifications()
			}
		}
	}
	
	// Tracks whether user should be gated or can proceed to app's main view
	var proceedToMainView: Bool {
		self.remoteNotificationServerRegistrationSuccess && self.signInWithAppleSuccess
	}
	
	
	
	// MARK: HTTP request methods
	
	
	
	// Construct HTTP request to send APNS token to remote notification server
	func updateRemoteNotificationServer() {
		// If userName is empty we've signed in with Apple previously, so username should be on remote notification server
		if self.userName == "no name provided" {
			os_log(.debug, "apnsManager.shared.updateRemoteNotificationServer(): userName not set, fetching from remote notification server")
			self.dispatchGroup.enter()
			self.getRemoteUserName() {
				self.dispatchGroup.leave()
			}
		}
		// Construct request URL + payload
		let requestURL = self.apiRoute + self.userID
		guard let url = URL(string: requestURL) else {
			os_log(.error, "apnsManager.shared.updateRemoteNotificationServer(): Failed to create request URL")
			return
		}
		guard let bundleID = Bundle.main.bundleIdentifier else {
			os_log(.error, "apnsManager.shared.updateRemoteNotificationServer(): Failed to read Bundle.main.bundleIdentifier")
			return
		}
		self.dispatchGroup.wait()
		let payload: [String : String] = [
			"bundle-id": bundleID,
			"device-token": self.deviceToken,
			"name": self.userName
		]
		
		// Construct HTTP request
		var request = URLRequest(url: url)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "content-type")
		request.timeoutInterval = 10
		guard let httpBody = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
			os_log(.error, "apnsManager.shared.updateRemoteNotificationServer(): httpBody: Failed to serialize payload JSON")
			return
		}
		request.httpBody = httpBody
		
		// Send HTTP request
		let session = URLSession.shared
		session.dataTask(with: request) { (data, response, error) in
			os_log(.debug, "apnsManager.shared.updateRemoteNotificationServer(): HTTP \(request.httpMethod! as NSObject) \(requestURL), requestData: \(payload)")
			// Check whether we like the HTTP response status code and report success or failure
			if let response = response as? HTTPURLResponse {
				let successResponseCodes = [
					200: "Success",
					201: "Created",
					409: "AlreadyExists"
				]
				os_log(.debug, "apnsManager.shared.updateRemoteNotificationServer(): responseCode: \(response.statusCode) \(successResponseCodes[response.statusCode] as NSObject? ?? "Unknown" as NSObject)")
				DispatchQueue.main.async {
					self.remoteNotificationServerRegistrationSuccess = successResponseCodes.keys.contains(response.statusCode)
				}
			}
			if let data = data {
				do {
					let responseData = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
					os_log(.debug, "apnsManager.shared.updateRemoteNotificationServer(): responseData: \(responseData as! NSObject)")
				} catch {
					os_log(.error, "apnsManager.shared.updateRemoteNotificationServer(): URLSession.dataTask: failed to create request session: \(error as NSObject)")
				}
			}
			if let error = error {
				os_log(.error, "apnsManager.shared.updateRemoteNotificationServer(): URLSession.dataTask caught error: \(error as NSObject)")
			}
		}.resume()
	}
	
	// Fetch admin status for user from remote notification server
	func checkForAdminFlag() {
		// Construct request URL + payload
		let requestURL = self.apiRoute + self.userID
		guard let url = URL(string: requestURL) else {
			os_log(.error, "apnsManager.shared.checkForAdminFlag(): Failed to create request URL")
			return
		}
		
		// Construct HTTP request
		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.setValue("application/json", forHTTPHeaderField: "content-type")
		request.timeoutInterval = 10
		
		// Send HTTP request
		let session = URLSession.shared
		session.dataTask(with: request) { (data, response, error) in
			os_log(.debug, "apnsManager.shared.checkForAdminFlag(): HTTP \(request.httpMethod! as NSObject) \(requestURL)")
			// Check whether we like the HTTP response status code and report success or failure
			if let response = response as? HTTPURLResponse {
				let responseCodes = [
					200: "Success",
					404: "NotFound"
				]
				os_log(.debug, "apnsManager.shared.checkForAdminFlag(): responseCode: \(response.statusCode) \(responseCodes[response.statusCode] as NSObject? ?? "Unknown" as NSObject)")
			}
			if let data = data {
				do {
					let responseData = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as! [String : Any]
					os_log(.debug, "apnsManager.shared.checkForAdminFlag(): responseData: \(responseData)")
					var adminFlag: Bool
					if responseData["admin"] as! String == "True" {
						adminFlag = true
					} else {
						adminFlag = false
					}
					DispatchQueue.main.async {
						self.userIsAdmin = adminFlag
					}
				} catch {
					os_log(.error, "apnsManager.shared.checkForAdminFlag(): URLSession.dataTask: failed to create request session: \(error as NSObject)")
				}
			}
			if let error = error {
				os_log(.error, "apnsManager.shared.checkForAdminFlag(): URLSession.dataTask caught error: \(error as NSObject)")
			}
		}.resume()
	}
	
	// Fetch admin status for user from remote notification server
	func getRemoteUserName(completionHandler: @escaping () -> Void) {
		// Construct request URL + payload
		let requestURL = self.apiRoute + self.userID
		guard let url = URL(string: requestURL) else {
			os_log(.error, "apnsManager.shared.getRemoteUserName():Failed to create request URL")
			return
		}
		
		// Construct HTTP request
		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.setValue("application/json", forHTTPHeaderField: "content-type")
		request.timeoutInterval = 10
		
		// Send HTTP request
		let session = URLSession.shared
		session.dataTask(with: request) { (data, response, error) in
			os_log(.debug, "apnsManager.shared.getRemoteUserName(): HTTP \(request.httpMethod! as NSObject) \(requestURL)")
			// Check whether we like the HTTP response status code and report success or failure
			if let response = response as? HTTPURLResponse {
				let responseCodes = [
					200: "Success",
					404: "NotFound"
				]
				os_log(.debug, "apnsManager.shared.getRemoteUserName(): responseCode: \(response.statusCode) \(responseCodes[response.statusCode] as NSObject? ?? "Unknown" as NSObject)")
				if response.statusCode == 404 {
					os_log(.error, "apnsManager.shared.getRemoteUserName(): User not found!")
					return
				}
			}
			if let data = data {
				do {
					let responseData = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as! [String : Any]
					os_log(.debug, "apnsManager.shared.getRemoteUserName(): responseData: \(responseData)")
					guard let remoteName = responseData["name"] as? String else {
						os_log(.error, "apnsManager.shared.getRemoteUserName(): failed to decode response")
						return
					}
					// Revisit this so SwiftUI will stop yelling at me about updating data from background thread
					if remoteName != self.userName {
						self.serialQueue.async {
							self.userName = remoteName
							completionHandler()
						}
					}
				} catch {
					os_log(.error, "apnsManager.shared.getRemoteUserName(): URLSession.dataTask: failed to create request session: \(error as NSObject)")
				}
			}
			if let error = error {
				os_log(.error, "apnsManager.shared.getRemoteUserName(): URLSession.dataTask caught error: \(error as NSObject)")
			}
		}.resume()
	}
	
	
	
	// MARK: Data Model methods and properties
	
	
	
	func handleAPNSContent(content: [AnyHashable : Any]) {
		if let newData = content["Data"] as? CGFloat {
			os_log(.info, "apnsManager.shared.handleAPNSContent: Received new data: \(content["Data"] as! NSObject)")
			self.size = newData
		} else {
			os_log(.error, "apnsManager.shared.handleAPNSContent: No Data key in notification dictionary!")
		}
	}
	
	@Published var size: CGFloat = 56.0 {
		didSet {
			os_log(.debug, "apnsManager.shared.size set: \(self.size)")
		}
	}
	
}

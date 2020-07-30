//
//  apnsManager.swift
//  https://github.com/magnolialogic/swiftui-apnsManager
//
//  Created by Chris Coffin on 7/24/20.
//

import os
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	
	// willFinishLaunchingWithOptions callback for debugging lifecycle state issues
	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		return true
	}
	
	// didFinishLaunchingWithOptions callback to claim UNUserNotificationCenterDelegate, request notification permissions, and register with APNS
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		UNUserNotificationCenter.current().delegate = self
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (allowed, error) in
			if allowed {
				os_log(.debug, "User granted permissions for notifications, registering with APNS")
				DispatchQueue.main.async {
					application.registerForRemoteNotifications()
				}
			} else if (error != nil) {
				os_log(.error, "Error requesting permissions: \(error!.localizedDescription)")
			} else {
				os_log(.default, "Notifications not allowed!")
			}
		}
		return true
	}
	
	// Callback for successful APNS registration
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		Settings.sharedManager.deviceToken = deviceToken.map { String(format: "%02x", $0)}.joined()
		os_log(.debug, "Successfully registered with APNS")
	}
	
	// Callback for failed APNS registration
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		os_log(.error, "Failed to register with APNS: \(error.localizedDescription)")
	}
	
	// Print current notification settings to debug console
	func getNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			os_log(.debug, "Notification settings: \(settings)")
		}
	}
	
	// Callback for handling user-visible alerts / notification
	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		os_log(.debug, "willPresentNotification: \(notification.debugDescription)")
		completionHandler(UNNotificationPresentationOptions.sound)
	}
	
	// Callback for handling background notifications
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		os_log(.debug, "didReceiveRemoteNotification: \(userInfo.debugDescription)")
		completionHandler(UIBackgroundFetchResult.newData)
	}
}

class Settings: ObservableObject {
	
	// Private init to prevent clients from creating another instance
	private init() {}
	
	// Create shared singleton
	static let sharedManager: Settings = Settings()
	
	// If deviceToken is valid and successfulTokenSubmission, update name on remote notification server if local name changes
	@Published var name: String = UserDefaults.standard.string(forKey: "name") ?? "no name provided" {
		didSet {
			UserDefaults.standard.setValue(name, forKey: "name")
			let token = self.deviceToken
			if !token.isEmpty && self.successfulTokenSubmission {
				updateDeviceTokenServerRecord(key: token, userName: name)
			}
		}
	}
	
	// Attempt to update remote notification server when deviceToken is changed
	@Published var deviceToken = UserDefaults.standard.string(forKey: "deviceToken") ?? "" {
		didSet {
			os_log(.debug, "Settings.sharedManager.deviceToken set: \(self.deviceToken)")
			UserDefaults.standard.setValue(deviceToken, forKey: "deviceToken")
			updateDeviceTokenServerRecord(key: deviceToken, userName: self.name)
		}
	}
	
	// Tracks whether updateDeviceTokenServerRecord received HTTP response indicating success
	@Published var successfulTokenSubmission = UserDefaults.standard.bool(forKey: "successfulTokenSubmission") {
		didSet {
			os_log(.debug, "Settings.sharedManager.successfulTokenSubmission set: \(self.successfulTokenSubmission)")
			UserDefaults.standard.setValue(successfulTokenSubmission, forKey: "successfulTokenSubmission")
		}
	}
	
	// Construct HTTP request to send APNS token to remote notification server
	func updateDeviceTokenServerRecord(key: String, userName: String) {
		
		// Construct request URL
		let server = "https://apns.example.com"
		let route = "/route/"
		let restURL = server + route + key
		guard let requestURL = URL(string: restURL) else {
			os_log(.error, "Failed to create request URL")
			return
		}
		
		// Construct request payload
		guard let bundleID = Bundle.main.bundleIdentifier else {
			os_log(.error, "Failed to read Bundle.main.bundleIdentifier")
			return
		}
		let payload: [String: String] = [
			"bundle-id": bundleID,
			"name": userName
		]
		
		// Construct HTTP request
		var request = URLRequest(url: requestURL)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "content-type")
		request.timeoutInterval = 10
		guard let httpBody = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
			os_log(.error, "httpBody: Failed to serialize payload JSON")
			return
		}
		request.httpBody = httpBody
		
		// Send HTTP request
		let session = URLSession.shared
		os_log(.debug, "Registering token with remote notification server: \(server)")
		session.dataTask(with: request) { (data, response, error) in
			os_log(.debug, "HTTP \(request.httpMethod! as NSObject) \(restURL)")
			if let data = data {
				do {
					let requestData = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
					os_log(.debug, "requestData: \(requestData as! NSObject)")
				} catch {
					os_log(.error, "URLSession.dataTask: failed to serialize requestData JSON: \(error as NSObject)")
				}
			}
			
			// Check whether we like the HTTP response status code and report success or failure
			if let response = response as? HTTPURLResponse {
				let successResponses = [
					200: "Success",
					201: "Created",
					409: "AlreadyExists"
				]
				os_log(.debug, "responseData: Status \(response.statusCode) \(successResponses[response.statusCode] as NSObject? ?? "Unknown" as NSObject)")
				DispatchQueue.main.async {
					self.successfulTokenSubmission = successResponses.keys.contains(response.statusCode)
				}
			}
			if let error = error {
				os_log(.error, "URLSession.dataTask caught error: \(error as NSObject)")
			}
		}.resume()
	}
}

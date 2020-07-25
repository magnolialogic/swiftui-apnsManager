//
//  PushNotificationManager.swift
//
//  Created by Chris Coffin on 7/24/20.
//

import os
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (allowed, error) in
			if allowed {
				os_log(.debug, "Notifications allowed, registering for remote notifications")
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
	
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		os_log(.debug, "Successfully registered for remote notifications, got device token: \(deviceToken.map { String(format: "%02x", $0)}.joined())")
	}
	
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		os_log(.error, "Failed to register for notifications: \(error.localizedDescription)")
	}
}

//
//  AppDelegate.swift
//  https://github.com/magnolialogic/swiftui-apnsManager
//
//  Created by Chris Coffin on 8/5/20.
//

import os
import SwiftUI

public class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	
	// willFinishLaunchingWithOptions callback for debugging lifecycle state issues
	public func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		return true
	}
	
	// didFinishLaunchingWithOptions callback to claim UNUserNotificationCenterDelegate, request notification permissions, and register with APNS
	// Handles push notification via launchOptions if app is not running and user taps on notification
	public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		UNUserNotificationCenter.current().delegate = self
		apnsManager.shared.checkNotificationAuthorizationStatus()
		if apnsManager.shared.notificationPermissionStatus == "Allowed" {
			apnsManager.shared.requestNotificationsPermission()
		}
		return true
	}
	
	// Callback for successful APNS registration
	public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		apnsManager.shared.deviceToken = deviceToken.map { String(format: "%02x", $0)}.joined()
		apnsManager.shared.apnsRegistrationSuccess = true
	}
	
	// Callback for failed APNS registration
	public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		apnsManager.shared.apnsRegistrationSuccess = false
		os_log(.error, "appDelegate: Failed to register with APNS: \(error.localizedDescription)")
	}
	
	// Print current notification settings to debug console
	func getNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			os_log(.debug, "appDelegate: Notification settings: \(settings)")
		}
	}
	
	// Callback for handling background notifications
	public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		os_log(.debug, "appDelegate: didReceiveRemoteNotification: \(userInfo.debugDescription)")
		if let apsPayload = userInfo["aps"] as? [String: AnyObject] {
			if apsPayload["content-available"] as? Int == 1 {
				// Handle silent notification content
				apnsManager.shared.handleAPNSContent(content: userInfo)
			} else {
				// Got user-facing notification
			}
			completionHandler(.newData)
		} else {
			completionHandler(.failed)
		}
	}
}

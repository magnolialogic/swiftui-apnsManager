# swiftui-PushNotificationManager
Easy APNS support for SwiftUI apps

Import `PushNotificationManager.swift` into your Xcode project to easily request push notification permissions and register with APNS.

### Setup

Simply add a `NotificationCenter @StateObject` and an `AppDelegate @UIApplicationDelegateAdaptor` to your `@main` block like so:

```
import os
import SwiftUI

@main
struct MySwiftUIApp: App {
	@StateObject var notificationCenter = NotificationCenter()
	@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}
```

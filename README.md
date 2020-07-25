# swiftui-PushNotificationManager
Easy APNS support for SwiftUI apps

Check out and add `PushNotificationManager.swift` to your Xcode project to easily request user permissions for push notifications on launch, and if allowed register with APNS and log device token.

### Implementation

Simply add `@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate` to your `@main` block like so:

```
import os
import SwiftUI

@main
struct MySwiftUIApp: App {
	@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}
```

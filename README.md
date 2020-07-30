# swiftui-apnsManager
Easy APNS support for SwiftUI apps

Add two lines of code to your SwiftUI app to handle requesting user permissions for notifications, and if allowed fetch a device token from APNS and upload it to [your remote notification server](https://github.com/magnolialogic/python-apns_server).

*Requires Xcode 12 / iOS 14*

## Implementation

1. Check out `PushNotificationManager.swift` and add to your Xcode 12 project
2. Add `@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate` to your `@main` block and `@ObservedObject var settings = Settings.sharedManager` to your ContentView like so:

#### MyApp.swift
```swift
import SwiftUI

@main
struct MyApp: App {
	@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}
```

#### ContentView.swift
```swift
import os
import SwiftUI

struct ContentView: View {
	@ObservedObject var settings = Settings.sharedManager
	
	var body: some View {
		Spacer()
		
		Text("Listening for push notifications...")
		
		Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		ContentView()
    }
}
```

#### Example console output
```
MyApp[1242:132836] User granted permissions for notifications, registering with APNS
MyApp[1242:132792] AppDelegate.deviceToken set: fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0cecf33b5b5530
MyApp[1242:132792] Settings.sharedManager.deviceToken set: fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0cecf33b5b5530
MyApp[1242:132792] Registering token with remote notification server: https://apns.example.com
MyApp[1242:132792] Successfully registered with APNS
MyApp[1242:132834] HTTP PUT https://apns.example.com/route/fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0cecf33b5b5530
MyApp[1242:132834] requestData: {
    "bundle-id" = "com.example.MyApp";
    "device-token" = fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0cecf33b5b5530;
    name = "Test";
}
MyApp[1242:132834] responseData: Status 409 AlreadyExists
MyApp[1242:132792] Settings.successfulTokenSubmission set: true
MyApp[1242:132792] Got background notification: [AnyHashable("Data"): 1, AnyHashable("aps"): {
    "content-available" = 1;
}]
```

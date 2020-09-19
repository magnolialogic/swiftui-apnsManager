# swiftui-apnsManager
SwiftUI package that allows you to gate access to your app's main view until user has completed Sign In With Apple and granted permission for push notifications.

Handles requesting user permissions for notifications, registering with APNS server and receiving device token, implements Sign In With Apple, and and uploads user ID + device token to [your remote notification server](https://github.com/magnolialogic/python-apns_server).

*Requires Xcode 12 / iOS 14*

## Usage

1. Add to your Xcode 12 / iOS 14 project as a Swift Package Dependency
2. `import APNSManager`
3. Add a Configuration Settings File to your project and define the route to its /user REST API (e.g. `https://apns.example.com/v1/user/`)
4. If you need to manage/track a user's Admin state, add "ADMIN_CHECK" key to Info.plist with value "true"
5. Start with MyExampleApp.swift below

**Note:** these steps result in a read-only library, so when you're ready to start customizing this boilerplate example do a `git clone` onto your local disk and then drag the local folder in to your Xcode sidebar. This will move the library from "Swift Package Dependencies" into your app's resources, and you can edit/update the implementation from there.

#### MyExampleApp.swift
```swift
import APNSManager
import AuthenticationServices
import os
import SwiftUI

@main
struct MyExampleApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    @StateObject var apnsManagedSettings = apnsManager.shared
	
    var body: some Scene {
        WindowGroup {
            if apnsManagedSettings.notificationPermissionStatus == "Unknown" {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if apnsManagedSettings.notificationPermissionStatus == "NotDetermined" {
                GetStartedView().environmentObject(apnsManagedSettings)
            } else if apnsManagedSettings.notificationPermissionStatus == "Denied" {
                NotificationsDeniedView().environmentObject(apnsManagedSettings)
            } else {
                NotificationsAllowedView().environmentObject(apnsManagedSettings)
            }
        }
    }
}

struct GetStartedView: View {
    @EnvironmentObject var apnsManagedSettings: apnsManager
	
    var body: some View {
        VStack {
            Spacer()
            Button(action: {
                apnsManagedSettings.requestNotificationsPermission()
            }, label: {
                Text("Get Started")
            })
            Text("Note: push notification permissions are required!")
                .font(.system(size: 10))
                .padding(.top, 10)
            Spacer()
        }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification), perform: { _ in
            apnsManagedSettings.checkNotificationAuthorizationStatus()
        })
    }
}

struct NotificationsDeniedView: View {
    @EnvironmentObject var apnsManagedSettings: apnsManager
	
    var body: some View {
        if apnsManagedSettings.notificationPermissionStatus == "Denied" {
            VStack {
                Spacer()
                Text("Notifications permissions are required")
                Button(action: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                }, label: {
                    Text("Enable in Settings")
                        .padding(.top, 20)
                })
                Spacer()
            }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification), perform: { _ in
                apnsManagedSettings.checkNotificationAuthorizationStatus()
            })
        } else {
            NotificationsAllowedView()
        }
    }
}

struct NotificationsAllowedView: View {
    @EnvironmentObject var apnsManagedSettings: apnsManager
	
    var body: some View {
        if apnsManagedSettings.proceedToMainView {
            MyExampleMainView()
        } else {
            Spacer()
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName]
                },
                onCompletion: { result in
                    switch result {
                    case .success (let authResults):
                        let authCredential = authResults.credential as! ASAuthorizationAppleIDCredential
                        let authCredentialUserID = authCredential.user
                        apnsManagedSettings.userID = authCredentialUserID
                        let userName = authCredential.fullName?.givenName ?? ""
                        if !userName.isEmpty {
                            apnsManagedSettings.userName = userName
                        }
                        apnsManagedSettings.updateRemoteNotificationServer()
                        DispatchQueue.main.async {
                            apnsManagedSettings.signInWithAppleSuccess = true
                        }
                    case.failure (let error):
                        os_log(.error, "Authorization failed: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            apnsManagedSettings.signInWithAppleSuccess = false
                        }
                    }
                }
            )
            .frame(width: 280, height: 60, alignment: .center)
            Spacer()
        }
    }
}

extension UserDefaults {
    func valueExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
```

#### Example console output
```
MyApp[15355:2946298] apnsManager.shared.notificationPermissionStatus set: NotDetermined
MyApp[15355:2946599] appDelegate: User granted permissions for notifications, registering with APNS
MyApp[15355:2946298] apnsManager.shared.deviceToken set: fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0ce
MyApp[15355:2946298] apnsManager.shared.apnsRegistrationSuccess set: true
MyApp[15355:2946298] apnsManager.shared.notificationPermissionStatus set: Allowed
MyApp[15355:2946298] apnsManager.shared.userID set: 1234567890
MyApp[15355:2946298] apnsManager.shared.userName set: Test User 1
MyApp[15355:2946718] apnsManager.shared.updateRemoteNotificationServer(): HTTP PUT https://apns.example.com/v1/user/1234567890, requestData: ["bundle-id": "com.example.MyApp", "device-token": "fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0ce", "name": "Test User 1"]
MyApp[15355:2946718] apnsManager.shared.updateRemoteNotificationServer(): responseCode: 200 Success
MyApp[15355:2946718] apnsManager.shared.updateRemoteNotificationServer(): responseData: User 1234567890 updated
MyApp[15355:2946298] apnsManager.shared.remoteNotificationServerRegistrationSuccess set: true
MyApp[15355:2946719] apnsManager.shared.checkForAdminFlag(): HTTP GET https://apns.example.com/v1/user/1234567890
MyApp[15355:2946719] apnsManager.shared.checkForAdminFlag(): responseCode: 200 Success
MyApp[15355:2946719] apnsManager.shared.checkForAdminFlag(): responseData: ["name": "Test User 1", "admin": True, "device-tokens": <__NSArrayI 0x2819a7a00>(
cdcadc070ae340a723133db22b9c8a11f05e323c5d60339f45fa9795ec29f130,
fcc37fb74f2506277739c1e343c535f131447327105e23ad2a0ce
)
, "user-id": 1234567890]
MyApp[15355:2946298] apnsManager.shared.userIsAdmin set: true
MyApp[15355:2946298] appDelegate: didReceiveRemoteNotification: [AnyHashable("aps"): {
    "content-available" = 1;
}, AnyHashable("Data"): 75]
MyApp[15355:2946298] apnsManager.shared.handleAPNSContent: Received new data: 75
MyApp[15355:2946298] apnsManager.shared.size set: 75.0

```

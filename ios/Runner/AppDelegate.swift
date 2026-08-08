import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications


@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {


    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
        [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {


        FirebaseApp.configure()


        UNUserNotificationCenter.current().delegate = self


        Messaging.messaging().delegate = self


        GeneratedPluginRegistrant.register(
            with: self
        )


        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }


    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {

        print("Firebase Token:")
        print(fcmToken ?? "")

    }

}
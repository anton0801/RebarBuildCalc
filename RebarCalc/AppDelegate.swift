import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib
import Combine

infix operator >>>: AdditionPrecedence

private func >>> (
    lhs: @escaping (AppDelegate) -> Void,
    rhs: @escaping (AppDelegate) -> Void
) -> (AppDelegate) -> Void {
    { host in lhs(host); rhs(host) }
}

private func igniteHeat(_ host: AppDelegate) {
    FirebaseApp.configure()
}

private func wireTracker(_ host: AppDelegate) {
    let sdk = AppsFlyerLib.shared()
    sdk.appsFlyerDevKey = Bar.caliperKey
    sdk.appleAppID = Bar.appCode
    sdk.delegate = host
    sdk.deepLinkDelegate = host
    sdk.isDebug = false
}

private func armSignal(_ host: AppDelegate) {
    Messaging.messaging().delegate = host
    UIApplication.shared.registerForRemoteNotifications()
}

private func openWatch(_ host: AppDelegate) {
    UNUserNotificationCenter.current().delegate = host
}

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private let lash = Lash()
    private let tamp = Tamp()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let raise = igniteHeat >>> wireTracker >>> armSignal >>> openWatch
        raise(self)

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            tamp.tamp(remote)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func onActivation() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: BarKey.attStatus)
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }

    fileprivate func relayBars(_ data: [AnyHashable: Any]) { lash.takeBars(data) }
    fileprivate func relayLaps(_ data: [AnyHashable: Any]) { lash.takeLaps(data) }
    fileprivate func relayPush(_ data: [AnyHashable: Any]) { tamp.tamp(data) }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, err in
            guard err == nil, let t = token else { return }
            UserDefaults.standard.set(t, forKey: BarKey.fcm)
            UserDefaults.standard.set(t, forKey: BarKey.push)
            UserDefaults(suiteName: Bar.suiteBay)?.set(t, forKey: BarKey.sharedFcm)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        relayPush(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        relayPush(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        relayPush(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        relayBars(data)
    }

//    func onConversionDataFail(_ error: Error) {
//        relayBars([
//            "error": true,
//            "error_desc": error.localizedDescription
//        ])
//    }
    func onConversionDataFail(_ error: Error) {
        // print("attribution fail: \(error.localizedDescription)")
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let link = result.deepLink else { return }
        relayLaps(link.clickEvent)
    }
}

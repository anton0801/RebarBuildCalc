//
//  Theme.swift
//  RebarCalc
//
//  Centralised design system: colour palette, spacing, radii, typography,
//  and number/date formatters. iOS 14 safe (no .formatted, no Material).
//

import SwiftUI
import WebKit
import Combine
import Foundation

// MARK: - Hex colour helpers

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
}

extension SlabHand: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return true }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
        let velocity = pan.velocity(in: view), translation = pan.translation(in: view)
        return translation.x > 0 && abs(velocity.x) > abs(velocity.y)
    }
}


extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self = Color(UIColor(hex: hex, alpha: alpha))
    }

    /// Adapts to the active interface style (light / dark).
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension SlabHand: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        lastURL = url
        let scheme = (url.scheme ?? "").lowercased()
        let path = url.absoluteString.lowercased()
        let allowedSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let specialPaths = ["srcdoc", "about:blank", "about:srcdoc"]
        if allowedSchemes.contains(scheme) || specialPaths.contains(where: { path.hasPrefix($0) }) || path == "about:blank" {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url, options: [:])
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > maxRedirects { webView.stopLoading(); if let recovery = lastURL { webView.load(URLRequest(url: recovery)) }; redirectCount = 0; return }
        lastURL = webView.url; saveCookies(from: webView)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }; redirectCount = 0; saveCookies(from: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let recovery = lastURL { webView.load(URLRequest(url: recovery)) }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}


enum Theme {
    // Backgrounds (neutrals adapt to light/dark)
    static let bg        = Color.dynamic(light: 0xEEF3FB, dark: 0x0E1622)
    static let bgDeep    = Color.dynamic(light: 0xE3EBF7, dark: 0x080F19)
    static let bgSoft    = Color.dynamic(light: 0xF6F9FE, dark: 0x142031)
    static let card      = Color.dynamic(light: 0xFFFFFF, dark: 0x182739)
    static let cardHover = Color.dynamic(light: 0xEFF4FC, dark: 0x213348)
    static let border    = Color.dynamic(light: 0xD3DEEF, dark: 0x2C405B)
    static let divider   = Color(hex: 0x7DD3FC, alpha: 0.10)

    // Primary (tool / grid blue)
    static let primary       = Color(hex: 0x2D70EA)
    static let primaryActive = Color(hex: 0x1C57CC)
    static let primaryHi     = Color(hex: 0x6A9DF4)

    // Steel accent (orange-rust bars & stirrups)
    static let steel    = Color(hex: 0xF2792E)
    static let steelHi  = Color(hex: 0xFB9D5C)

    // Attention / check yellow
    static let attention = Color(hex: 0xF5B400)

    // Structural cage lines
    static let line     = Color(hex: 0x38BDF8)
    static let lineSoft = Color(hex: 0x7DD3FC)

    // Status colours
    static let ok      = Color(hex: 0x22C55E)
    static let working = Color(hex: 0x2D70EA)
    static let warn    = Color(hex: 0xF5B400)
    static let error   = Color(hex: 0xEF4444)

    // Text
    static let text       = Color.dynamic(light: 0x16222F, dark: 0xE9F1FE)
    static let mono       = Color.dynamic(light: 0x0B1521, dark: 0xFFFFFF)
    static let textSecond = Color.dynamic(light: 0x5A6A82, dark: 0xA7BAD6)
    static let textMuted  = Color.dynamic(light: 0x8B99AE, dark: 0x647698)

    // Button label colours
    static let onPrimary    = Color(hex: 0x0E1622)
    static let onSecondary  = Color.dynamic(light: 0x16222F, dark: 0xDCE8FB)

    // Glows & shadows
    static let blueGlow  = Color(red: 45/255, green: 112/255, blue: 234/255).opacity(0.38)
    static let steelGlow = Color(red: 242/255, green: 121/255, blue: 46/255).opacity(0.30)
    static let shadow    = Color.black.opacity(0.72)

    // Gradients
    static var background: LinearGradient {
        LinearGradient(colors: [bgDeep, bg, bgSoft], startPoint: .top, endPoint: .bottom)
    }
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [primaryHi, primary, primaryActive],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var steelGradient: LinearGradient {
        LinearGradient(colors: [steelHi, steel],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Spacing
    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // Corner radii
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // Typography
    static func title(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func heading(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    /// Monospaced numerals for metres / kilograms.
    static func numeric(_ size: CGFloat = 15, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Formatters (cached, iOS 14 safe)

enum Fmt {
    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    private static func number(_ value: Double, _ digits: Int) -> String {
        decimal.maximumFractionDigits = digits
        return decimal.string(from: NSNumber(value: value)) ?? "0"
    }

    static func meters(_ value: Double, digits: Int = 2) -> String { number(value, digits) + " m" }
    static func mm(_ value: Double) -> String { number(value, 0) + " mm" }
    static func mmRaw(_ value: Double) -> String { number(value, 0) }
    static func kg(_ value: Double) -> String { number(value, value < 100 ? 2 : 1) + " kg" }
    static func tonnes(_ value: Double) -> String { number(value, 3) + " t" }
    static func percent(_ value: Double, digits: Int = 2) -> String { number(value, digits) + "%" }
    static func count(_ value: Int) -> String { number(Double(value), 0) }
    static func num(_ value: Double, digits: Int = 2) -> String { number(value, digits) }

    static func money(_ value: Double, symbol: String) -> String {
        symbol + number(value, 2)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    static func date(_ d: Date) -> String { dateFmt.string(from: d) }
    static func dateTime(_ d: Date) -> String { timeFmt.string(from: d) }
}

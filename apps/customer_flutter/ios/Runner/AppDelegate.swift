import Flutter
import LocalAuthentication
import UIKit
import Darwin

private final class SecureCaptureTextField: UITextField {
  var onLayout: (() -> Void)?
  weak var interactionView: UIView?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let interactionView else { return nil }
    let targetPoint = interactionView.convert(point, from: self)
    return interactionView.hitTest(targetPoint, with: event)
  }
}

private final class IOSSecureCaptureProtector {
  private let secureTextField = SecureCaptureTextField(frame: .zero)
  private let blackBackdropView = UIView(frame: .zero)
  private weak var protectedView: UIView?
  private weak var originalSuperlayer: CALayer?
  private weak var hostView: UIView?
  private var secureCanvasLayer: CALayer?
  private var originalLayerIndex: UInt32 = 0
  private var enabled = false

  init() {
    secureTextField.isSecureTextEntry = true
    secureTextField.text = " "
    secureTextField.textColor = .clear
    secureTextField.tintColor = .clear
    secureTextField.backgroundColor = .clear
    secureTextField.borderStyle = .none
    secureTextField.isUserInteractionEnabled = true
    secureTextField.isAccessibilityElement = false
    secureTextField.accessibilityElementsHidden = false
    secureTextField.clipsToBounds = true
    secureTextField.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    blackBackdropView.backgroundColor = .black
    blackBackdropView.isUserInteractionEnabled = false
    blackBackdropView.isAccessibilityElement = false
    blackBackdropView.accessibilityElementsHidden = true
    blackBackdropView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    secureTextField.onLayout = { [weak self] in
      self?.layoutProtectedLayer()
    }
  }

  @discardableResult
  func enable(in window: UIWindow) -> Bool {
    if enabled {
      layoutProtectedLayer()
      return true
    }

    guard let rootView = window.rootViewController?.view,
          let rootHostView = rootView.superview,
          let rootSuperlayer = rootView.layer.superlayer
    else {
      return false
    }

    window.layoutIfNeeded()
    rootHostView.layoutIfNeeded()
    rootView.layoutIfNeeded()

    let rootFrame = rootView.frame
    let layerIndex = rootSuperlayer.sublayers?
      .firstIndex(where: { $0 === rootView.layer }) ?? 0

    blackBackdropView.frame = rootFrame
    rootHostView.insertSubview(blackBackdropView, belowSubview: rootView)

    secureTextField.frame = rootFrame
    rootHostView.insertSubview(secureTextField, belowSubview: rootView)
    secureTextField.setNeedsLayout()
    secureTextField.layoutIfNeeded()

    guard let canvasView = secureCanvasView(in: secureTextField) else {
      secureTextField.removeFromSuperview()
      blackBackdropView.removeFromSuperview()
      return false
    }
    canvasView.isUserInteractionEnabled = true
    canvasView.accessibilityElementsHidden = false
    secureTextField.interactionView = rootView
    let canvasLayer = canvasView.layer

    protectedView = rootView
    hostView = rootHostView
    originalSuperlayer = rootSuperlayer
    originalLayerIndex = UInt32(layerIndex)
    secureCanvasLayer = canvasLayer

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    canvasLayer.addSublayer(rootView.layer)
    rootView.layer.frame = canvasLayer.bounds
    CATransaction.commit()

    enabled = true
    return true
  }

  private func secureCanvasView(in rootView: UIView) -> UIView? {
    let descendants = rootView.subviews.flatMap { subview -> [UIView] in
      [subview] + allDescendants(of: subview)
    }
    if let namedCanvas = descendants.first(where: { view in
      let className = NSStringFromClass(type(of: view))
      return className.contains("TextLayoutCanvasView")
        || className.contains("TextFieldCanvasView")
    }) {
      return namedCanvas
    }

    return descendants
      .filter { $0.bounds.width > 0 && $0.bounds.height > 0 }
      .max {
        ($0.bounds.width * $0.bounds.height)
          < ($1.bounds.width * $1.bounds.height)
      }
  }

  private func allDescendants(of view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + allDescendants(of: $0) }
  }

  func disable() {
    guard enabled else {
      secureTextField.removeFromSuperview()
      blackBackdropView.removeFromSuperview()
      return
    }

    let rootView = protectedView
    let rootLayer = rootView?.layer
    let rootHostView = hostView
    let rootSuperlayer = originalSuperlayer

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    rootLayer?.removeFromSuperlayer()

    if let rootLayer, let rootSuperlayer {
      let layerCount = rootSuperlayer.sublayers?.count ?? 0
      rootSuperlayer.insertSublayer(
        rootLayer,
        at: min(originalLayerIndex, UInt32(layerCount))
      )
      rootLayer.frame = rootHostView?.bounds ?? rootLayer.frame
    }
    secureTextField.removeFromSuperview()
    blackBackdropView.removeFromSuperview()
    CATransaction.commit()

    enabled = false
    secureTextField.interactionView = nil
    protectedView = nil
    hostView = nil
    originalSuperlayer = nil
    secureCanvasLayer = nil
    rootHostView?.setNeedsLayout()
    rootHostView?.layoutIfNeeded()
  }

  private func layoutProtectedLayer() {
    guard enabled,
          let rootView = protectedView,
          let rootHostView = hostView,
          let canvasLayer = secureCanvasLayer
    else {
      return
    }

    let frame = rootHostView.bounds
    blackBackdropView.frame = frame
    secureTextField.frame = frame

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    rootView.layer.frame = canvasLayer.bounds
    CATransaction.commit()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let screenSecurityChannelName = "customer_flutter/screen_security"
  private let biometricKeysChannelName = "customer_flutter/biometric_keys"
  private let biometricDeviceIdKey = "customer_flutter_biometric_device_id"
  private var screenSecurityChannel: FlutterMethodChannel?
  private var sensitiveRoute: String?
  private var privacyOverlay: UIView?
  private let secureCaptureProtector = IOSSecureCaptureProtector()
  private var screenshotOverlayDismissWorkItem: DispatchWorkItem?
  private var privacyOverlayTitle = "Screen capture is not allowed"
  private var privacyOverlayDescription = "Sensitive information is hidden. Please unlock again to continue."
  private var iosScreenshotPolicy = "lock_and_blank"
  private var iosScreenCaptureOverlayEnabled = true
  private var iosExitAppEnabled = true
  private var captureTerminationScheduled = false
  private let screenSecurityRouteKeys = [
    "route", "currentRoute", "current_route", "routeName", "route_name",
    "routePath", "route_path", "path", "currentPath", "current_path",
    "screen", "screenName", "screen_name", "url", "currentUrl",
    "current_url", "targetUrl", "target_url", "deepLink", "deep_link",
  ]
  private let screenSecurityEventKeys = [
    "event", "eventName", "event_name", "eventType", "event_type",
    "eventAction", "event_action", "nativeEvent", "native_event",
    "action",
  ]
  private let screenSecurityReasonKeys = [
    "reason", "reasonText", "reason_text", "reasonName", "reason_name",
    "cause", "message", "detail", "details",
  ]
  private let screenshotPolicyKeys = [
    "ios_screenshot_policy", "iosScreenshotPolicy", "screenshot_policy",
    "screenshotPolicy",
  ]
  private let screenCaptureOverlayKeys = [
    "ios_screen_capture_overlay", "iosScreenCaptureOverlay",
    "screen_capture_overlay", "screenCaptureOverlay",
  ]
  private let exitAppPolicyKeys = [
    "ios_exit_app", "iosExitApp", "exit_app", "exitApp",
  ]
  private let privacyOverlayTitleKeys = [
    "overlay_title", "overlayTitle", "privacy_overlay_title",
    "privacyOverlayTitle", "screen_capture_title", "screenCaptureTitle",
  ]
  private let privacyOverlayDescriptionKeys = [
    "overlay_description", "overlayDescription",
    "privacy_overlay_description", "privacyOverlayDescription",
    "screen_capture_description", "screenCaptureDescription",
  ]

  private var biometricKeyTag: String {
    let bundleId = Bundle.main.bundleIdentifier?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let namespace = (bundleId?.isEmpty == false) ? bundleId! : "customer_flutter"
    return "\(namespace).biometric.p256"
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureScreenSecurityChannel(engineBridge)
    configureBiometricKeysChannel(engineBridge)
    registerScreenCaptureObservers()
    registerAppPrivacyObservers()
  }

  private func configureScreenSecurityChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: screenSecurityChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    screenSecurityChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "enable":
        let args = call.arguments as? [String: Any]
        self.sensitiveRoute = self.stringArg(
          args,
          keys: self.screenSecurityRouteKeys,
          fallback: self.sensitiveRoute
        )
        self.updateScreenSecurityPolicy(args)
        self.updatePrivacyOverlayCopy(args)
        self.refreshSecureCaptureProtection()
        if UIScreen.main.isCaptured {
          if self.shouldShowPrivacyOverlay() {
            self.showPrivacyOverlay(reason: "screen_capture_active")
          } else {
            self.hidePrivacyOverlay()
          }
          if self.iosExitAppEnabled {
            self.requestSensitiveExit(
              reason: "screen_capture",
              nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
              isCaptured: UIScreen.main.isCaptured
            )
          } else {
            self.sendSecurityEvent(
              event: "screen_capture_active",
              reason: "screen_capture",
              nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
              isCaptured: UIScreen.main.isCaptured,
              source: "ios_enable_existing_capture"
            )
          }
        }
        result(nil)
      case "disable":
        self.sensitiveRoute = nil
        self.refreshSecureCaptureProtection()
        self.hidePrivacyOverlay()
        result(nil)
      case "reportSecurityEvent":
        let args = call.arguments as? [String: Any]
        let event = self.stringArg(
          args,
          keys: self.screenSecurityEventKeys,
          fallback: "screen_capture"
        ) ?? "screen_capture"
        let route = self.stringArg(
          args,
          keys: self.screenSecurityRouteKeys,
          fallback: self.sensitiveRoute ?? ""
        ) ?? ""
        let reason = self.stringArg(args, keys: self.screenSecurityReasonKeys)
        self.updateScreenSecurityPolicy(args)
        self.updatePrivacyOverlayCopy(args)
        self.sensitiveRoute = route.isEmpty ? self.sensitiveRoute : route
        self.refreshSecureCaptureProtection()
        if self.shouldShowPrivacyOverlay() {
          self.showPrivacyOverlay(reason: reason ?? event)
        }
        self.sendSecurityEvent(
          event: event,
          route: route,
          reason: reason,
          nativeEvent: event,
          source: "ios_report_security_event"
        )
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func updateScreenSecurityPolicy(_ args: [String: Any]?) {
    if let policy = stringArg(args, keys: screenshotPolicyKeys) {
      iosScreenshotPolicy = policy
    }

    if let overlay = boolArg(args, keys: screenCaptureOverlayKeys) {
      iosScreenCaptureOverlayEnabled = overlay
    }
    if let exitApp = boolArg(args, keys: exitAppPolicyKeys) {
      iosExitAppEnabled = exitApp
    }
  }

  private func updatePrivacyOverlayCopy(_ args: [String: Any]?) {
    if let title = stringArg(args, keys: privacyOverlayTitleKeys) {
      privacyOverlayTitle = title
    }
    if let description = stringArg(args, keys: privacyOverlayDescriptionKeys) {
      privacyOverlayDescription = description
    }
  }

  private func shouldShowPrivacyOverlay() -> Bool {
    return screenSecurityPolicyEnabled() && iosScreenCaptureOverlayEnabled
  }

  private func screenSecurityPolicyEnabled() -> Bool {
    let policy = iosScreenshotPolicy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if ["none", "off", "disabled"].contains(policy) {
      return false
    }
    return true
  }

  private func refreshSecureCaptureProtection(retryIfWindowUnavailable: Bool = true) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      guard self.sensitiveRoute != nil && self.screenSecurityPolicyEnabled() else {
        self.secureCaptureProtector.disable()
        return
      }

      guard let window = self.activeWindow(),
            self.secureCaptureProtector.enable(in: window)
      else {
        guard retryIfWindowUnavailable else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.refreshSecureCaptureProtection(retryIfWindowUnavailable: false)
        }
        return
      }
    }
  }

  private func boolArg(_ value: Any?) -> Bool? {
    if let bool = value as? Bool {
      return bool
    }
    if let number = value as? NSNumber {
      return number.boolValue
    }
    if let string = value as? String {
      switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "1", "true", "yes", "y", "on", "enable", "enabled",
           "active", "available", "allowed", "supported", "ready",
           "protect", "protected", "secure", "secured":
        return true
      case "0", "false", "no", "n", "off", "disable", "disabled",
           "inactive", "unavailable", "blocked", "hidden", "unsupported",
           "not_supported", "not_allowed", "unprotected":
        return false
      default:
        return nil
      }
    }
    return nil
  }

  private func boolArg(_ args: [String: Any]?, keys: [String]) -> Bool? {
    for key in keys {
      if let parsed = boolArg(args?[key]) {
        return parsed
      }
    }
    return nil
  }

  private func stringArg(
    _ args: [String: Any]?,
    keys: [String],
    fallback: String? = nil
  ) -> String? {
    for key in keys {
      if let value = args?[key],
         let normalized = normalizedStringArg(value) {
        return normalized
      }
    }
    return fallback
  }

  private func normalizedStringArg(_ value: Any?) -> String? {
    if let string = value as? String {
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    if let number = value as? NSNumber {
      return number.stringValue
    }
    if let nested = value as? [String: Any] {
      return stringArg(nested, keys: ["value", "code", "key", "path", "url", "href"])
    }
    return nil
  }

  private func registerScreenCaptureObservers() {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  private func registerAppPrivacyObservers() {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillHideSensitiveSnapshot),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidReturnFromSensitiveSnapshot),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func applicationWillHideSensitiveSnapshot() {
    guard sensitiveRoute != nil else { return }
    guard shouldShowPrivacyOverlay() else { return }
    showPrivacyOverlay(reason: "app_inactive")
  }

  @objc private func applicationDidReturnFromSensitiveSnapshot() {
    guard sensitiveRoute != nil else { return }
    refreshSecureCaptureProtection()
    if UIScreen.main.isCaptured {
      if shouldShowPrivacyOverlay() {
        showPrivacyOverlay(reason: "screen_capture_active")
      } else {
        hidePrivacyOverlay()
      }
      if iosExitAppEnabled {
        requestSensitiveExit(
          reason: "screen_capture",
          nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
          isCaptured: UIScreen.main.isCaptured
        )
      } else {
        sendSecurityEvent(
          event: "screen_capture_active",
          reason: "screen_capture",
          nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
          isCaptured: UIScreen.main.isCaptured,
          source: "ios_active_return_capture"
        )
      }
      return
    }

    hidePrivacyOverlay()
  }

  @objc private func userDidTakeScreenshot() {
    guard sensitiveRoute != nil else { return }
    if shouldShowPrivacyOverlay() {
      showPrivacyOverlay(reason: "screenshot")
    }
    if iosExitAppEnabled {
      requestSensitiveExit(
        reason: "screenshot",
        nativeEvent: UIApplication.userDidTakeScreenshotNotification.rawValue,
        isCaptured: UIScreen.main.isCaptured
      )
      return
    }
    sendSecurityEvent(
      event: "screenshot_detected",
      reason: "screenshot",
      nativeEvent: UIApplication.userDidTakeScreenshotNotification.rawValue,
      isCaptured: UIScreen.main.isCaptured,
      source: "ios_screenshot_notification"
    )
  }

  @objc private func screenCaptureStateChanged() {
    guard sensitiveRoute != nil else { return }

    if UIScreen.main.isCaptured {
      if shouldShowPrivacyOverlay() {
        showPrivacyOverlay(reason: "screen_capture")
      } else {
        hidePrivacyOverlay()
      }
      if iosExitAppEnabled {
        requestSensitiveExit(
          reason: "screen_capture",
          nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
          isCaptured: UIScreen.main.isCaptured
        )
        return
      }
      sendSecurityEvent(
        event: "screen_capture_active",
        reason: "screen_capture",
        nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
        isCaptured: UIScreen.main.isCaptured,
        source: "ios_capture_notification"
      )
    } else {
      hidePrivacyOverlay()
      sendSecurityEvent(
        event: "screen_capture_ended",
        reason: "screen_capture",
        nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
        isCaptured: UIScreen.main.isCaptured,
        source: "ios_capture_notification"
      )
    }
  }

  private func requestSensitiveExit(
    reason: String,
    nativeEvent: String? = nil,
    isCaptured: Bool? = nil
  ) {
    guard !captureTerminationScheduled else { return }
    captureTerminationScheduled = true
    showPrivacyOverlay(reason: "forced_exit")
    sendSecurityEvent(
      event: "screen_security_exit_requested",
      reason: reason,
      nativeEvent: nativeEvent,
      isCaptured: isCaptured,
      source: "ios_exit_app_policy"
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      exit(EXIT_SUCCESS)
    }
  }

  private func sendSecurityEvent(
    event: String,
    route: String? = nil,
    reason: String? = nil,
    nativeEvent: String? = nil,
    isCaptured: Bool? = nil,
    source: String? = nil
  ) {
    let resolvedRoute = route ?? sensitiveRoute ?? ""
    let payload: [String: Any?] = [
      "event": event,
      "eventName": nativeEvent ?? event,
      "nativeEvent": nativeEvent,
      "route": resolvedRoute,
      "currentRoute": resolvedRoute,
      "reason": reason,
      "reasonText": reason,
      "source": source ?? "ios_screen_security",
      "isCaptured": isCaptured,
      "screenCaptureActive": isCaptured,
    ]
    screenSecurityChannel?.invokeMethod("securityEvent", arguments: payload.compactMapValues { $0 })
  }

  private func showPrivacyOverlay(reason: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.activeWindow() else { return }

      self.screenshotOverlayDismissWorkItem?.cancel()
      self.screenshotOverlayDismissWorkItem = nil

      if let overlay = self.privacyOverlay {
        overlay.frame = window.bounds
        overlay.backgroundColor = .black
        if overlay.superview == nil {
          window.addSubview(overlay)
        }
        window.bringSubviewToFront(overlay)
        if reason == "screenshot" {
          self.scheduleScreenshotOverlayDismissal()
        }
        return
      }

      let overlay = UIView(frame: window.bounds)
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      overlay.backgroundColor = .black
      overlay.isAccessibilityElement = false
      overlay.accessibilityElementsHidden = true

      self.privacyOverlay = overlay
      window.addSubview(overlay)
      if reason == "screenshot" {
        self.scheduleScreenshotOverlayDismissal()
      }
    }
  }

  private func hidePrivacyOverlay() {
    DispatchQueue.main.async { [weak self] in
      self?.screenshotOverlayDismissWorkItem?.cancel()
      self?.screenshotOverlayDismissWorkItem = nil
      self?.privacyOverlay?.removeFromSuperview()
      self?.privacyOverlay = nil
    }
  }

  private func scheduleScreenshotOverlayDismissal() {
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.screenshotOverlayDismissWorkItem = nil
      guard !UIScreen.main.isCaptured else { return }
      guard UIApplication.shared.applicationState == .active else { return }
      self.privacyOverlay?.removeFromSuperview()
      self.privacyOverlay = nil
    }
    screenshotOverlayDismissWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
  }

  private func activeWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private func configureBiometricKeysChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: biometricKeysChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      do {
        switch call.method {
        case "existingDeviceId":
          result(self.existingBiometricDeviceId())
        case "deviceId":
          result(self.currentBiometricDeviceId())
        case "deleteKeyPair":
          try self.deleteBiometricKeyPair()
          result(true)
        case "createKeyPair":
          let publicKeyPem = try self.ensureBiometricKeyPair()
          let deviceId = self.currentBiometricDeviceId()
          result([
            "deviceId": deviceId,
            "credentialId": deviceId,
            "rawId": deviceId,
            "publicKeyPem": publicKeyPem,
            "publicKey": publicKeyPem,
            "algorithm": "ES256",
            "signingAlgorithm": "ES256",
            "keyAlgorithm": "ES256",
          ])
        case "signChallenge":
          let args = call.arguments as? [String: Any]
          let challenge = args?["challenge"] as? String ?? ""
          let localizedReason = self.stringArg(
            args,
            keys: ["localizedReason", "localized_reason", "authenticationReason", "authentication_reason"],
            fallback: "Confirm your identity to continue"
          ) ?? "Confirm your identity to continue"
          guard !challenge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result(FlutterError(
              code: "invalid_challenge",
              message: "Challenge is required.",
              details: nil
            ))
            return
          }
          do {
            result(try self.signBiometricChallengePayload(
              challenge,
              localizedReason: localizedReason
            ))
          } catch {
            if self.shouldInvalidateBiometricKey(error) {
              try? self.deleteBiometricKeyPair()
              result(FlutterError(
                code: "biometric_key_invalidated",
                message: "Biometric enrollment changed. Register this device again.",
                details: nil
              ))
              return
            }
            if self.isBiometricCancellation(error) {
              result(FlutterError(
                code: "biometric_cancelled",
                message: "Biometric authentication was cancelled.",
                details: nil
              ))
              return
            }
            throw error
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(
          code: "biometric_key_error",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private func currentBiometricDeviceId() -> String {
    if let existing = existingBiometricDeviceId(), !existing.isEmpty {
      return existing
    }

    let created = "ios-\(UUID().uuidString)"
    UserDefaults.standard.set(created, forKey: biometricDeviceIdKey)
    return created
  }

  private func existingBiometricDeviceId() -> String? {
    guard let stored = UserDefaults.standard.string(forKey: biometricDeviceIdKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !stored.isEmpty
    else {
      return nil
    }

    let lookup = lookupBiometricPrivateKey()
    if lookup.key != nil {
      return stored
    }

    // Keychain can be temporarily unavailable while iOS is still activating
    // the protected app. Only clear the credential after a definitive
    // not-found response; signing will validate every other state.
    if lookup.status == errSecItemNotFound {
      UserDefaults.standard.removeObject(forKey: biometricDeviceIdKey)
      return nil
    }

    return stored
  }

  private func deleteBiometricKeyPair() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: Data(biometricKeyTag.utf8),
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw BiometricKeyError.keyDeletionFailed
    }
    UserDefaults.standard.removeObject(forKey: biometricDeviceIdKey)
  }

  private func ensureBiometricKeyPair() throws -> String {
    if let existing = findBiometricPrivateKey(),
       let publicKey = SecKeyCopyPublicKey(existing) {
      return try publicKeyPem(publicKey)
    }

    let tagData = Data(biometricKeyTag.utf8)
    var error: Unmanaged<CFError>?
    let access = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage, .biometryCurrentSet],
      &error
    )

    if let error {
      throw error.takeRetainedValue() as Error
    }

    var attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tagData,
        kSecAttrAccessControl as String: access as Any,
      ],
    ]

    #if !targetEnvironment(simulator)
    attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
    #endif

    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      if let error {
        throw error.takeRetainedValue() as Error
      }
      throw BiometricKeyError.keyCreationFailed
    }

    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw BiometricKeyError.publicKeyUnavailable
    }

    return try publicKeyPem(publicKey)
  }

  private func signBiometricChallenge(
    _ challenge: String,
    localizedReason: String
  ) throws -> String {
    let context = LAContext()
    context.localizedReason = localizedReason
    context.localizedFallbackTitle = ""

    let privateKey = try authenticatedBiometricPrivateKey(context)

    guard SecKeyIsAlgorithmSupported(
      privateKey,
      .sign,
      .ecdsaSignatureMessageX962SHA256
    ) else {
      throw BiometricKeyError.unsupportedAlgorithm
    }

    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      privateKey,
      .ecdsaSignatureMessageX962SHA256,
      Data(challenge.utf8) as CFData,
      &error
    ) else {
      if let error {
        throw error.takeRetainedValue() as Error
      }
      throw BiometricKeyError.signatureFailed
    }

    return (signature as Data).base64EncodedString()
  }

  private func signBiometricChallengePayload(
    _ challenge: String,
    localizedReason: String
  ) throws -> [String: Any] {
    let signature = try signBiometricChallenge(
      challenge,
      localizedReason: localizedReason
    )
    let deviceId = existingBiometricDeviceId() ?? ""
    var payload: [String: Any] = [
      "signature": signature,
      "signatureBase64": signature,
      "signatureDer": signature,
      "signedPayload": challenge,
      "algorithm": "ES256",
      "signingAlgorithm": "ES256",
      "keyAlgorithm": "ES256",
    ]
    if !deviceId.isEmpty {
      payload["deviceId"] = deviceId
      payload["credentialId"] = deviceId
      payload["rawId"] = deviceId
    }
    return payload
  }

  private func findBiometricPrivateKey(authenticationContext: LAContext? = nil) -> SecKey? {
    return lookupBiometricPrivateKey(authenticationContext: authenticationContext).key
  }

  private func lookupBiometricPrivateKey(
    authenticationContext: LAContext? = nil
  ) -> (key: SecKey?, status: OSStatus) {
    var query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: Data(biometricKeyTag.utf8),
      kSecReturnRef as String: true,
    ]
    if let authenticationContext {
      query[kSecUseAuthenticationContext as String] = authenticationContext
    }
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess else {
      return (nil, status)
    }

    return ((item as! SecKey), status)
  }

  private func authenticatedBiometricPrivateKey(_ context: LAContext) throws -> SecKey {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: Data(biometricKeyTag.utf8),
      kSecReturnRef as String: true,
      kSecUseAuthenticationContext as String: context,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(status, nil) ?? "Biometric key is unavailable."]
      )
    }
    guard let item else {
      throw BiometricKeyError.privateKeyUnavailable
    }
    return (item as! SecKey)
  }

  private func shouldInvalidateBiometricKey(_ error: Error) -> Bool {
    return errorChain(error).contains { nativeError in
      nativeError.domain == NSOSStatusErrorDomain &&
        nativeError.code == Int(errSecItemNotFound)
    }
  }

  private func isBiometricCancellation(_ error: Error) -> Bool {
    return errorChain(error).contains { nativeError in
      if nativeError.domain == NSOSStatusErrorDomain {
        return nativeError.code == Int(errSecUserCanceled)
      }
      guard nativeError.domain == LAError.errorDomain else { return false }
      return [
        LAError.Code.userCancel.rawValue,
        LAError.Code.appCancel.rawValue,
        LAError.Code.systemCancel.rawValue,
        LAError.Code.userFallback.rawValue,
      ].contains(nativeError.code)
    }
  }

  private func errorChain(_ error: Error) -> [NSError] {
    var chain: [NSError] = []
    var current: NSError? = error as NSError
    var seen = Set<ObjectIdentifier>()
    while let nativeError = current {
      let identifier = ObjectIdentifier(nativeError)
      guard seen.insert(identifier).inserted else { break }
      chain.append(nativeError)
      current = nativeError.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return chain
  }

  private func publicKeyPem(_ publicKey: SecKey) throws -> String {
    var error: Unmanaged<CFError>?
    guard let external = SecKeyCopyExternalRepresentation(publicKey, &error) else {
      if let error {
        throw error.takeRetainedValue() as Error
      }
      throw BiometricKeyError.publicKeyUnavailable
    }

    let x963 = external as Data
    let spkiHeader = Data([
      0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86,
      0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A,
      0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
      0x42, 0x00,
    ])
    let der = spkiHeader + x963
    let body = der.base64EncodedString()
      .split(every: 64)
      .joined(separator: "\n")

    return "-----BEGIN PUBLIC KEY-----\n\(body)\n-----END PUBLIC KEY-----"
  }
}

private enum BiometricKeyError: LocalizedError {
  case keyCreationFailed
  case publicKeyUnavailable
  case privateKeyUnavailable
  case keyDeletionFailed
  case signatureFailed
  case unsupportedAlgorithm

  var errorDescription: String? {
    switch self {
    case .keyCreationFailed:
      return "Unable to create a biometric key."
    case .publicKeyUnavailable:
      return "Unable to read the biometric public key."
    case .privateKeyUnavailable:
      return "Biometric device key is not registered."
    case .keyDeletionFailed:
      return "Unable to delete the biometric key."
    case .signatureFailed:
      return "Unable to sign biometric challenge."
    case .unsupportedAlgorithm:
      return "Biometric key algorithm is not supported."
    }
  }
}

private extension String {
  func split(every length: Int) -> [String] {
    guard length > 0 else { return [self] }
    var result: [String] = []
    var start = startIndex

    while start < endIndex {
      let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
      result.append(String(self[start..<end]))
      start = end
    }

    return result
  }
}

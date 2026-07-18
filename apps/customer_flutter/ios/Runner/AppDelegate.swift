import Flutter
import LocalAuthentication
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let screenSecurityChannelName = "customer_flutter/screen_security"
  private let biometricKeysChannelName = "customer_flutter/biometric_keys"
  private let biometricDeviceIdKey = "customer_flutter_biometric_device_id"
  private var screenSecurityChannel: FlutterMethodChannel?
  private var sensitiveRoute: String?
  private var privacyOverlay: UIView?
  private var screenshotOverlayDismissWorkItem: DispatchWorkItem?
  private var privacyOverlayTitle = "Screen capture is not allowed"
  private var privacyOverlayDescription = "Sensitive information is hidden. Please unlock again to continue."
  private var iosScreenshotPolicy = "lock_and_blank"
  private var iosScreenCaptureOverlayEnabled = true
  private var iosExitAppEnabled = false
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
        if UIScreen.main.isCaptured {
          if self.shouldShowPrivacyOverlay() {
            self.showPrivacyOverlay(reason: "screen_capture_active")
          } else {
            self.hidePrivacyOverlay()
          }
          self.sendSecurityEvent(
            event: "screen_capture_active",
            reason: "screen_capture",
            nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
            isCaptured: UIScreen.main.isCaptured,
            source: "ios_enable_existing_capture"
          )
        }
        result(nil)
      case "disable":
        self.sensitiveRoute = nil
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
    let policy = iosScreenshotPolicy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if ["none", "off", "disabled"].contains(policy) {
      return false
    }
    return iosScreenCaptureOverlayEnabled
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
    if UIScreen.main.isCaptured {
      if shouldShowPrivacyOverlay() {
        showPrivacyOverlay(reason: "screen_capture_active")
      } else {
        hidePrivacyOverlay()
      }
      sendSecurityEvent(
        event: "screen_capture_active",
        reason: "screen_capture",
        nativeEvent: UIScreen.capturedDidChangeNotification.rawValue,
        isCaptured: UIScreen.main.isCaptured,
        source: "ios_active_return_capture"
      )
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
    sendSecurityEvent(
      event: "screen_security_exit_requested",
      reason: reason,
      nativeEvent: nativeEvent,
      isCaptured: isCaptured,
      source: "ios_exit_app_policy"
    )
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
        if overlay.superview == nil {
          window.addSubview(overlay)
        }
        if reason == "screenshot" {
          self.scheduleScreenshotOverlayDismissal()
        }
        return
      }

      let overlay = UIView(frame: window.bounds)
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      overlay.backgroundColor = UIColor.systemBackground

      let stack = UIStackView()
      stack.axis = .vertical
      stack.alignment = .center
      stack.spacing = 12
      stack.translatesAutoresizingMaskIntoConstraints = false

      let icon = UIImageView(image: UIImage(systemName: "eye.slash.fill"))
      icon.tintColor = UIColor.systemBlue
      icon.contentMode = .scaleAspectFit

      let title = UILabel()
      title.text = self.privacyOverlayTitle
      title.font = UIFont.preferredFont(forTextStyle: .title2)
      title.textColor = UIColor.label
      title.textAlignment = .center

      let subtitle = UILabel()
      subtitle.text = self.privacyOverlayDescription
      subtitle.font = UIFont.preferredFont(forTextStyle: .body)
      subtitle.textColor = UIColor.secondaryLabel
      subtitle.textAlignment = .center
      subtitle.numberOfLines = 0

      stack.addArrangedSubview(icon)
      stack.addArrangedSubview(title)
      stack.addArrangedSubview(subtitle)
      overlay.addSubview(stack)

      NSLayoutConstraint.activate([
        icon.widthAnchor.constraint(equalToConstant: 56),
        icon.heightAnchor.constraint(equalToConstant: 56),
        stack.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 28),
        stack.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -28),
        stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      ])

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

    guard hasExistingBiometricKeyPair() else {
      try? deleteBiometricKeyPair()
      return nil
    }

    return stored
  }

  private func hasExistingBiometricKeyPair() -> Bool {
    findBiometricPrivateKey() != nil
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
      return nil
    }

    return (item as! SecKey)
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
    let nativeError = error as NSError
    guard nativeError.domain == NSOSStatusErrorDomain else { return false }
    return nativeError.code == Int(errSecItemNotFound)
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

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let screenSecurityChannelName = "customer_flutter/screen_security"
  private let biometricKeysChannelName = "customer_flutter/biometric_keys"
  private let biometricDeviceIdKey = "customer_flutter_biometric_device_id"
  private var screenSecurityChannel: FlutterMethodChannel?
  private var sensitiveRoute: String?
  private var privacyOverlay: UIView?

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
        self.sensitiveRoute = args?["route"] as? String
        if UIScreen.main.isCaptured {
          self.showPrivacyOverlay(reason: "screen_capture_active")
          self.sendSecurityEvent(event: "screen_capture_active", reason: "screen_capture")
        }
        result(nil)
      case "disable":
        self.sensitiveRoute = nil
        self.hidePrivacyOverlay()
        result(nil)
      case "reportSecurityEvent":
        let args = call.arguments as? [String: Any]
        let event = args?["event"] as? String ?? "screen_capture"
        let route = args?["route"] as? String ?? self.sensitiveRoute ?? ""
        let reason = args?["reason"] as? String
        self.sensitiveRoute = route.isEmpty ? self.sensitiveRoute : route
        self.showPrivacyOverlay(reason: reason ?? event)
        self.sendSecurityEvent(event: event, route: route, reason: reason)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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

  @objc private func userDidTakeScreenshot() {
    guard sensitiveRoute != nil else { return }
    showPrivacyOverlay(reason: "screenshot")
    sendSecurityEvent(event: "screenshot_detected", reason: "screenshot")
  }

  @objc private func screenCaptureStateChanged() {
    guard sensitiveRoute != nil else { return }

    if UIScreen.main.isCaptured {
      showPrivacyOverlay(reason: "screen_capture")
      sendSecurityEvent(event: "screen_capture_active", reason: "screen_capture")
    } else {
      hidePrivacyOverlay()
      sendSecurityEvent(event: "screen_capture_ended", reason: "screen_capture")
    }
  }

  private func sendSecurityEvent(
    event: String,
    route: String? = nil,
    reason: String? = nil
  ) {
    let payload: [String: Any?] = [
      "event": event,
      "route": route ?? sensitiveRoute ?? "",
      "reason": reason,
    ]
    screenSecurityChannel?.invokeMethod("securityEvent", arguments: payload.compactMapValues { $0 })
  }

  private func showPrivacyOverlay(reason: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.activeWindow() else { return }

      if let overlay = self.privacyOverlay {
        overlay.frame = window.bounds
        if overlay.superview == nil {
          window.addSubview(overlay)
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
      title.text = "ห้ามบันทึกภาพหน้าจอ"
      title.font = UIFont.preferredFont(forTextStyle: .title2)
      title.textColor = UIColor.label
      title.textAlignment = .center

      let subtitle = UILabel()
      subtitle.text = "ระบบซ่อนข้อมูลสำคัญและจะให้ยืนยันตัวตนใหม่"
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
    }
  }

  private func hidePrivacyOverlay() {
    DispatchQueue.main.async { [weak self] in
      self?.privacyOverlay?.removeFromSuperview()
      self?.privacyOverlay = nil
    }
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
        case "deviceId":
          result(self.currentBiometricDeviceId())
        case "createKeyPair":
          let publicKeyPem = try self.ensureBiometricKeyPair()
          result([
            "deviceId": self.currentBiometricDeviceId(),
            "publicKeyPem": publicKeyPem,
            "algorithm": "ES256",
          ])
        case "signChallenge":
          let args = call.arguments as? [String: Any]
          let challenge = args?["challenge"] as? String ?? ""
          guard !challenge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result(FlutterError(
              code: "invalid_challenge",
              message: "Challenge is required.",
              details: nil
            ))
            return
          }
          result(try self.signBiometricChallenge(challenge))
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
    if let existing = UserDefaults.standard.string(forKey: biometricDeviceIdKey), !existing.isEmpty {
      return existing
    }

    let created = "ios-\(UUID().uuidString)"
    UserDefaults.standard.set(created, forKey: biometricDeviceIdKey)
    return created
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

  private func signBiometricChallenge(_ challenge: String) throws -> String {
    guard let privateKey = findBiometricPrivateKey() else {
      throw BiometricKeyError.privateKeyUnavailable
    }

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

  private func findBiometricPrivateKey() -> SecKey? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: Data(biometricKeyTag.utf8),
      kSecReturnRef as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess else {
      return nil
    }

    return (item as! SecKey)
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

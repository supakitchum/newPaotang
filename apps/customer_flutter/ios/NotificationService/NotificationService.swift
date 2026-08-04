import UniformTypeIdentifiers
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private let maximumImageBytes = 8 * 1024 * 1024
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var downloadTask: URLSessionDataTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    bestAttemptContent = content

    guard let imageURL = imageURL(from: request.content.userInfo) else {
      finish(with: content)
      return
    }

    var urlRequest = URLRequest(url: imageURL)
    urlRequest.timeoutInterval = 8
    downloadTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, _ in
      guard let self else { return }
      guard
        let data,
        !data.isEmpty,
        data.count <= self.maximumImageBytes,
        let httpResponse = response as? HTTPURLResponse,
        (200..<300).contains(httpResponse.statusCode),
        let attachment = self.attachment(data: data, response: httpResponse)
      else {
        self.finish(with: content)
        return
      }

      content.attachments = [attachment]
      self.finish(with: content)
    }
    downloadTask?.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    downloadTask?.cancel()
    finish(with: bestAttemptContent)
  }

  private func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
    let candidates: [Any?] = [
      userInfo["image_url"],
      userInfo["imageUrl"],
      userInfo["gcm.n.image"],
      (userInfo["fcm_options"] as? [String: Any])?["image"],
    ]

    for candidate in candidates {
      guard
        let value = candidate as? String,
        let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
      else { continue }
      return url
    }
    return nil
  }

  private func attachment(data: Data, response: HTTPURLResponse) -> UNNotificationAttachment? {
    let extensionName = fileExtension(for: response)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let fileURL = directory.appendingPathComponent("notification.\(extensionName)")
      try data.write(to: fileURL, options: .atomic)
      return try UNNotificationAttachment(identifier: "campaign-image", url: fileURL)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      return nil
    }
  }

  private func fileExtension(for response: HTTPURLResponse) -> String {
    if
      let mimeType = response.mimeType,
      let type = UTType(mimeType: mimeType),
      let preferredExtension = type.preferredFilenameExtension
    {
      return preferredExtension
    }

    let sourceExtension = response.url?.pathExtension.lowercased() ?? ""
    return ["jpg", "jpeg", "png", "webp"].contains(sourceExtension)
      ? sourceExtension
      : "jpg"
  }

  private func finish(with content: UNNotificationContent?) {
    guard let contentHandler else { return }
    self.contentHandler = nil
    contentHandler(content ?? bestAttemptContent ?? UNNotificationContent())
  }
}

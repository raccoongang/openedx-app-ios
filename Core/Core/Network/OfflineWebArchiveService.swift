//
//  OfflineWebArchiveService.swift
//  Core
//
//  Created by Codex on 16.03.2025.
//

import Foundation
import WebKit
import OEXFoundation

public struct OfflineWebArchiveResult: Sendable {
    public let fileURL: URL
    public let originalURL: URL
    public let size: Int
}

public protocol OfflineWebArchiveServiceProtocol: Sendable {
    func archivePage(
        sourceURLString: String,
        fileName: String,
        destinationDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> OfflineWebArchiveResult
}

@MainActor
public final class OfflineWebArchiveService: OfflineWebArchiveServiceProtocol {

    private let authInteractor: AuthInteractorProtocol
    private let config: ConfigProtocol

    public init(
        authInteractor: AuthInteractorProtocol,
        config: ConfigProtocol
    ) {
        self.authInteractor = authInteractor
        self.config = config
    }

    public func archivePage(
        sourceURLString: String,
        fileName: String,
        destinationDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> OfflineWebArchiveResult {

        progress(0.0)
        let targetURL = try makeAbsoluteURL(from: sourceURLString)
        debugLog(">>>WEB Preparing snapshot", targetURL.absoluteString)

        // Refresh cookies to increase the chance that the session is valid.
        do {
            try await authInteractor.getCookies(force: false)
        } catch {
            debugLog(">>>WEB Cookie refresh failed", error.localizedDescription)
        }

        let webView = WKWebView(frame: .zero)
        let delegate = ArchiveNavigationDelegate(onProgress: progress)
        webView.navigationDelegate = delegate

        let request = URLRequest(url: targetURL)
        try await delegate.load(request: request, in: webView)
        debugLog(">>>WEB Page loaded", targetURL.absoluteString)

        let archiveData = try await withCheckedThrowingContinuation { continuation in
            webView.createWebArchiveData { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    debugLog(">>>WEB Archive capture error", targetURL.absoluteString, error.localizedDescription)
                    continuation.resume(throwing: error)
                }
            }
        }

        let destinationURL = destinationDirectory.appendingPathComponent(fileName)
        do {
            try archiveData.write(to: destinationURL, options: Data.WritingOptions.atomic)
        } catch {
            throw OfflineWebArchiveError.writeFailed(error)
        }

        progress(1.0)
        debugLog(">>>WEB Archive data size", archiveData.count)

        return OfflineWebArchiveResult(
            fileURL: destinationURL,
            originalURL: targetURL,
            size: archiveData.count
        )
    }

    private func makeAbsoluteURL(from string: String) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        if trimmed.hasPrefix("//"), let schemeURL = URL(string: "https:\(trimmed)") {
            return schemeURL
        }

        if let relativeURL = URL(string: trimmed, relativeTo: config.baseURL)?.absoluteURL {
            return relativeURL
        }

        throw OfflineWebArchiveError.invalidURL(trimmed)
    }
}

private enum OfflineWebArchiveError: LocalizedError {
    case invalidURL(String)
    case emptyArchive
    case navigationFailed(Error)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Unable to build URL from: \(value)"
        case .emptyArchive:
            return "Web archive creation returned empty data."
        case .navigationFailed(let error):
            return "Failed to load page before archiving: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Failed to persist web archive: \(error.localizedDescription)"
        }
    }
}

@MainActor
private final class ArchiveNavigationDelegate: NSObject, WKNavigationDelegate {

    private var continuation: CheckedContinuation<Void, Error>?
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func load(request: URLRequest, in webView: WKWebView) async throws {
        onProgress(0.1)
        debugLog(">>>WEB Loading", request.url?.absoluteString ?? "")
        webView.load(request)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onProgress(0.9)
        debugLog(">>>WEB Navigation finished", webView.url?.absoluteString ?? "")
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(with: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        fail(with: error)
    }

    private func fail(with error: Error) {
        debugLog(">>>WEB Navigation failed", error.localizedDescription)
        continuation?.resume(throwing: OfflineWebArchiveError.navigationFailed(error))
        continuation = nil
    }
}

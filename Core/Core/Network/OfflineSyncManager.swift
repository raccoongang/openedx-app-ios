//
//  OfflineSyncManager.swift
//  Core
//
//  Created by  Stepanok Ivan on 20.06.2024.
//

import Foundation
@preconcurrency import WebKit
@preconcurrency import Combine
import Swinject
import OEXFoundation

public protocol OfflineSyncManagerProtocol: Sendable {
    func handleMessage(message: WKScriptMessage, blockID: String) async
    func syncOfflineProgress() async
}

@MainActor
public class OfflineSyncManager: OfflineSyncManagerProtocol {
    
    let persistence: CorePersistenceProtocol
    let interactor: OfflineSyncInteractorProtocol
    let connectivity: ConnectivityProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        persistence: CorePersistenceProtocol,
        interactor: OfflineSyncInteractorProtocol,
        connectivity: ConnectivityProtocol
    ) {
        self.persistence = persistence
        self.interactor = interactor
        self.connectivity = connectivity
        
        self.connectivity.internetReachableSubject.sink(receiveValue: { state in
            switch state {
            case .reachable:
                Task(priority: .low) {
                    await self.syncOfflineProgress()
                }
            case .notReachable, nil:
                 break
            }
        }).store(in: &cancellables)
    }
    
    public func handleMessage(message: WKScriptMessage, blockID: String) async {
        if message.name == "IOSBridge",
           let progressJson = message.body as? String {
            await persistence.saveOfflineProgress(
                progress: OfflineProgress(
                    progressJson: progressJson
                )
            )
            let correctedProgressJson = (progressJson.removingPercentEncoding ?? progressJson)
            await dispatchMarkProblemCompleted(
                on: message.webView,
                blockID: blockID,
                payload: correctedProgressJson
            )
        } else if let offlineProgress = await persistence.loadProgress(for: blockID) {
            let correctedProgressJson = (offlineProgress.progressJson.removingPercentEncoding ?? offlineProgress.progressJson)
            await dispatchMarkProblemCompleted(
                on: message.webView,
                blockID: blockID,
                payload: correctedProgressJson
            )
        }
    }
    
    public func syncOfflineProgress() async {
        let offlineProgress = await persistence.loadAllOfflineProgress()
        let cookies = HTTPCookieStorage.shared.cookies
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        for progress in offlineProgress {
            do {
                if try await interactor.submitOfflineProgress(
                    courseID: progress.courseID,
                    blockID: progress.blockID,
                    data: progress.data
                ) {
                   await persistence.deleteProgress(for: progress.blockID)
                }
                if let config = Container.shared.resolve(ConfigProtocol.self), let cookies {
                    HTTPCookieStorage.shared.setCookies(cookies, for: config.baseURL, mainDocumentURL: nil)
                }
            } catch {
                debugLog("Error submitting offline progress: \(error.localizedDescription)")
            }
        }
    }

    private func dispatchMarkProblemCompleted(
        on webView: WKWebView?,
        blockID: String,
        payload: String
    ) async {
        guard let webView else { return }
        let payloadLiteral = payload.jsEscapedForTemplateLiteral()
        let blockLiteral = blockID.jsEscapedForJavaScriptLiteral()
        let script = """
        (function() {
            const payload = `\(payloadLiteral)`;
            const blockId = \(blockLiteral);

            function invoke(target) {
                if (!target) { return false; }
                try {
                    if (typeof target.markProblemCompleted === 'function') {
                        target.markProblemCompleted(payload);
                        return true;
                    }
                } catch (error) {}
                return false;
            }

            if (invoke(window)) { return; }

            const frame = document.querySelector('iframe[data-block-id=\"' + blockId + '\"]');
            if (!frame) { return; }

            if (invoke(frame.contentWindow)) { return; }

            try {
                if (frame.contentWindow) {
                    frame.contentWindow.postMessage({ type: 'parent:markProblemCompleted', payload: payload }, '*');
                }
            } catch (error) {}
        })();
        """
        await MainActor.run {
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

private extension String {
    func jsEscapedForJavaScriptLiteral() -> String {
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    func jsEscapedForTemplateLiteral() -> String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }
}

//
//  GroupedWebView.swift
//  Course
//
//  Created by OpenAI Codex on 2024.
//

import SwiftUI
import Swinject
import Core
import Theme
import WebKit
import OEXFoundation

struct GroupedWebView: View {
    let items: [CourseUnitDisplayItem.WebContentItem]
    let offlineURLs: [String: URL]
    let connectivity: ConnectivityProtocol
    let roundedBackgroundEnabled: Bool

    @State private var htmlFileURL: URL?
    @State private var configurationSignature: String = ""

    private var combinedInjections: [WebviewInjection] {
        var seen = Set<String>()
        var result: [WebviewInjection] = []
        for item in items {
            for var injection in item.injections {
                guard seen.insert(injection.id).inserted else { continue }
                injection.forMainFrameOnly = false
                result.append(injection)
            }
        }
        var resizeInjection = WebviewInjection.groupedContentResize
        if seen.insert(resizeInjection.id).inserted {
            result.append(resizeInjection)
        }
        return result
    }

    private var sourceMap: [String: String] {
        items.reduce(into: [String: String]()) { result, item in
            let source = offlineURLs[item.blockId]?.absoluteString ?? item.url
            result[item.blockId] = source
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let htmlFileURL {
                WebUnitView(
                    url: htmlFileURL.absoluteString,
                    dataUrl: htmlFileURL.absoluteString,
                    viewModel: Container.shared.resolve(WebUnitViewModel.self)!,
                    connectivity: connectivity,
                    injections: combinedInjections,
                    blockID: items.first?.blockId ?? "",
                    blockIDResolver: { message in
                        resolveBlockID(from: message)
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            if roundedBackgroundEnabled {
                Spacer(minLength: 5)
            }
        }
        .if(roundedBackgroundEnabled) { view in
            view.roundedBackgroundWeb(
                strokeColor: Theme.Colors.textInputUnfocusedStroke,
                maxIpadWidth: .infinity
            )
        }
        .onAppear {
            updateHTMLIfNeeded()
        }
        .onChange(of: sourceSignature()) { _ in
            updateHTMLIfNeeded()
        }
    }

    private func sourceSignature() -> String {
        items
            .map { item in
                let source = sourceMap[item.blockId] ?? item.url
                return "\(item.blockId)::\(source)"
            }
            .joined(separator: "|")
    }

    private func updateHTMLIfNeeded() {
        let signature = sourceSignature()
        guard signature != configurationSignature || htmlFileURL == nil else { return }
        do {
            let html = buildHTML()
            if let existing = htmlFileURL {
                try? FileManager.default.removeItem(at: existing)
            }
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("grouped-\(UUID().uuidString).html")
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            htmlFileURL = fileURL
            configurationSignature = signature
        } catch {
            htmlFileURL = nil
            debugLog("Failed to create grouped web html: \(error.localizedDescription)")
        }
    }

    private func buildHTML() -> String {
        let iframeHTML = items.map { item -> String in
            let source = sourceMap[item.blockId] ?? item.url
            let src = source.htmlEscaped()
            let blockId = item.blockId.htmlEscaped()
            return """
            <iframe
                class="unit-frame"
                src="\(src)"
                name="\(blockId)"
                data-block-id="\(blockId)"
                scrolling="no"
                allowfullscreen
                loading="lazy"
                allow="autoplay; fullscreen; encrypted-media"
            ></iframe>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                }
                body {
                    display: flex;
                    flex-direction: column;
                    gap: 0;
                }
                iframe {
                    width: 100%;
                    border: 0;
                    background-color: transparent;
                    display: block;
                }
                .unit-frame {
                    min-height: 120px;
                    overflow: hidden;
                    background-color: transparent;
                }
            </style>
        </head>
        <body>
            \(iframeHTML)
            <script>
                (function () {
                    const MIN_HEIGHT = 80;
                    const MAX_HEIGHT = 1000000;
                    const frames = Array.from(document.querySelectorAll('iframe.unit-frame'));
                    const heights = new Map();

                    function clampHeight(value) {
                        return Math.max(MIN_HEIGHT, Math.min(MAX_HEIGHT, Math.round(value || 0)));
                    }

                    function applyHeight(frame, value) {
                        const next = clampHeight(value);
                        const prev = heights.get(frame);
                        if (prev !== next) {
                            frame.style.height = next + 'px';
                            heights.set(frame, next);
                        }
                    }

                    function requestHeight(frame) {
                        try {
                            const message = { type: 'parent:getHeight', id: frame.dataset.blockId };
                            if (frame.contentWindow && frame.contentWindow !== window) {
                                frame.contentWindow.postMessage(message, '*');
                            }
                        } catch (error) {
                            // ignored
                        }
                    }

                    function handleMessage(event) {
                        const data = event.data;
                        if (!data || typeof data !== 'object') { return; }
                        if (data.type === 'child:height' && typeof data.height === 'number') {
                            const target = frames.find(frame => frame.dataset.blockId === data.id);
                            if (target) {
                                applyHeight(target, data.height);
                            }
                            return;
                        }
                        if (data.type === 'child:ready' && typeof data.id === 'string') {
                            const target = frames.find(frame => frame.dataset.blockId === data.id);
                            if (target) {
                                requestHeight(target);
                            }
                        }
                    }

                    for (const frame of frames) {
                        applyHeight(frame, 120);
                        frame.addEventListener('load', () => requestHeight(frame));
                    }

                    window.addEventListener('message', handleMessage, false);
                    let resizeTimer = null;
                    window.addEventListener('resize', () => {
                        if (resizeTimer) { clearTimeout(resizeTimer); }
                        resizeTimer = setTimeout(() => {
                            resizeTimer = null;
                            frames.forEach(frame => requestHeight(frame));
                        }, 150);
                    });
                    document.addEventListener('visibilitychange', () => {
                        if (!document.hidden) {
                            frames.forEach(frame => requestHeight(frame));
                        }
                    });

                    setTimeout(() => {
                        frames.forEach(frame => requestHeight(frame));
                    }, 50);
                })();
            </script>
        </body>
        </html>
        """
    }

    private func resolveBlockID(from message: WKScriptMessage) -> String? {
        if let url = message.frameInfo.request.url?.absoluteString,
           let blockID = extractBlockID(from: url) {
            return blockID
        }

        if let bodyString = message.body as? String,
           let blockID = extractBlockIDFromProgressJson(bodyString) {
            return blockID
        }

        return nil
    }

    private func extractBlockID(from url: String) -> String? {
        guard let start = url.range(of: "xblock/")?.upperBound else { return nil }
        if let handlerEnd = url.range(of: "/handler", range: start..<url.endIndex)?.lowerBound {
            return String(url[start..<handlerEnd])
        }
        if let queryEnd = url[start...].firstIndex(of: "?") {
            return String(url[start..<queryEnd])
        }
        if let slashEnd = url[start...].firstIndex(of: "/") {
            return String(url[start..<slashEnd])
        }
        return String(url[start...])
    }

    private func extractBlockIDFromProgressJson(_ string: String) -> String? {
        let normalized = string.removingPercentEncoding ?? string
        guard let data = normalized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = json["url"] as? String else {
            return nil
        }
        return extractBlockID(from: url)
    }
}

private extension String {
    func htmlEscaped() -> String {
        var escaped = self
        let replacements: [String: String] = [
            "&": "&amp;",
            "\"": "&quot;",
            "'": "&#39;",
            "<": "&lt;",
            ">": "&gt;"
        ]
        for (key, value) in replacements {
            escaped = escaped.replacingOccurrences(of: key, with: value)
        }
        return escaped
    }
}

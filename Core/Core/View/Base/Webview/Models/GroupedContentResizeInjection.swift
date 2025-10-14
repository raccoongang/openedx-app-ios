//
//  GroupedContentResizeInjection.swift
//  Core
//
//  Created by OpenAI Codex on 2024.
//

import WebKit

public struct GroupedContentResizeInjection: WebViewScriptInjectionProtocol {
    public init() {}

    public var id: String = "GroupedContentResizeInjection"

    public var script: String {
        """
        (function () {
            try {
                if (window.top === window) { return; }
                if (window.__groupedContentResizeInstalled) { return; }
                window.__groupedContentResizeInstalled = true;

                var childId = '';
                if (typeof window.name === 'string' && window.name.length > 0) {
                    childId = window.name;
                } else {
                    var meta = document.querySelector('meta[name="grouped-block-id"]');
                    if (meta && typeof meta.content === 'string') {
                        childId = meta.content;
                    }
                }

                var MIN_HEIGHT = 80;
                var MAX_HEIGHT = 1000000;
                var pending = false;
                var lastHeight = 0;
                var lastViewportHeight = 0;
                var lastOverflow = 0;

                function clampHeight(value) {
                    return Math.max(MIN_HEIGHT, Math.min(MAX_HEIGHT, Math.round(value || 0)));
                }

                function postMessage(type, payload) {
                    if (!window.parent || window.parent === window) { return; }
                    var data = Object.assign({ type: type, id: childId }, payload || {});
                    window.parent.postMessage(data, '*');
                }

                function measure() {
                    pending = false;
                    var doc = document.documentElement;
                    var body = document.body || doc;
                    if (!doc) { return; }
                    var viewport = Math.max(window.innerHeight || 0, doc.clientHeight || 0);
                    var height = Math.max(
                        doc.scrollHeight || 0,
                        doc.offsetHeight || 0,
                        doc.clientHeight || 0,
                        body ? body.scrollHeight || 0 : 0,
                        body ? body.offsetHeight || 0 : 0,
                        body ? body.clientHeight || 0 : 0
                    );
                    height = clampHeight(height);
                    var overflow = Math.max(0, height - viewport);

                    if (lastHeight > 0 && viewport > lastViewportHeight && Math.abs(overflow - lastOverflow) <= 1) {
                        height = lastHeight;
                        overflow = lastOverflow;
                    }

                    if (lastHeight > 0 && height > lastHeight) {
                        var viewportDiff = viewport - lastViewportHeight;
                        var heightDiff = height - lastHeight;
                        if (viewportDiff > 0 && Math.abs(heightDiff - viewportDiff) <= 2) {
                            height = lastHeight;
                        }
                    }

                    if (Math.abs(height - lastHeight) <= 1) {
                        lastViewportHeight = viewport;
                        lastOverflow = overflow;
                        return;
                    }

                    lastHeight = height;
                    lastViewportHeight = viewport;
                    lastOverflow = overflow;
                    postMessage('child:height', { height: height });
                }

                function scheduleMeasure() {
                    if (pending) { return; }
                    pending = true;
                    var raf = window.requestAnimationFrame || function (cb) { return setTimeout(cb, 16); };
                    raf(function () { measure(); });
                }

                var observer = new MutationObserver(scheduleMeasure);
                observer.observe(document.documentElement, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    characterData: true
                });

                if (window.ResizeObserver) {
                    var resizeObserver = new ResizeObserver(scheduleMeasure);
                    resizeObserver.observe(document.documentElement);
                    if (document.body) { resizeObserver.observe(document.body); }
                }

                window.addEventListener('load', scheduleMeasure);
                document.addEventListener('DOMContentLoaded', scheduleMeasure);

                window.addEventListener('message', function (event) {
                    var data = event.data;
                    if (!data || typeof data !== 'object') { return; }
                    if (data.type === 'parent:getHeight' || data.type === 'parent:ping') {
                        scheduleMeasure();
                    }
                });

                postMessage('child:ready', {});
                scheduleMeasure();
            } catch (error) {
                // ignore
            }
        })();
        """
    }

    public var messages: [WebviewMessage]? = nil
    public var injectionTime: WKUserScriptInjectionTime = .atDocumentEnd
    public var forMainFrameOnly: Bool = false
}

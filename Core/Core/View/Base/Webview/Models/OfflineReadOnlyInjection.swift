//
//  OfflineReadOnlyInjection.swift
//  Core
//
//  Created by Codex on 16.03.2025.
//

import WebKit

public struct OfflineReadOnlyInjection: WebViewScriptInjectionProtocol {
    public let id: String = "OfflineReadOnlyInjection"

    public var script: String {
        """
        (function() {
            if (window.__offlineReadOnlyApplied) { return; }
            window.__offlineReadOnlyApplied = true;

            const addBanner = () => {
                const existing = document.getElementById('offline-readonly-banner');
                if (existing) { return; }
                const banner = document.createElement('div');
                banner.id = 'offline-readonly-banner';
                banner.innerText = 'Offline preview: submissions are disabled.';
                banner.style.position = 'fixed';
                banner.style.top = '0';
                banner.style.left = '0';
                banner.style.right = '0';
                banner.style.zIndex = '2147483647';
                banner.style.padding = '12px';
                banner.style.fontSize = '14px';
                banner.style.fontWeight = '600';
                banner.style.textAlign = 'center';
                banner.style.color = '#0B0B0B';
                banner.style.background = 'rgba(255, 199, 0, 0.95)';
                document.body.appendChild(banner);
                document.body.style.marginTop = (parseInt(getComputedStyle(document.body).marginTop || '0', 10) + banner.offsetHeight) + 'px';
            };

            const disableInteractiveElements = () => {
                const selectors = [
                    'form',
                    'button',
                    'input[type="submit"]',
                    'input[type="button"]',
                    'a.problem-action-button',
                    '.problem-action-button'
                ];
                selectors.forEach(selector => {
                    document.querySelectorAll(selector).forEach(element => {
                        element.classList.add('offline-readonly-disabled');
                        if ('disabled' in element) {
                            element.setAttribute('disabled', 'true');
                        }
                        element.setAttribute('aria-disabled', 'true');
                        element.style.pointerEvents = 'none';
                        element.style.opacity = '0.6';
                        element.style.cursor = 'not-allowed';
                    });
                });
            };

            const preventInteraction = (event) => {
                if (!event) { return; }
                const target = event.target || {};
                if (target.closest && target.closest('.offline-readonly-disabled')) {
                    event.stopImmediatePropagation();
                    event.preventDefault();
                    return false;
                }
                return true;
            };

            const interceptNetwork = () => {
                if (window.fetch && !window.__offlineFetchPatched) {
                    window.fetch = function() {
                        console.warn('Offline preview: blocked fetch request.', arguments[0]);
                        return Promise.reject(new Error('offline_preview_blocked'));
                    };
                    window.__offlineFetchPatched = true;
                }

                if (window.XMLHttpRequest && !window.__offlineXHRPatched) {
                    XMLHttpRequest.prototype.send = function() {
                        console.warn('Offline preview: blocked XMLHttpRequest.', this.responseURL);
                        this.abort();
                    };
                    window.__offlineXHRPatched = true;
                }
            };

            document.addEventListener('submit', preventInteraction, true);
            document.addEventListener('click', preventInteraction, true);

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                    addBanner();
                    disableInteractiveElements();
                });
            } else {
                addBanner();
                disableInteractiveElements();
            }

            interceptNetwork();
        })();
        """
    }

    public var messages: [WebviewMessage]? {
        nil
    }

    public var injectionTime: WKUserScriptInjectionTime {
        .atDocumentEnd
    }

    public var forMainFrameOnly: Bool {
        true
    }
}

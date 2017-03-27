//
//  WKWebView+ScriptHandler.swift
//  HoogleIt
//
//  Created by guoc on 26/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation
import WebKit

private class ScrollToFragmentScriptMessageHandler: NSObject, WKScriptMessageHandler {
    
    private let script: WKUserScript
    
    fileprivate init(script: WKUserScript) {
        self.script = script
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        userContentController.removeUserScript(script)
    }
}

extension WKWebView {
    
    private struct ScriptMessageHandlerNames {
        private init() {}
        static let scrollToFragmentFinished = "fragmentScrollFinished"
    }
    
    func setupScrollToFragmentScript(with urlFragment: String) {
        
        configuration.userContentController.removeScriptMessageHandler(forName: ScriptMessageHandlerNames.scrollToFragmentFinished)
        
        // This script is for scrolling view to the URL fragment, and will be removed once it is called.
        let source = "window.onload = function () {" +
                     "  (document.getElementById('\(urlFragment)') || document.querySelector(\"a[name='\(urlFragment)']\")).scrollIntoView();" +
                     "  window.webkit.messageHandlers.\(ScriptMessageHandlerNames.scrollToFragmentFinished).postMessage();" +
                     "};"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        
        configuration.userContentController.add(ScrollToFragmentScriptMessageHandler(script: script), name: ScriptMessageHandlerNames.scrollToFragmentFinished)
        
        configuration.userContentController.addUserScript(script)
    }
}

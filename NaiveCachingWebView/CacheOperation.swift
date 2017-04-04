//
//  CacheOperation.swift
//  NaiveCachingWebView
//
//  Created by guoc on 4/4/17.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation
import WebKit

class CacheOperation: Operation {

    private var _executing = false
    private var _finished = false

    private let webView: WKWebView
    private let request: URLRequest
    private let htmlProcessors: HTMLProcessorsProtocol?
    private let cachingCompletionHandler: (() -> Void)?

    init(_ webView: WKWebView, request: URLRequest, with htmlProcessors: HTMLProcessorsProtocol? = nil, cachingCompletionHandler: (() -> Void)? = nil) {
        self.webView = webView
        self.request = request
        self.htmlProcessors = htmlProcessors
        self.cachingCompletionHandler = cachingCompletionHandler
        super.init()
    }

    override internal(set) var isExecuting: Bool {
        get {
            return _executing
        }
        set {
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    override internal(set) var isFinished: Bool {
        get {
            return _finished
        }
        set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }

    override var isAsynchronous: Bool {
        return true
    }

    override func start() {
        if isCancelled {
            isFinished = true
            return
        }

        isExecuting = true

        DispatchQueue.global(qos: .utility).async {

            self.webView.cacheInlinedWebPage(for: self.request, with: self.htmlProcessors)
            self.cachingCompletionHandler?()
        }
    }
}

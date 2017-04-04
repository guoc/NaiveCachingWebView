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

    private let request: URLRequest
    private let htmlProcessors: HTMLProcessorsProtocol?
    private let cachingCompletionHandler: (() -> Void)?

    init(_ request: URLRequest, with htmlProcessors: HTMLProcessorsProtocol? = nil, cachingCompletionHandler: (() -> Void)? = nil) {
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
            testingPrint(after: "starting start function")
            isFinished = true
            isExecuting = false
            return
        }

        isExecuting = true

        DispatchQueue.global(qos: .utility).async {

            let requestWithUserAgentSet: URLRequest = {
                var request = self.request
                request.setValue(WKWebView.userAgent, forHTTPHeaderField: "User-Agent")
                return request
            }()

            if self.isCancelled {
                testingPrint(after: "setting user agent")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            guard let plainHTMLString = WKWebView.plainHTML(for: requestWithUserAgentSet) else {
                assertionFailure("Failed to fetch the plain HTML for \(String(describing: self.request.url))")
                return
            }

            if self.isCancelled {
                testingPrint(after: "fetching plain HTML")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            let preprocessedHTMLString = self.htmlProcessors?.preprocessor?(plainHTMLString) ?? plainHTMLString

            if self.isCancelled {
                testingPrint(after: "HTML preprocessing")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            guard let url = self.request.url else {
                assertionFailure("Expected non-nil URL in request \(self.request).")
                return
            }
            let baseURL = url.deletingLastPathComponent()

            let inlinedHTMLString = WKWebView.inlineResources(for: preprocessedHTMLString, with: baseURL)

            if self.isCancelled {
                testingPrint(after: "inlining resource files")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            let postprocessedHTMLString = self.htmlProcessors?.postprocessor?(inlinedHTMLString) ?? inlinedHTMLString

            if self.isCancelled {
                testingPrint(after: "HTML postprocessing")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            #if SAVE_INLINED_PAGE_FOR_TESTING
                let targetPath = FileManager.default.temporaryDirectory
                    .appendingPathComponent("NaiveCachingWebView", isDirectory: true)
                    .appendingPathComponent("InlinedPages", isDirectory: true)
                    .appendingPathComponent(url.absoluteString.replacingOccurrences(of: "^https?:\\/\\/", with: "", options: .regularExpression) + ".html")
                do {
                    try FileManager.default.createDirectory(at: targetPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                    print("Try to save inlined page file to \(targetPath)")
                    try postprocessedHTMLString.write(to: targetPath, atomically: true, encoding: .utf8)
                } catch {
                    assertionFailure("Failed to save inlined page file.")
                }
                if self.isCancelled {
                    testingPrint(after: "saving inlined page for testing")
                    self.isFinished = true
                    self.isExecuting = false
                    return
                }
            #endif

            let newCachedResponse: CachedURLResponse = {
                let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: postprocessedHTMLString.characters.count, textEncodingName: "UTF-8")
                guard let data = postprocessedHTMLString.data(using: .utf8) else {
                    preconditionFailure("Failed to convert HTML string to data.")
                }
                return CachedURLResponse(response: response, data: data)
            }()

            if self.isCancelled {
                testingPrint(after: "preparing response to cache")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            URLCache.shared.storeCachedResponse(newCachedResponse, for: self.request.requestByRemovingURLFragment)
            
            print("Cache stored for \(self.request.requestByRemovingURLFragment.url?.absoluteString ?? "nil url").")

            if self.isCancelled {
                testingPrint(after: "storing cache")
                self.isFinished = true
                self.isExecuting = false
                return
            }

            self.cachingCompletionHandler?()

            self.isExecuting = false
            self.isFinished = true
        }
    }

}

fileprivate func testingPrint(after whatJustHapped: String) {
    #if LOG_FOR_TESTING
        print("Operation cancelled after \(whatJustHapped).")
    #endif
}

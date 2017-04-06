//
//  NaiveCachingWebViewTests.swift
//  NaiveCachingWebViewTests
//
//  Created by guoc on 27/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import XCTest
import FBSnapshotTestCase
import WebKit
@testable import NaiveCachingWebView

class NaiveCachingWebViewTests: FBSnapshotTestCase {
    
    static private let testLinks: [String] = {
        
        let filePath = Bundle(for: NaiveCachingWebViewTests.self).path(forResource: "test-links", ofType: "txt")!
        let fileContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        let links = fileContent.components(separatedBy: "\n")
        return links
    }()
        
    let window = UIWindow(frame: UIScreen.main.bounds)
    
    override func setUp() {
        super.setUp()
        
        URLCache.shared.removeAllCachedResponses()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
// MARK: - Test cachingLoad
    
    func testFirstTimeLoading() {
        
        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        
        let nativeLoadingResult = syncLoad(request: request)

        let cachingLoadingResult = syncCachingLoad(request: request)

        FBSnapshotCompareReferenceImage(nativeLoadingResult, to: cachingLoadingResult, tolerance: 0)
    }

// MARK: - Test user agent

    func testUserAgent() {

        let userAgent = WKWebView.userAgent
        print(userAgent)
        XCTAssert(!userAgent.isEmpty)
    }

// MARK: - Test hasCached

    func testHasCached() {

        let request = URLRequest(url: URL(string: "https://www.google.com")!)
        syncCache(request: request)
        XCTAssert(WKWebView.hasCached(for: request))
    }

// MARK: - Test cache

    func testCache() {

        let request = URLRequest(url: URL(string: "https://www.google.com")!)
        syncCache(request: request)
        syncCachingLoad(request: request)
    }

// MARK: - Test cache operations

    func testCacheOperations() {

        let urlStrings = [
            "http://hackage.haskell.org/package/Agda-2.3.0/docs/src/Agda-TypeChecking-Monad-Env.html"
          , "http://hackage.haskell.org/package/Agda-2.3.0/docs/Agda-TypeChecking-Forcing.html"
          , "http://hackage.haskell.org/package/Agda-2.2.10/docs/Agda-TypeChecking-Errors.html"
          , "http://hackage.haskell.org/package/Agda-2.2.8/docs/Agda-TypeChecking-Rules-Decl.html"
          , "http://hackage.haskell.org/package/Agda-2.2.6/docs/src/Agda-Syntax-Parser-Layout.html"
          , "http://hackage.haskell.org/package/Agda-2.2.6/docs/Agda-TypeChecking-Monad-Closure.html"
          , "http://hackage.haskell.org/package/AERN-RnToRm-0.3.0.1/docs/Data-Number-ER-RnToRm-Approx.html"
          , "http://hackage.haskell.org/package/AERN-Real-0.9.3/docs/Data-Number-ER-Real-Base.html"
          , "http://hackage.haskell.org/package/ADPfusion-0.4.1.1/docs/ADP-Fusion-SynVar-Array-Type.html"
          , "http://hackage.haskell.org/package/ADPfusion-0.4.0.1/docs/src/ADP-Fusion-TH-Common.html"
        ]

        let urls = urlStrings.map { URL(string: $0)! }
        let requests = urls.map { URLRequest(url: $0) }
        let cacheOperations = requests.map { WKWebView.cache($0, startAutomatically: false) }

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .utility
        operationQueue.addOperations(cacheOperations, waitUntilFinished: false)

        while operationQueue.operationCount != 0 {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: .distantFuture)
        }

        let r = WKWebView.hasCached(for: requests[4])
        print(r)

        syncCachingLoad(request: requests[4])
    }

// MARK: - Test cancel cache operation

    func testCancelCacheOperation() {

        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        let cacheOperation = WKWebView.cache(request, with: nil) { (_, _) in
            print("Cache finished")
        }
        RunLoop.current.run(until: Date() + TimeInterval(arc4random_uniform(10)))
        cacheOperation.cancel()
        while true {
            RunLoop.current.run(until: Date() + 0.25)
            if cacheOperation.isFinished && !cacheOperation.isExecuting {
                return
            }
        }
    }

// MARK: - Test load after cache

    func testLoadAfterCache() {

        let currentRunLoop = CFRunLoopGetCurrent()
        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        WKWebView.cache(request, with: nil) { (_, _) in
            print("Cache finished")
            CFRunLoopStop(currentRunLoop)
        }
        CFRunLoopRun()
        syncLoad(request: request)
    }

// MARK: - Test caching correction

    func testCachingCorrection() {
        
//        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        
        for (index, link) in NaiveCachingWebViewTests.testLinks.enumerated() {

            autoreleasepool {
                
                print("Testing \(index) ...")
                
                let request = URLRequest(url: URL(string: link)!)
                
                let nativeLoadingResult = syncLoad(request: request)
                
                _ = syncCachingLoad(request: request)
                
                let cachingLoadingResult = syncCachingLoad(request: request)
                
                let identifier = link
                    .replacingOccurrences(of: "https?:\\/\\/", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "/", with: "-")
                
                FBSnapshotCompareReferenceImage(nativeLoadingResult, to: cachingLoadingResult, tolerance: 0.01, identifier: identifier)
            }
        }
    }

// MARK: - Helpers
    
    private class NavigationDelegate: NSObject, WKNavigationDelegate {

        let currentRunLoop: CFRunLoop

        init(currentRunLoop: CFRunLoop) {
            self.currentRunLoop = currentRunLoop
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { 
                CFRunLoopStop(self.currentRunLoop)
            }
        }
    }

    @discardableResult func syncLoad(request: URLRequest) -> UIImage {

        let webView = WKWebView(frame: window.bounds)
        let delegate = NavigationDelegate(currentRunLoop: CFRunLoopGetCurrent())
        webView.navigationDelegate = delegate
        window.addSubview(webView)

        _ = webView.load(request)

        CFRunLoopRun()
        
        guard let snapshot = image(forViewOrLayer: webView) else {
            preconditionFailure("Failed to get the web view's snapshot.")
        }
        
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        
        return snapshot
    }
    
    @discardableResult private func syncCachingLoad(request: URLRequest) -> UIImage {
        
        let webView = WKWebView(frame: window.bounds)
        let currentRunLoop = CFRunLoopGetCurrent()!
        let delegate = NavigationDelegate(currentRunLoop: currentRunLoop)
        webView.navigationDelegate = delegate
        window.addSubview(webView)

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        _ = webView.cachingLoad(request, with: nil) { (_, _) in
            // This completionHandler may be called non-escaping, which means it may be called before executing next statement.
            // TODO: Fix it with Swift another escaping related issue in WKWebView+NaiveCachingWebView.swift
            dispatchGroup.leave()
        }
        CFRunLoopRun() // wait navigation finished
        // wait caching finished
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.current.run(until: Date() + 0.25)
        }

        guard let snapshot = image(forViewOrLayer: webView) else {
            preconditionFailure("Failed to get the web view's snapshot.")
        }
        
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        
        return snapshot

    }

    private func syncCache(request: URLRequest) {

        let currentRunLoop = CFRunLoopGetCurrent()

        WKWebView.cache(request) { (_, _) in
            CFRunLoopStop(currentRunLoop)
        }

        CFRunLoopRun()
    }
}

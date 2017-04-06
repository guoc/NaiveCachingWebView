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

// MARK: - Test cancel cache operation

    func testCancelCacheOperation() {

        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        let cacheOperation = WKWebView.cache(request, with: nil) {
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
        WKWebView.cache(request, with: nil) {
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
    
    private func syncCachingLoad(request: URLRequest) -> UIImage {
        
        let webView = WKWebView(frame: window.bounds)
        let currentRunLoop = CFRunLoopGetCurrent()!
        let delegate = NavigationDelegate(currentRunLoop: currentRunLoop)
        webView.navigationDelegate = delegate
        window.addSubview(webView)

        _ = webView.cachingLoad(request, with: nil) {
            CFRunLoopStop(currentRunLoop)
        }
        CFRunLoopRun() // wait navigation finished
        CFRunLoopRun() // wait caching finished

        guard let snapshot = image(forViewOrLayer: webView) else {
            preconditionFailure("Failed to get the web view's snapshot.")
        }
        
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        
        return snapshot

    }

    private func syncCache(request: URLRequest) {

        let currentRunLoop = CFRunLoopGetCurrent()

        WKWebView.cache(request) {
            CFRunLoopStop(currentRunLoop)
        }

        CFRunLoopRun()
    }
}

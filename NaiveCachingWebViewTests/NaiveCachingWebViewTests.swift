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
        
// MARK: - Test cachingLoad
    
    func testFirstTimeLoading() {
        
        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        
        let nativeLoadingResult = syncLoad(request: request)

        let cachingLoadingResult = syncCachingLoad(request: request)

        FBSnapshotCompareReferenceImage(nativeLoadingResult, to: cachingLoadingResult, tolerance: 0)
    }

    func testCachingOptions() {

        let request = URLRequest(url: URL(string: "https://hackage.haskell.org/packages/archive/base/latest/doc/html/Prelude.html#v:map")!)

        let nativeLoadingResult = syncLoad(request: request)

        syncCachingLoad(request: request)
        
        let cachingLoadingResult = syncCachingLoad(request: request, options: [.ignoreExistingCache, .rebuildCache])

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
        
        var randomIndices: Set<Int> = []
        let linksCount = NaiveCachingWebViewTests.testLinks.count
        while randomIndices.count < 10 {
            randomIndices.insert(Int(arc4random_uniform(UInt32(linksCount))))
        }

        let testLinks = randomIndices.map { NaiveCachingWebViewTests.testLinks[$0] }

        for (index, link) in testLinks.enumerated() {

            autoreleasepool {
                
                print("Testing \(index) ...")
                
                let request = URLRequest(url: URL(string: link)!)
                
                let nativeLoadingResult = syncLoad(request: request)
                
                syncCachingLoad(request: request)
                
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
    
    @discardableResult private func syncCachingLoad(request: URLRequest, options: CachingOptions = []) -> UIImage {
        
        let webView = WKWebView(frame: window.bounds)
        let currentRunLoop = CFRunLoopGetCurrent()!
        let delegate = NavigationDelegate(currentRunLoop: currentRunLoop)
        webView.navigationDelegate = delegate
        window.addSubview(webView)

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        webView.cachingLoad(request, options: options, with: nil) { (_, _) in
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

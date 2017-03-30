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
    
    private static let userAgent: String = {
        
        var userAgent: String!
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        webView.evaluateJavaScript("navigator.userAgent") { (result: Any?, error: Error?) in
            guard error == nil else {
                preconditionFailure(error!.localizedDescription)
            }
            guard let result = result as? String else {
                preconditionFailure("Failed to get user agent.")
            }
            userAgent = result
            dispatchGroup.leave()
        }
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date() + 0.25)
        }
        
        return userAgent
    }()
    
    let dispatchGroup = DispatchGroup()
    
    let window = UIWindow(frame: UIScreen.main.bounds)
    var webView: WKWebView!
    
    override func setUp() {
        super.setUp()
        
        URLCache.shared.removeAllCachedResponses()
        
        webView = WKWebView(frame: window.bounds)
        webView.navigationDelegate = self
        window.addSubview(webView)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
// MARK: - Test cachingLoad
    
    func testFirstTimeLoading() {
        
        var request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        request.setValue(NaiveCachingWebViewTests.userAgent, forHTTPHeaderField: "User-Agent")
        
        _ = webView.load(request)
        waitWebViewLoadingFinished()
        let nativeLoadingResult = image(forViewOrLayer: webView)

        _ = webView.cachingLoad(request)
        waitWebViewLoadingFinished()
        let cachingLoadingResult = image(forViewOrLayer: webView)

        FBSnapshotCompareReferenceImage(nativeLoadingResult, to: cachingLoadingResult, tolerance: 0)
    }
    
    func testCachingCorrection() {
        
        var request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        request.setValue(NaiveCachingWebViewTests.userAgent, forHTTPHeaderField: "User-Agent")
        
        _ = webView.load(request)
        waitWebViewLoadingFinished()
        let nativeLoadingResult = image(forViewOrLayer: webView)
        
        let expectation = self.expectation(description: "Snapshots comparison finished")
        _ = webView.cachingLoad(request, with: nil, cachingCompletionHanlder: {
            _ = self.webView.cachingLoad(request) // cachingLoad again to load caches.
            self.waitWebViewLoadingFinished()
            let cachingLoadingResult = self.image(forViewOrLayer: self.webView)
            self.FBSnapshotCompareReferenceImage(nativeLoadingResult, to: cachingLoadingResult, tolerance: 0)
            expectation.fulfill()
        })
        waitWebViewLoadingFinished()
        
        wait(for: [expectation], timeout: 10)
    }
    
}

extension NaiveCachingWebViewTests {
    
    func waitWebViewLoadingFinished() {
        
        dispatchGroup.enter()
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date() + 0.25)
        }
    }
}

extension NaiveCachingWebViewTests: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dispatchGroup.leave()
        }
    }
}

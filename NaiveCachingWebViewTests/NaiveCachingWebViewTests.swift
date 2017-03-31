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
    
    
    private class NavigationDelegate: NSObject, WKNavigationDelegate {
        
        let dispatchGroup: DispatchGroup
        
        init(dispatchGroup: DispatchGroup) {
            self.dispatchGroup = dispatchGroup
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.dispatchGroup.leave()
            }
        }
    }

    private func syncLoad(request: URLRequest) -> UIImage {
        
        let webView = WKWebView(frame: window.bounds)
        let dispatchGroup = DispatchGroup()
        let delegate = NavigationDelegate(dispatchGroup: dispatchGroup)
        webView.navigationDelegate = delegate
        window.addSubview(webView)

        dispatchGroup.enter()

        _ = webView.load(request)
        
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date() + 0.25)
        }
        
        guard let snapshot = image(forViewOrLayer: webView) else {
            preconditionFailure("Failed to get the web view's snapshot.")
        }
        
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        
        return snapshot
    }
    
    private func syncCachingLoad(request: URLRequest) -> UIImage {
        
        let webView = WKWebView(frame: window.bounds)
        let dispatchGroup = DispatchGroup()
        let delegate = NavigationDelegate(dispatchGroup: dispatchGroup)
        webView.navigationDelegate = delegate
        window.addSubview(webView)
        
        dispatchGroup.enter() // wait navigation finished
        dispatchGroup.enter() // wait caching finished
        
        _ = webView.cachingLoad(request, with: nil) {
            dispatchGroup.leave()
        }
        
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date() + 0.25)
        }
        
        guard let snapshot = image(forViewOrLayer: webView) else {
            preconditionFailure("Failed to get the web view's snapshot.")
        }
        
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        
        return snapshot

    }
}

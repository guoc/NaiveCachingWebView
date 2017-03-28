//
//  NaiveCachingWebViewTests.swift
//  NaiveCachingWebViewTests
//
//  Created by guoc on 27/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import XCTest
import WebKit
@testable import NaiveCachingWebView

class NaiveCachingWebViewTests: XCTestCase {
    
    let dispatchGroup = DispatchGroup()
    
    let window = UIWindow(frame: UIScreen.main.bounds)
    var webView: WKWebView!
    
    override func setUp() {
        super.setUp()
        
        webView = WKWebView(frame: window.bounds)
        webView.navigationDelegate = self
        window.addSubview(webView)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {

        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/base-4.9.1.0/docs/Prelude.html#v:map")!)
        dispatchGroup.enter()
        _ = webView.cachingLoad(request)
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date() + 0.25)
        }

    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

extension NaiveCachingWebViewTests: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Finished!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let webView = webView
            self.dispatchGroup.leave()
        }
    }
}

//
//  CacheInfoTests.swift
//  NaiveCachingWebView
//
//  Created by guoc on 7/4/17.
//  Copyright © 2017 guoc. All rights reserved.
//

import XCTest
import WebKit

class CacheInfoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()

        URLCache.shared.removeAllCachedResponses()
    }
        
    func testCacheInfo() {

        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)

        let currentRunLoop = CFRunLoopGetCurrent()

        WKWebView.cache(request) { (_, _) in
            CFRunLoopStop(currentRunLoop)
        }

        CFRunLoopRun()

        let cacheInfo = WKWebView.cacheInfo(for: request)
        XCTAssertNotNil(cacheInfo)

        let cacheDate = cacheInfo!.cacheDate
        print("Cached at \(cacheDate.description(with: Locale.current)), \(Date().timeIntervalSince(cacheDate)) elapsed.")
        XCTAssert(cacheDate < Date())

    }
    
}

//
//  CacheOperationTests.swift
//  NaiveCachingWebView
//
//  Created by guoc on 7/4/17.
//  Copyright © 2017 guoc. All rights reserved.
//

import XCTest
import WebKit

class CacheOperationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()

        URLCache.shared.removeAllCachedResponses()
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
    }

    // MARK: - Test cancel cache operation

    func testCancelCacheOperation() {

        let request = URLRequest(url: URL(string: "http://hackage.haskell.org/package/bytedump")!)
        let cacheOperation = WKWebView.cache(request, with: nil) { (_, _) in
            print("Cache finished")
        }
        RunLoop.current.run(until: Date() + TimeInterval(arc4random_uniform(10)))
        cacheOperation.cancel()
        while !cacheOperation.isFinished || cacheOperation.isExecuting {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: .distantFuture)
        }
    }

    
}

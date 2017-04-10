//
//  HTMLProcessors.swift
//  NaiveCachingWebView
//
//  Created by guoc on 10/4/17.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

public protocol HTMLProcessorsProtocol {

    var preprocessor: ((String) -> String)? { get }
    var postprocessor: ((String) -> String)? { get }
}

public struct HTMLProcessors: HTMLProcessorsProtocol {

    public let preprocessor: ((String) -> String)?
    public let postprocessor: ((String) -> String)?

    public init(preprocessor: ((String) -> String)?, postprocessor: ((String) -> String)?) {
        self.preprocessor = preprocessor
        self.postprocessor = postprocessor
    }
}

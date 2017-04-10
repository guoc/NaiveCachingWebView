//
//  CachingOptions.swift
//  NaiveCachingWebView
//
//  Created by guoc on 10/4/17.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

public struct CachingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let ignoreExistingCache = CachingOptions(rawValue: 1 << 1)
    public static let rebuildCache = CachingOptions(rawValue: 1 << 2)
}

//
//  CacheInfo.swift
//  NaiveCachingWebView
//
//  Created by guoc on 7/4/17.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

public struct CacheInfo {

    private struct UserInfoKeys {
        private init() {}

        static let cacheData = "cacheDate"
        static let naiveCachingWebViewCached = "naiveCachingWebViewCached"
    }

    public let cacheDate: Date
    public let naiveCachingWebViewCached: Bool

    internal init() {
        cacheDate = Date()
        naiveCachingWebViewCached = true
    }

    internal init?(from userInfo: [AnyHashable : Any]?) {
        guard let cacheDate = userInfo?[UserInfoKeys.cacheData] as? Date
            , let naiveCachingWebViewCached = userInfo?[UserInfoKeys.naiveCachingWebViewCached] as? Bool else
        {
            return nil
        }
        self.cacheDate = cacheDate
        self.naiveCachingWebViewCached = naiveCachingWebViewCached
    }

    internal func toUserInfo() -> [AnyHashable : Any] {
        return [UserInfoKeys.cacheData: cacheDate, UserInfoKeys.naiveCachingWebViewCached: naiveCachingWebViewCached]
    }
}

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
    }

    public let cacheDate: Date

    internal init() {
        cacheDate = Date()
    }

    internal init?(from userInfo: [AnyHashable : Any]?) {
        guard let cacheDate = userInfo?[UserInfoKeys.cacheData] as? Date else {
            return nil
        }
        self.cacheDate = cacheDate
    }

    internal func toUserInfo() -> [AnyHashable : Any] {
        return [UserInfoKeys.cacheData: cacheDate]
    }
}

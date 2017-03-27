//
//  URL+Extension.swift
//  HoogleIt
//
//  Created by guoc on 25/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

extension URL {
    
    var longestBaseURL: URL {
        guard let match = absoluteString.range(of: "^https?:\\/\\/(\\S+\\/)*", options: .regularExpression) else {
            preconditionFailure("Unexpected URL: \(self)")
        }
        return URL(string: absoluteString.substring(with: match))!
    }
    
    var urlByRemovingFragment: URL {
        guard let fragment = fragment else {
            return self
        }
        return URL(string: absoluteString.replacingOccurrences(of: "#\(fragment)", with: "")) ?? self
    }
}

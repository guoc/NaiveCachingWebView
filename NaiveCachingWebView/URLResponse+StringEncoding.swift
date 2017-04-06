//
//  URLResponse+StringEncoding.swift
//  HoogleIt
//
//  Created by guoc on 25/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

extension URLResponse {
    
    var stringEncoding: String.Encoding? {
        if let textEncodingName = textEncodingName {
            let rawValue = UInt(CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString))
            switch rawValue {
            case 0x8000100:
                return .utf8
            default:
                return String.Encoding(rawValue: rawValue)
            }
        } else {
            return nil
        }
    }
}

extension CachedURLResponse {
    
    var stringEncoding: String.Encoding? {
        return response.stringEncoding
    }
}

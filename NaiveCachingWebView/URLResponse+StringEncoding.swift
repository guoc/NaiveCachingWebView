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
            return String.Encoding(rawValue: UInt(CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)))
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

//
//  String+NSRange.swift
//  HoogleIt
//
//  Created by guoc on 24/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

// https://gist.github.com/robnadin/2720534f91702c444b6b9bde0fdfe224#gistcomment-1925909
extension String {
    func nsRange(from range: Range<String.Index>) -> NSRange {
        let from = range.lowerBound.samePosition(in: utf16)
        let to = range.upperBound.samePosition(in: utf16)
        return NSRange(location: utf16.distance(from: utf16.startIndex, to: from),
                       length: utf16.distance(from: from, to: to))
    }
    
    func range(from nsRange: NSRange) -> Range<String.Index> {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self)
            else
        {
            preconditionFailure("Failed to convert NSRange (\(nsRange)) to Range<String.Index>")
        }
        return from ..< to
    }
}

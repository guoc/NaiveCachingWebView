//
//  FBSnapshotTestCase+Extension.swift
//  NaiveCachingWebView
//
//  Created by guoc on 28/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

public extension FBSnapshotTestCase {

    func FBSnapshotCompareReferenceImage(_ referenceImage: UIImage!, to image: UIImage!, tolerance: CGFloat, identifier: String? = nil) {
        
        let snapshotTestController = FBSnapshotTestController(test: type(of: self))
        
        do {
            try snapshotTestController?.compareReferenceImage(referenceImage, to: image, tolerance: tolerance)
        } catch let error {
            try! snapshotTestController?.saveFailedReferenceImage(referenceImage, test: image, selector: invocation?.selector, identifier: identifier ?? "")
            XCTFail("Snapshot comparison failed: \(error)", file: #file, line: #line)
        }
    }
    
    func image(forViewOrLayer viewOrLayer: Any!) -> UIImage! {
        
        let snapshotTestController = FBSnapshotTestController(test: type(of: self))
        return snapshotTestController?._image(forViewOrLayer: viewOrLayer)
    }

}

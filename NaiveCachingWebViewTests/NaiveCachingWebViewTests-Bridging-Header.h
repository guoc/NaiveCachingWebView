//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <UIKit/UIKit.h>
#import <FBSnapshotTestCase/FBSnapshotTestCase.h>

@interface FBSnapshotTestController (Private)

- (UIImage *)_imageForViewOrLayer:(id)viewOrLayer;

@end

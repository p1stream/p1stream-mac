#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>

@protocol PreviewClientDelegate

- (void)previewSetSurface:(IOSurfaceRef)surfaceRef;
- (void)previewUpdated;

@end

@interface PreviewClient : NSObject <NSMachPortDelegate>

@property id<PreviewClientDelegate> delegate;

- (instancetype)initWithMixerId:(NSString *)mixerId;
- (void)destroy;

@end

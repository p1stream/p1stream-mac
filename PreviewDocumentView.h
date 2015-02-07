#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "PreviewClient.h"

@interface PreviewDocumentView : NSOpenGLView <WebDocumentView, PreviewClientDelegate>

@property (nonatomic) NSString *mixerId;

- (instancetype)initWithFrame:(NSRect)frameRect;

@end

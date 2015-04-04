#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface PreviewDocumentView : NSOpenGLView <WebDocumentView>

@property (nonatomic) NSString *mixerId;

- (instancetype)initWithFrame:(NSRect)frameRect;

@end

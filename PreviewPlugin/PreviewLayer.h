#import <QuartzCore/QuartzCore.h>
#import "PreviewClient.h"

@interface PreviewLayer : CAOpenGLLayer <PreviewClientDelegate>

@property (nonatomic) NSString *mixerId;

@end

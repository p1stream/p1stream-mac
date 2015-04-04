#import "PreviewDocumentView.h"
#import "PreviewLayer.h"
#import <QuartzCore/QuartzCore.h>

@implementation PreviewDocumentView {
    NSString *_mixerId;
    PreviewLayer *_layer;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _layer = [PreviewLayer new];

        self.layer = _layer;
        self.wantsLayer = TRUE;
    }
    return self;
}

- (NSString *)mixerId
{
    return _mixerId;
}

- (void)setMixerId:(NSString *)mixerId
{
    if ([mixerId isEqualToString:_mixerId])
        return;

    _mixerId = mixerId;
    [self updatePreviewMixerId];
}

- (void)viewDidMoveToSuperview
{
    self.needsLayout = TRUE;
    [self updatePreviewMixerId];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
    self.needsLayout = TRUE;
}

- (void)updatePreviewMixerId
{
    _layer.mixerId = self.superview != nil ? _mixerId : nil;
}

- (void)layout
{
    CGSize size = self.superview.bounds.size;
    CGRect frame = CGRectMake(0, 0, size.width, size.height);

    self.frame = frame;
    _layer.frame = frame;

    [super layout];
}

- (void)setDataSource:(WebDataSource *)dataSource
{
}

- (void)dataSourceUpdated:(WebDataSource *)dataSource
{
    NSString *str = [[NSString alloc] initWithData:dataSource.data encoding:NSUTF8StringEncoding];
    if (str)
        self.mixerId = str;
}

- (void)viewWillMoveToHostWindow:(NSWindow *)hostWindow
{
}

- (void)viewDidMoveToHostWindow
{
}

@end

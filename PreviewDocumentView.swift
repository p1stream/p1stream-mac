import Cocoa
import WebKit

class PreviewDocumentView: NSView, WebDocumentView {

    private let previewLayer = PreviewLayer()

    var mixerId: String? {
        didSet {
            updatePreviewMixerId();
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder);
        setupPreviewLayer();
    }

    override init() {
        super.init();
        setupPreviewLayer();
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect);
        setupPreviewLayer();
    }

    func setupPreviewLayer() {
        layer = previewLayer;
        wantsLayer = true;
    }

    override func viewDidMoveToSuperview() {
        updatePreviewMixerId();
        needsLayout = true;
    }

    override func resizeWithOldSuperviewSize(oldSize: NSSize) {
        needsLayout = true;
    }

    func updatePreviewMixerId() {
        previewLayer.mixerId = superview != nil ? mixerId : nil;
    }

    func setNeedsLayout(flag: Bool) {
        super.needsLayout = flag;
    }

    override func layout() {
        let size = self.superview!.bounds.size;
        let newFrame = NSMakeRect(0, 0, size.width, size.height);

        frame = newFrame;
        previewLayer.frame = newFrame;

        super.layout();
    }

    func setDataSource(dataSource: WebDataSource!) {
    }

    func dataSourceUpdated(dataSource: WebDataSource!) {
        mixerId = NSString(data: dataSource.data, encoding: NSUTF8StringEncoding);
    }

    func viewWillMoveToHostWindow(hostWindow: NSWindow!) {
    }

    func viewDidMoveToHostWindow() {
    }

}

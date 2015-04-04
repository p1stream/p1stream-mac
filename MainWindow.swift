import Cocoa
import WebKit

class MainWindow: NSWindowController, NSWindowDelegate {

    let blankUrl = NSURL(string: "about:blank")!
    var startUrl: NSURL?

    @IBOutlet weak var webView: WebView!

    override func showWindow(sender: AnyObject?) {
        let wasVisible = window?.visible == true
        super.showWindow(sender)

        if !wasVisible {
            let request = NSURLRequest(URL: startUrl!)
            webView.mainFrame.loadRequest(request)
        }
    }

    override func windowDidLoad() {
        webView.customUserAgent = "p1stream-mac"
    }

    func windowWillClose(notification: NSNotification) {
        let request = NSURLRequest(URL: blankUrl)
        webView.mainFrame.loadRequest(request)
    }

}

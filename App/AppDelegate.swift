import Cocoa
import WebKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private let serverTask = ServerTask()
    private let mainWindow = MainWindow(windowNibName: "MainWindow")

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "onTaskMessage:",
            name: "ServerTaskMessage",
            object: serverTask
        )
        serverTask.start()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        mainWindow.close()
        serverTask.stop()
    }

    func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if (mainWindow.startUrl != nil) {
            mainWindow.showWindow(sender)
            mainWindow.window!.makeKeyAndOrderFront(sender)
        }
        return false
    }

    func onTaskMessage(aNotification: NSNotification) {
        let info = aNotification.userInfo!
        let msg = info["ServerTaskMessageContents"] as [String: AnyObject]
        switch msg["t"] as String {
            case "started":
                let value = msg["v"] as [String: AnyObject]
                let url = value["url"] as String
                mainWindow.startUrl = NSURL(string: url)
                mainWindow.showWindow(nil)
            default:
                break
        }
    }

}

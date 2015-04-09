import Foundation

class ServerTask: NSObject {

    private let task = NSTask()
    private let stdIn = NSPipe()
    private let stdOut = NSPipe()
    private let notificationCenter = NSNotificationCenter.defaultCenter()
    private var buffer = NSMutableData()

    override init() {
        super.init()

        let pkgPath = NSBundle.mainBundle().resourcePath! + "/p1stream"
        task.launchPath = pkgPath + "/bin/iojs"
        task.arguments = [pkgPath + "/p1stream.js", "--rpc"]
        task.standardInput = stdIn
        task.standardOutput = stdOut

        notificationCenter.addObserver(
            self, selector: "onReadCompletion:",
            name: NSFileHandleReadCompletionNotification,
            object: stdOut.fileHandleForReading
        )
        stdOut.fileHandleForReading.readInBackgroundAndNotify()
    }

    func start() {
        task.launch()
    }

    func stop() {
        stdIn.fileHandleForWriting.closeFile()
        task.waitUntilExit()
    }

    func onReadCompletion(aNotification: NSNotification) {
        let info = aNotification.userInfo!
        if let error = info["NSFileHandleError"] as! NSNumber? {
            println("Child process stdout read error: \(error)")
        } else if let data = info[NSFileHandleNotificationDataItem] as? NSData {
            if data.length != 0 {
                buffer.appendData(data)
                stdOut.fileHandleForReading.readInBackgroundAndNotify()
                flushBuffer()
            }
        }
    }

    func flushBuffer() {
        let charBuffer = UnsafePointer<CChar>(buffer.bytes)
        let length = buffer.length

        var start = 0
        for var i = 0; i < length; i++ {
            if charBuffer[i] == 0x0A {
                let chunk = buffer.subdataWithRange(NSMakeRange(start, i - start))
                handleMessage(chunk)
                start = i + 1
            }
        }

        if start != 0 {
            buffer = NSMutableData(data: buffer.subdataWithRange(
                NSMakeRange(start, length - start)
            ))
        }
    }

    func handleMessage(data: NSData) {
        var errorVar: NSError?
        let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(
            data,
            options: nil,
            error: &errorVar
        )
        if let error = errorVar {
            println("Child process invalid JSON message: \(error)")
        }
        else if let msg = json as? [String: AnyObject] {
            notificationCenter.postNotificationName(
                "ServerTaskMessage",
                object: self,
                userInfo: ["ServerTaskMessageContents": msg]
            )
        }
        else {
            println("Child process invalid JSON message")
        }
    }

}

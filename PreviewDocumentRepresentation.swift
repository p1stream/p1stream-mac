import Cocoa
import WebKit

class PreviewDocumentRepresentation: NSObject, WebDocumentRepresentation {

    func setDataSource(dataSource: WebDataSource!) {
    }

    func receivedData(data: NSData!, withDataSource dataSource: WebDataSource!) {
    }

    func receivedError(error: NSError!, withDataSource dataSource: WebDataSource!) {
    }

    func finishedLoadingWithDataSource(dataSource: WebDataSource!) {
    }

    func canProvideDocumentSource() -> Bool {
        return false
    }

    func documentSource() -> String! {
        return ""
    }

    func title() -> String! {
        return "P1stream preview"
    }

}

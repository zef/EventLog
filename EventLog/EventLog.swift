//
//  EventLog.swift
//  EventLog
//
//  Created by Zef Houssney on 4/9/15.
//

import Foundation

// would rather use a struct... but going class for @objc compatibility.
// I thought of wrapping up the compatibility stuff in its own class
// that references the struct, but think that's overkill for now...
@objc class EventLog: NSObject {

    @objc enum EventType: Int {
        case BlankType, UserInteraction, Checkpoint, Success, Error

        func stringValue() -> String? {
            switch self {
            case BlankType:
                return nil
            case UserInteraction:
                return "User Interaction"
            case Checkpoint:
                return "Checkpoint"
            case Success:
                return "Success"
            case Error:
                return "Error"
            }
        }
    }

    struct Event {
        let message: String
        var type: EventType?
        let time = NSDate()

        func offsetSince(startTime: NSDate) -> NSTimeInterval {
            return time.timeIntervalSinceDate(startTime)
        }

        func dictionaryValue() -> [String : String] {
            return [
                "message" : message,
                "type" : type?.stringValue() ?? "",
                "time" : EventLog.JSONTimeFormatter.stringFromDate(time),
            ]
        }

        func stringValue() -> String {
            let noticeType: String
            if let typeValue = type?.stringValue() {
                noticeType = "[\(typeValue)] "
            } else {
                noticeType = ""
            }

            return "\(noticeType)\(message)"
        }
    }

    var name: String
    var events = [Event]()
    let creationTime = NSDate()
    var loggingEnabled = false

    init(name: String) {
        self.name = name
    }

    static var JSONTimeFormatter: NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SSS"
        return formatter
    }

    @objc func addEvent(message: String, type: EventType = .BlankType) {
        let event = Event(message: message, type: type)
        events.append(event)
        logEventAdded(event)
    }

    func logEventAdded(event: Event) {
        if loggingEnabled {
            println("\(name): \(offsetFor(event)): \(event.stringValue())")
        }
    }

    func offsetFor(event: Event) -> String {
        return EventLog.formatTime(event.offsetSince(self.creationTime))
    }

    func stringValue() -> String {
        let strings = events.map { event -> String in
            let time = self.offsetFor(event)
            return "\(time): \(event.stringValue())"
        }
        return join("\n", strings)
    }

    func jsonValue() -> String {
        let eventList = events.map { event -> [String : String] in
            var dict = event.dictionaryValue()
            dict["offset"] = self.offsetFor(event)
            return dict
        }

        let data = NSJSONSerialization.dataWithJSONObject(eventList, options: .PrettyPrinted, error: nil)
        return NSString(data: data!, encoding: NSUTF8StringEncoding)! as String
    }

    static func formatTime(totalSeconds: Double) -> String {
        let remainder = totalSeconds % 1
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / (60 * 60)
        let subSeconds = (round(remainder * 100 + 0.001) / 100) * 100
        let string = String(format: "%1d:%02d:%02d.%02d", Int(hours), Int(minutes), Int(seconds), Int(subSeconds))

        var startIndex = string.startIndex
        var indexOfDesiredChar: String.Index?

        while indexOfDesiredChar == nil {
            let char = string[startIndex]
            if char == "0" || char == ":" {
                startIndex = startIndex.successor()
            } else if char == "." {
                indexOfDesiredChar = startIndex.predecessor()
            } else {
                indexOfDesiredChar = startIndex
            }
        }

        return string.substringFromIndex(indexOfDesiredChar!)
    }
}
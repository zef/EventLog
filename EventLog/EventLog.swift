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
struct EventLog {

    enum EventType: Int {
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
        let time: NSDate

        init(message: String, type: EventType?, time: NSDate = NSDate()) {
            self.message = message
            self.type = type
            self.time = time
        }

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

        static func fromDictionary(dictionary: [String: String]) -> Event? {
            var time: NSDate?
            if let timeString = dictionary["time"] {
                if let date = EventLog.JSONTimeFormatter.dateFromString(timeString) {
                    time = date
                }
            }
            if let message = dictionary["message"], time = time {
                return Event(message: message, type: nil, time: time)
            }
            return nil
        }
    }

    var name: String
    var events = [Event]()
    let creationTime: NSDate
    var consoleLoggingEnabled = false
    var persisted = false

    init (_ name: String) {
        if let saved = EventLog.loadFromDisk(name) {
            self = saved
        } else {
            self.name = name
            self.creationTime = NSDate()
        }
    }

    init (name: String, creationTime: NSDate, events: [Event]) {
        self.name = name
        self.creationTime = creationTime
        self.events = events
    }

    mutating func addEvent(message: String, type: EventType = .BlankType) {
        let event = Event(message: message, type: type)
        events.append(event)
        logEventAdded(event)
    }

    func logEventAdded(event: Event) {
        if consoleLoggingEnabled {
            println("\(name): \(offsetFor(event)): \(event.stringValue())")
        }
    }

    func offsetFor(event: Event) -> String {
        return EventLog.formatTimeOffset(event.offsetSince(self.creationTime))
    }

    var stringValue: String {
        let strings = events.map { event -> String in
            let time = self.offsetFor(event)
            return "\(time): \(event.stringValue())"
        }
        return join("\n", strings)
    }

    var dictionaryValue: [String: AnyObject] {
        let eventList = events.map { event -> [String : String] in
            var dict = event.dictionaryValue()
            dict["offset"] = self.offsetFor(event)
            return dict
        }

        return [
            "name": name,
            "creationTime": EventLog.JSONTimeFormatter.stringFromDate(creationTime),
            "exportTime": EventLog.JSONTimeFormatter.stringFromDate(NSDate()),
            "events": eventList,
        ]
    }

    func jsonValue(pretty: Bool = false) -> String {
        let options = pretty ? NSJSONWritingOptions.PrettyPrinted : nil
        let data = NSJSONSerialization.dataWithJSONObject(dictionaryValue, options: options, error: nil)
        return NSString(data: data!, encoding: NSUTF8StringEncoding)! as String
    }

    func saveToDisk() -> Bool {
        return jsonValue().writeToFile(savePath, atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    }

    static func loadFromDisk(name: String) -> EventLog? {
        if let json = NSString(contentsOfFile: savePath(name), encoding: NSUTF8StringEncoding, error: nil) {
            if let data = NSJSONSerialization.JSONObjectWithData(json.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, options: nil, error: nil) as? [String: AnyObject] {
                var creationTime = NSDate()
                if let dateString = data["creationTime"] as? String {
                    if let date = EventLog.JSONTimeFormatter.dateFromString(dateString) {
                        creationTime = date
                    }
                }
                var events = [Event]()
                if let eventData = data["events"] as? [[String: String]] {
                    for data in eventData {
                        if let event = Event.fromDictionary(data) {
                            events.append(event)
                        }
                    }
                }
                return EventLog(name: name, creationTime: creationTime, events: events)
            }
        }
        return nil
    }

    var savePath: String {
        return EventLog.savePath(name)
    }

    static func savePath(name: String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory,.UserDomainMask,true).first as! String
        return "\(documentsPath)/EventLog-\(name).json"
    }

    static func formatTimeOffset(totalSeconds: Double) -> String {
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

    static var JSONTimeFormatter: NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SSS"
        return formatter
    }
}

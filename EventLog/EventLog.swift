//
//  EventLog.swift
//  EventLog
//
//  Created by Zef Houssney on 4/9/15.
//

import Foundation


protocol EventLogMessage {
    static var eventLog: EventLog { get }
    static var name: String { get }
    var logName: String { get }

    var title: String { get }
    var attributes: [String: String] { get }
    var stringValue: String { get }
}

struct EventLog {

    struct Event {
        let title: String
        let attributes: [String: String]
        let stringValue: String
        let time: NSDate

        struct Keys {
            static let Title = "title"
            static let Time = "time"
            static let StringValue = "stringValue"
        }

        init(message: EventLogMessage, attributes: [String: String]? = nil) {
            self.title = message.title
            self.stringValue = message.stringValue
            self.time = NSDate()

            var allAttributes = message.attributes
            if let attributes = attributes {
                for (key, value) in attributes {
                    allAttributes[key] = value
                }
            }
            self.attributes = allAttributes

        }
        init(title: String, attributes: [String: String], stringValue: String, time: NSDate) {
            self.title = title
            self.attributes = attributes
            self.stringValue = stringValue
            self.time = time
        }

        func offsetSince(startTime: NSDate) -> NSTimeInterval {
            return time.timeIntervalSinceDate(startTime)
        }

        func dictionaryValue() -> [String : String] {
            var dict = attributes
            dict[Keys.Title] = title
            dict[Keys.Time] = EventLog.JSONTimeFormatter.stringFromDate(time)
            dict[Keys.StringValue] = stringValue
            return dict
        }

        static func fromDictionary(dictionary: [String: String]) -> Event? {
            var attributes = dictionary

            if let title = attributes.removeValueForKey(Keys.Title), timeString = attributes.removeValueForKey(Keys.Time), stringValue = attributes.removeValueForKey(Keys.StringValue) {
                
                var time = NSDate()
                if let date = EventLog.JSONTimeFormatter.dateFromString(timeString) {
                    time = date
                }
                
                return Event(title: title, attributes: attributes, stringValue: stringValue, time: time)
            }

            return nil
        }
    }

    var name: String
    var events = [Event]()
    let creationTime: NSDate
    var consoleLoggingEnabled = true
    var persisted = true

    static private var storage = [String: EventLog]()

    init (_ name: String) {
        if let stored = EventLog.storage[name] {
            self = stored
        } else if let saved = EventLog.loadFromDisk(name) {
            self = saved
        } else {
            self.name = name
            self.creationTime = NSDate()
            EventLog.storage[name] = self
        }
    }

    init (name: String, creationTime: NSDate, events: [Event]) {
        self.name = name
        self.creationTime = creationTime
        self.events = events
    }

    static func add(message: EventLogMessage, attributes: [String: String]? = nil) {
        var log = EventLog(message.logName)
        let message = Event(message: message, attributes: attributes)
        log.addEvent(message)
        log.save()
    }

    mutating func addEvent(event: Event) {
        events.append(event)
        didAddLogEvent(event)
    }

    private func didAddLogEvent(event: Event) {
        if consoleLoggingEnabled {
            println("\(name): \(offsetFor(event)): \(event.stringValue)")
        }
    }

    func offsetFor(event: Event) -> String {
        return EventLog.formatTimeOffset(event.offsetSince(self.creationTime))
    }

    var stringValue: String {
        let strings = events.map { event -> String in
            let time = self.offsetFor(event)
            return "\(time): \(event.stringValue)"
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

    func save() {
        EventLog.storage[name] = self
        saveToDisk()
    }

    func saveToDisk() {
        if persisted {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
                jsonValue().writeToFile(savePath, atomically: true, encoding: NSUTF8StringEncoding, error: nil)
            })
        }
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

    func reset() {
        EventLog.storage.removeValueForKey(name)
        NSFileManager.defaultManager().removeItemAtPath(savePath, error: nil)
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
        let totalHours = totalSeconds / (60 * 60)
        let hours = totalHours % 24
        let days = totalHours / 24
        let subSeconds = (round(remainder * 100 + 0.001) / 100) * 100
        let string = String(format: "%1dd+%02d:%02d:%02d.%02d", Int(days), Int(hours), Int(minutes), Int(seconds), Int(subSeconds))

        var startIndex = string.startIndex
        var indexOfDesiredChar: String.Index?

        while indexOfDesiredChar == nil {
            let char = string[startIndex]
            if char == "0" || char == ":" || char == "d" || char == "+" {
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

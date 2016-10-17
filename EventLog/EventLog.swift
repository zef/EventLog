//
//  EventLog.swift
//  EventLog
//
//  Created by Zef Houssney on 4/9/15.
//

import Foundation

typealias LoggableDictionary = [String: LoggableValue]

public protocol LoggableValue {
    // this Any type should be something that can be converted by JSONSerialization
    // if it is not, the value will stored using String(describing: yourValue)
    // default conformances are defined at bottom of this file.
    var loggableValue: Any { get }
}

protocol EventLogMessage {
    // Default is "EventLog", override to separate into multiple instances of EventLog
    var logName: String { get }

    // Required, but enums with a String value will use that value automatically
    var title: String { get }

    // Defaults to empty, but you can implement to add your own attributes
    var attributes: LoggableDictionary { get }

    // Defaults to title, but can be overridden to customize behavior when printed.
    var stringValue: String { get }

    // Implement this to disable events from being added under certain circumstances.
    func shouldAdd() -> Bool

    // Implement this to execute code after an event is added to its EventLog
    func afterAdd()
}

extension EventLogMessage {
    var logName: String {
        return "EventLog"
    }

    var attributes: LoggableDictionary {
        return [:]
    }

    var stringValue: String {
        return title
    }

    func shouldAdd() -> Bool {
        return true
    }

    func afterAdd() { }

    // internal
    var eventLog: EventLog {
        return EventLog(logName)
    }
}

extension EventLogMessage where Self: RawRepresentable, Self.RawValue == String {
    var title: String {
        return rawValue
    }
}

struct EventLog {

    struct Event {
        let title: String
        let attributes: LoggableDictionary
        let stringValue: String
        let time: Date

        struct Keys {
            static let Title = "title"
            static let Time = "time"
            static let StringValue = "stringValue"
        }

        init(message: EventLogMessage, attributes: LoggableDictionary? = nil) {
            self.title = message.title
            self.stringValue = message.stringValue
            self.time = Date()

            var allAttributes = message.attributes
            if let attributes = attributes {
                for (key, value) in attributes {
                    allAttributes[key] = value
                }
            }
            self.attributes = allAttributes
        }

        fileprivate init?(dictionary: LoggableDictionary) {
            var attributes = dictionary
            if let title = attributes.removeValue(forKey: Keys.Title) as? String,
               let stringValue = attributes.removeValue(forKey: Keys.StringValue) as? String,
               let timeString = attributes.removeValue(forKey: Keys.Time) as? String {

                self.title = title
                self.stringValue = stringValue
                self.attributes = attributes

                self.time = EventLog.ISO8601Formatter.date(from: timeString) ?? Date()
            } else {
                return nil
            }
        }

        func offsetSince(time startTime: Date) -> TimeInterval {
            return time.timeIntervalSince(startTime)
        }

        func dictionaryValue() -> [String: Any] {
            var dict = EventLog.validatedLoggableDictionary(dictionary: attributes)
            dict[Keys.Title] = title
            dict[Keys.Time] = EventLog.ISO8601Formatter.string(from: time)
            dict[Keys.StringValue] = stringValue
            return dict
        }
    }

    var name: String
    var events = [Event]()
    let creationTime: Date
    var consoleLoggingEnabled = true
    var persisted = true

    static fileprivate var memoryStorage = [String: EventLog]()

    init(_ name: String) {
        if let stored = EventLog.memoryStorage[name] {
            self = stored
        } else if let saved = EventLog.loadFromDisk(named: name) {
            self = saved
        } else {
            self.name = name
            self.creationTime = Date()
            EventLog.memoryStorage[name] = self
        }
    }

    init(name: String, creationTime: Date, events: [Event]) {
        self.name = name
        self.creationTime = creationTime
        self.events = events
    }

    static func add(_ message: EventLogMessage, attributes: LoggableDictionary? = nil) {
        if message.shouldAdd() {
            var log = message.eventLog
            log.add(event: Event(message: message, attributes: attributes))
            log.save()
            message.afterAdd()
        }
    }

    fileprivate mutating func add(event: Event) {
        events.append(event)
        didAdd(event: event)
    }

    fileprivate func didAdd(event: Event) {
        if consoleLoggingEnabled {
            print("\(name) @ \(offsetFor(event: event)): \(event.stringValue)")
        }
    }

    func offsetFor(event: Event) -> String {
        return EventLog.formatTimeOffset(event.offsetSince(time: self.creationTime))
    }

    func events(matching message: EventLogMessage) -> [Event] {
        return events.filter { $0.title == message.title }
    }

    var stringValue: String {
        let strings = events.map { event -> String in
            let time = self.offsetFor(event: event)
            return "\(time): \(event.stringValue)"
        }
        return strings.joined(separator: "\n")
    }

    var dictionaryValue: [String: Any] {
        let eventList = events.map { event -> [String: Any] in
            var dict = event.dictionaryValue()
            dict["offset"] = self.offsetFor(event: event)
            return dict
        }

        return [
            "name": name,
            "creationTime": EventLog.ISO8601Formatter.string(from: creationTime),
            "exportTime": EventLog.ISO8601Formatter.string(from: Date()),
            "events": eventList,
        ]
    }

    func jsonValue(pretty: Bool = false) -> String {
        let options: JSONSerialization.WritingOptions = pretty ? JSONSerialization.WritingOptions.prettyPrinted : []
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionaryValue, options: options)
            if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String {
                return string
            } else {
                print("EventLog encountered error converting data to JSON string.")
                return ""
            }
        } catch {
            print("EventLog encountered error converting dictionaryValue to Data.")
            return ""
        }
    }

    func save() {
        saveToMemory()
        saveToDisk()
    }

    func reset() {
        EventLog.memoryStorage.removeValue(forKey: name)
//        creationTime = Date()
        do {
            try FileManager.default.removeItem(atPath: savePath)
        } catch {
            print("EventLog encountered error removing saved file.")
        }
    }

    fileprivate func saveToMemory() {
        EventLog.memoryStorage[name] = self
    }

    fileprivate func saveToDisk() {
        if persisted {
            DispatchQueue.global(qos: .background).async(execute: { () -> Void in
                do {
                    try self.jsonValue().write(toFile: self.savePath, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    print("EventLog encountered error when writing JSON to disk.")
                }
            })
        }
    }

    static fileprivate func loadFromDisk(named name: String) -> EventLog? {
        if let json = try? NSString(contentsOfFile: savePath(forName: name), encoding: String.Encoding.utf8.rawValue) {
            guard let jsonData = json.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false) else { return nil }

            if let data = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                guard let data = data else { return nil }

                var creationTime = Date()
                if let dateString = data["creationTime"] as? String {
                    creationTime = EventLog.ISO8601Formatter.date(from: dateString) ?? Date()
                }
                var events = [Event]()
                if let eventData = data["events"] as? [LoggableDictionary] {
                    for data in eventData {
                        if let event = Event(dictionary: data) {
                            events.append(event)
                        }
                    }
                }
                return EventLog(name: name, creationTime: creationTime, events: events)
            }
        }
        return nil
    }

    fileprivate var savePath: String {
        return EventLog.savePath(forName: name)
    }

    static fileprivate func savePath(forName name: String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return "\(documentsPath)/EventLog-\(name).json"
    }

    static func validatedLoggableDictionary(dictionary: LoggableDictionary) -> [String: Any] {
        var validated = dictionary as [String: Any]
        for (key, value) in dictionary {
            validated[key] = value.validatedLoggableValue
        }
        return validated
    }

    static func formatTimeOffset(_ totalSeconds: Double) -> String {
        let remainder = totalSeconds.truncatingRemainder(dividingBy: 1)
        let seconds = totalSeconds.truncatingRemainder(dividingBy: 60)
        let minutes = (totalSeconds / 60).truncatingRemainder(dividingBy: 60)
        let totalHours = totalSeconds / (60 * 60)
        let hours = totalHours.truncatingRemainder(dividingBy: 24)
        let days = totalHours / 24
        let subSeconds = (round(remainder * 100 + 0.001) / 100) * 100
        let string = String(format: "%1dd+%02d:%02d:%02d.%02d", Int(days), Int(hours), Int(minutes), Int(seconds), Int(subSeconds))

        var startIndex = string.startIndex
        var indexOfDesiredChar: String.Index?

        while indexOfDesiredChar == nil {
            let char = string[startIndex]
            if char == "0" || char == ":" || char == "d" || char == "+" {
                startIndex = string.index(after: startIndex)
            } else if char == "." {
                indexOfDesiredChar = string.index(before: startIndex)
            } else {
                indexOfDesiredChar = startIndex
            }
        }

        return string.substring(from: indexOfDesiredChar!)
    }

    static var ISO8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSxxx"
        return formatter
    }()
}


extension LoggableValue {
    public var loggableValue: Any {
        return self
    }

    public var validatedLoggableValue: Any {
        let value = loggableValue
        guard JSONSerialization.isValidJSONObject([value]) else {
            return String(describing: value)
        }
        return value
    }
}

extension String: LoggableValue {}
extension Int: LoggableValue {}
extension Float: LoggableValue {}
extension Double: LoggableValue {}

// these will throw out values that do not conform to LoggableValue
// Swift does not (yet) allow Array/Dictionary extensions with constraints to conform to a protocol
// when it does we can do something like this and simplify the function.
// extension Array: LoggableValue where Element: LoggableValue  { }
extension Array: LoggableValue {
    public var loggableValue: Any {
        return self.flatMap { $0 as? LoggableValue }.map { $0.validatedLoggableValue }
    }
}
// note that this also throws out both:
//   keys that are not String
//   values that are not LoggableValue
extension Dictionary: LoggableValue {
    public var loggableValue: Any {
        var loggableDict = [String: Any]()
        for (key, value) in self {
            if let key = key as? String, let value = value as? LoggableValue {
                loggableDict[key] = value.validatedLoggableValue
            }
        }
        return loggableDict
    }
}


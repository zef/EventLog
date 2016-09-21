//
//  EventLog.swift
//  EventLog
//
//  Created by Zef Houssney on 4/9/15.
//

import Foundation


protocol EventLogMessage {
    // Default is "EventLog", override to separate into multiple instances of EventLog
    var logName: String { get }

    // Required, but enums with a String value will use that value automatically
    var title: String { get }

    // Defaults to empty, but you can implement to add your own attributes
    var attributes: [String: String] { get }

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

    var attributes: [String: String] {
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
        let attributes: [String: String]
        let stringValue: String
        let time: Date

        struct Keys {
            static let Title = "title"
            static let Time = "time"
            static let StringValue = "stringValue"
        }

        init(message: EventLogMessage, attributes: [String: String]? = nil) {
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

        init?(dictionary: [String: String]) {
            var attributes = dictionary
            if let title = attributes.removeValue(forKey: Keys.Title), let timeString = attributes.removeValue(forKey: Keys.Time), let stringValue = attributes.removeValue(forKey: Keys.StringValue) {

                self.title = title
                self.attributes = attributes
                self.stringValue = stringValue

                if let date = EventLog.JSONTimeFormatter.date(from: timeString) {
                    self.time = date
                } else {
                    self.time = Date()
                }
            } else {
                return nil
            }
        }

        func offsetSince(time startTime: Date) -> TimeInterval {
            return time.timeIntervalSince(startTime)
        }

        func dictionaryValue() -> [String : String] {
            var dict = attributes
            dict[Keys.Title] = title
            dict[Keys.Time] = EventLog.JSONTimeFormatter.string(from: time)
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

    init (_ name: String) {
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

    init (name: String, creationTime: Date, events: [Event]) {
        self.name = name
        self.creationTime = creationTime
        self.events = events
    }

    static func add(_ message: EventLogMessage, attributes: [String: String]? = nil) {
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
            print("\(name): \(offsetFor(event: event)): \(event.stringValue)")
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

    var dictionaryValue: [String: AnyObject] {
        let eventList = events.map { event -> [String : String] in
            var dict = event.dictionaryValue()
            dict["offset"] = self.offsetFor(event: event)
            return dict
        }

        return [
            "name": name as AnyObject,
            "creationTime": EventLog.JSONTimeFormatter.string(from: creationTime) as AnyObject,
            "exportTime": EventLog.JSONTimeFormatter.string(from: Date()) as AnyObject,
            "events": eventList as AnyObject,
        ]
    }

    func jsonValue(_ pretty: Bool = false) -> String {
        let options: JSONSerialization.WritingOptions = pretty ? JSONSerialization.WritingOptions.prettyPrinted : []
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionaryValue, options: options)
            return NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        } catch {
            return ""
        }
    }

    func save() {
        saveToMemory()
        saveToDisk()
    }

    fileprivate func saveToMemory() {
        EventLog.memoryStorage[name] = self
    }

    fileprivate func saveToDisk() {
        if persisted {
            DispatchQueue.global(qos: .background).async(execute: { () -> Void in
                do {
                    try self.jsonValue().write(toFile: self.savePath, atomically: true, encoding: String.Encoding.utf8)
                } catch {}
            })
        }
    }

    static fileprivate func loadFromDisk(named name: String) -> EventLog? {
        if let json = try? NSString(contentsOfFile: savePath(forName: name), encoding: String.Encoding.utf8.rawValue) {
            guard let jsonData = json.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false) else { return nil }

            if let data = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject] {
                guard let data = data else { return nil }

                var creationTime = Date()
                if let dateString = data["creationTime"] as? String, let date = EventLog.JSONTimeFormatter.date(from: dateString) {
                    creationTime = date
                }
                var events = [Event]()
                if let eventData = data["events"] as? [[String: String]] {
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

    func reset() {
        EventLog.memoryStorage.removeValue(forKey: name)
        do {
            try FileManager.default.removeItem(atPath: savePath)
        } catch { }
    }

    fileprivate var savePath: String {
        return EventLog.savePath(forName: name)
    }

    static fileprivate func savePath(forName name: String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return "\(documentsPath)/EventLog-\(name).json"
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

    static var JSONTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SSS"
        return formatter
    }()
}

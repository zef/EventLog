//
//  EventLogTests.swift
//  EventLogTests
//
//  Created by Zef Houssney on 4/9/15.
//

import UIKit
import XCTest

// This is to test that we handle values not supported by JSONSerialization
// and don't just crash. We do this by storing non-conforming values by passing them
// through to String(describing: yourValue)
// To log a date yourself without passing to the above method, you can return your own value
// inside loggableValue yourself, or convert it to your own value before storing it
extension Date: LoggableValue {}

enum TestMessage: String, EventLogMessage {
    static var logName = "Test Log"
    static var eventLog: EventLog {
        return EventLog(logName)
    }

    var logName: String {
        return TestMessage.logName
    }

    case One = "One"
    case Two = "Two"
    case Three = "Three"
    case Four = "Four"
    case Unaddable = "Unaddable"


    var title: String {
        return rawValue
    }

    var attributes: LoggableDictionary {
        return ["number": number]
    }

    var number: Int {
        switch self {
        case .One:
            return 1
        case .Two:
            return 2
        case .Three:
            return 3
        case .Four:
            return 4
        case .Unaddable:
            return 5
        }
    }

    var stringValue: String {
        return "\(number): \(title)"
    }

    func shouldAdd() -> Bool {
        switch self {
        case .Unaddable:
            return false
        default:
            return true
        }
    }

}

class EventLogTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestMessage.eventLog.reset()
    }

    func testName() {
        XCTAssertEqual(TestMessage.eventLog.name, "Test Log")
    }

    func testEvents() {
        EventLog.add(TestMessage.One)
        EventLog.add(TestMessage.Two)
        EventLog.add(TestMessage.Three)
        EventLog.add(TestMessage.Four)

        XCTAssertEqual(TestMessage.eventLog.events.count, 4)

        if let event = TestMessage.eventLog.events.first {
            XCTAssertEqual(event.title, "One")
            XCTAssertEqual(event.attributes["number"] as! Int, 1)
        } else {
            XCTFail("No Event Found")
        }
        
        if let event = TestMessage.eventLog.events.last {
            XCTAssertEqual(event.title, "Four")
            XCTAssertEqual(event.attributes["number"] as! Int, 4)
        } else {
            XCTFail("No Event Found")
        }
        
    }

    func testCallbacks() {
        EventLog.add(TestMessage.One)
        EventLog.add(TestMessage.Two)
        EventLog.add(TestMessage.Three)
        EventLog.add(TestMessage.Four)
        EventLog.add(TestMessage.Unaddable)

        XCTAssertEqual(TestMessage.eventLog.events.count, 4)
    }

    func testArbitraryValues() {
        EventLog.add(TestMessage.One, attributes: ["Some": "Thing"])

        if let event = TestMessage.eventLog.events.first {
            XCTAssertEqual(event.attributes["Some"] as! String, "Thing")
        } else {
            XCTFail("No Event Found")
        }
    }

    func testNestedValues() {
        let logAttributes = ["Some": ["Nested": "Thing"]]
        EventLog.add(TestMessage.One, attributes: logAttributes)

        if let event = TestMessage.eventLog.events.first {
            if let dict = event.attributes["Some"] as? LoggableDictionary,
               let string = dict["Nested"] as? String {
                XCTAssertEqual(string, "Thing")
            } else {
                XCTFail("Data not valid")
            }
        } else {
            XCTFail("No Event Found")
        }
    }

    // testing that we don't crash here, as much as we are the expected values
    func testNonSerializableValues() {
        let date = Date()
        EventLog.add(TestMessage.One, attributes: [
            "Date": date,
            "DictDate": ["Date": date],
            "ArrayDate": [date]
        ])

        let expectedString = String(describing: date)
        if let eventDict = TestMessage.eventLog.events.first?.dictionaryValue() {
            if let dateString = eventDict["Date"] as? String {
                XCTAssertEqual(expectedString, dateString)
            } else {
                XCTFail("Date was not stored")
            }

            if let dict = eventDict["DictDate"] as? [String: String] {
                XCTAssertEqual(expectedString, dict["Date"])
            } else {
                XCTFail("Date was not stored in nested dictionary")
            }

            if let array = eventDict["ArrayDate"] as? [String] {
                XCTAssertEqual(expectedString, array.first)
            } else {
                XCTFail("Date was not stored in nested array")
            }
        } else {
            XCTFail("No Event Found")
        }
    }

    func testFiltering() {
        EventLog.add(TestMessage.One)
        EventLog.add(TestMessage.Two)
        EventLog.add(TestMessage.One)
        EventLog.add(TestMessage.Three)
        EventLog.add(TestMessage.One)
        EventLog.add(TestMessage.Four)
        EventLog.add(TestMessage.One)

        let events = TestMessage.eventLog.events(matching: TestMessage.One)
        XCTAssertEqual(events.count, 4)
    }

    func testFormatTime() {
        let minute: Double = 60
        let hour = minute * 60
        XCTAssertEqual(EventLog.formatTimeOffset(1), "1.00")
        XCTAssertEqual(EventLog.formatTimeOffset(1.01), "1.01")
        XCTAssertEqual(EventLog.formatTimeOffset(1.014), "1.01")
        XCTAssertEqual(EventLog.formatTimeOffset(1.015), "1.02")
        XCTAssertEqual(EventLog.formatTimeOffset(minute + 1.01), "1:01.01")
        XCTAssertEqual(EventLog.formatTimeOffset(hour + minute + 1), "1:01:01.00")
        XCTAssertEqual(EventLog.formatTimeOffset(24 * hour - 1), "23:59:59.00")
        XCTAssertEqual(EventLog.formatTimeOffset(24 * hour + minute + 1), "1d+00:01:01.00")
        XCTAssertEqual(EventLog.formatTimeOffset(24 * hour), "1d+00:00:00.00")
        XCTAssertEqual(EventLog.formatTimeOffset(48 * hour), "2d+00:00:00.00")
    }

    
    func testPerformanceExample() {
        self.measure() {
            let range = 1...25
            for _ in range {
                EventLog.add(TestMessage.One)
            }
            for _ in range {
                EventLog.add(TestMessage.Two)
            }
            for _ in range {
                EventLog.add(TestMessage.Three)
            }
            for _ in range {
                EventLog.add(TestMessage.Four)
            }
        }
    }
}

//
//  EventLogTests.swift
//  EventLogTests
//
//  Created by Zef Houssney on 4/9/15.
//  Copyright (c) 2015 Made by Kiwi. All rights reserved.
//

import UIKit
import XCTest

enum TestMessage: String, EventLogMessage {
    case One = "One"
    case Two = "Two"
    case Three = "Three"
    case Four = "Four"
    case Unaddable = "Unaddable"

    static var eventLog: EventLog {
        return EventLog(name)
    }
    static var name: String {
        return "Test Log"
    }
    var logName: String {
        return TestMessage.name
    }

    var title: String {
        return rawValue
    }

    var attributes: [String: String] {
        return ["number": String(number)]
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

    func shouldAdd(log: EventLog) -> Bool {
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

//    override func teardown() {
//        log = EventLog(name: "Main")
//
//        super.tearDown()
//    }

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
            XCTAssertEqual(event.attributes["number"]!, "1")
        } else {
            XCTFail("No Event Found")
        }
        
        if let event = TestMessage.eventLog.events.last {
            XCTAssertEqual(event.title, "Four")
            XCTAssertEqual(event.attributes["number"]!, "4")
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
            XCTAssertEqual(event.attributes["Some"]!, "Thing")
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

        let events = TestMessage.eventLog.eventsWithMessage(TestMessage.One)
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
        self.measureBlock() {
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

    func performAfter(seconds: Int64, completion: () -> ()) {
        let time = seconds * Int64(NSEC_PER_SEC)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, time), dispatch_get_main_queue(), completion)
    }
}

//
//  EventLogTests.swift
//  EventLogTests
//
//  Created by Zef Houssney on 4/9/15.
//  Copyright (c) 2015 Made by Kiwi. All rights reserved.
//

import UIKit
import XCTest

class EventLogTests: XCTestCase {

    var log = EventLog(name: "Main")

    override func setUp() {
        super.setUp()
    }

//    override func teardown() {
//        log = EventLog(name: "Main")
//
//        super.tearDown()
//    }

    func testName() {
        XCTAssertEqual(log.name, "Main")
    }

    func testEventTypes() {
        var running = true

        let expectaiton = expectationWithDescription("Adding events...")

        log = EventLog(name: "Main")
        performAfter(1, completion: { () -> () in
            self.log.addEvent("A good thing happened")

            self.performAfter(1, completion: { () -> () in
                self.log.addEvent("A bad thing happened", type: .Error)

                if let type = self.log.events.first?.type {
                    XCTAssertEqual(type, EventLog.EventType.BlankType)
                }

                if let type = self.log.events.last?.type {
                    XCTAssertEqual(type, EventLog.EventType.Error)
                }

                println("-------------")
                println(self.log.stringValue())
                println("-------------")
                println(self.log.jsonValue())
                println("-------------")
                expectaiton.fulfill()
            })
        })

        self.waitForExpectationsWithTimeout(2.5, handler: { (error) -> Void in

        })
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
        XCTAssertEqual(EventLog.formatTimeOffset(24 * hour + minute + 1), "24:01:01.00")
        XCTAssertEqual(EventLog.formatTimeOffset(24 * hour), "24:00:00.00")
    }

//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measureBlock() {
//            // Put the code you want to measure the time of here.
//        }
//    }

    func performAfter(seconds: Int64, completion: () -> ()) {
        let time = seconds * Int64(NSEC_PER_SEC)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, time), dispatch_get_main_queue(), completion)
    }
}

//
//  DateProviding.swift
//  SportBoardApp
//
//  Created by Codex on 10/3/25.
//

import Foundation

protocol DateProviding {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
    var calendar: Calendar { Calendar.current }
}

struct FixedDateProvider: DateProviding {
    let now: Date
    let calendar: Calendar
}

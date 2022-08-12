//
//  Task+Sleep.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import Foundation

extension DispatchTimeInterval: Comparable {
    public static func < (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> Bool {
        return lhs.totalNanoseconds < rhs.totalNanoseconds
    }
    var totalNanoseconds: Int64 {
        switch self {
        case .nanoseconds(let ns): return Int64(ns)
        case .microseconds(let us): return Int64(us) * 1_000
        case .milliseconds(let ms): return Int64(ms) * 1_000_000
        case .seconds(let sec): return Int64(sec) * 1_000_000_000
        case .never: fatalError("infinite nanoseconds")
        @unknown default: fatalError("unhandled case")
        }
    }
    var timeInterval: TimeInterval {
        return Double(totalNanoseconds) / 1_000_000_000
    }
}

extension DispatchTime {
    static func timeIntervalSince(_ time: DispatchTime) -> TimeInterval {
        time.distance(to: .now()).timeInterval
    }
}

extension Task where Success == Never, Failure == Never {
    enum SleepError: Error {
        case invalidDuration(_ duration: DispatchTimeInterval)
    }

    static func sleep(_ time: DispatchTimeInterval) async throws {
        let nanoseconds = time.totalNanoseconds
        guard nanoseconds > 0 else {
            throw SleepError.invalidDuration(time)
        }

        try await Task.sleep(nanoseconds: UInt64(nanoseconds))
    }
}

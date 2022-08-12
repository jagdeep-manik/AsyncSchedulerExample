//
//  AsyncSchedule.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import Foundation
import Combine

/// A repeatable work item.
protocol AsyncSchedule {
    var uuid: UUID { get }
    func execute() async -> DispatchTimeInterval
}

/// A hint is a signal for the schedule to run immediately.
///
/// For example, let's say you poll for a resource every 10 minutes,
/// but you want to support fetching that resource immediately when
/// the user changes the shift. To do that, you can make the schedule
/// conform to this protocol and whenever the publisher in `hint`
/// receives a message, your schedule will be fired.
protocol AsyncHintableSchedule {
    associatedtype HintType
    var uuid: UUID { get }
    var hint: AnyPublisher<HintType, Never> { get }
    func execute(hint: HintType?) async -> DispatchTimeInterval
}

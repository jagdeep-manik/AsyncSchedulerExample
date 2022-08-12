//
//  AsyncScheduler.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import Foundation
import Combine

/// State relevant to an active schedule.
struct ScheduleState {
    let task: Task<(), Error>
    let observations: Set<AnyCancellable>?
}

/// Tracks active schedules to retain them and support cancellation.
actor SchedulerState {
    var scheduleStateByID: [UUID: ScheduleState] = [:]

    func registerSchedule(id: UUID,
                          observations: Set<AnyCancellable>? = nil,
                          operation: @escaping @Sendable () async throws -> Void) {
        cancelSchedule(id: id)
        scheduleStateByID[id] = ScheduleState(task: Task(operation: operation), observations: observations)
    }

    func cancelSchedule(id: UUID) {
        guard let scheduleState = scheduleStateByID[id] else {
            return
        }

        scheduleState.task.cancel()
        scheduleStateByID[id] = nil
    }

    func cancelAll() {
        scheduleStateByID.keys.forEach { (id: UUID) in
            cancelSchedule(id: id)
        }

        scheduleStateByID = [:]
    }
}

final class AsyncScheduler {


    // MARK: - Private Vars

    private let schedulerState = SchedulerState()


    // MARK: - Functions

    func schedule(_ asyncSchedule: AsyncSchedule) {
        execute(asyncSchedule)
    }

    func schedule<T: AsyncHintableSchedule>(_ asyncSchedule: T) {
        execute(asyncSchedule, hint: nil)
    }

    func unschedule(_ asyncSchedule: AsyncSchedule) {
        Task {
            await schedulerState.cancelSchedule(id: asyncSchedule.uuid)
        }
    }

    func unschedule<T: AsyncHintableSchedule>(_ asyncSchedule: T) {
        Task {
            await schedulerState.cancelSchedule(id: asyncSchedule.uuid)
        }
    }

    func unscheduleAll() {
        Task {
            await schedulerState.cancelAll()
        }
    }


    // MARK: - Private Functions

    private func execute<T: AsyncHintableSchedule>(_ schedule: T, hint: T.HintType?) {
        Task {
            let taskOperation: @Sendable () async throws -> Void = {
                try await Self.repeatedlyExecute(schedule, hint: hint)
            }

            var observations = Set<AnyCancellable>()
            schedule
                .hint
                .sink { [weak self] hint in
                    self?.execute(schedule, hint: hint)
                }
                .store(in: &observations)

            await schedulerState.registerSchedule(id: schedule.uuid, observations: observations, operation: taskOperation)
        }
    }

    private func execute(_ schedule: AsyncSchedule) {
        Task {
            let taskOperation: @Sendable () async throws -> Void = {
                try await Self.repeatedlyExecute(schedule)
            }

            await schedulerState.registerSchedule(id: schedule.uuid, operation: taskOperation)
        }
    }

    private static func repeatedlyExecute(_ schedule: AsyncSchedule) async throws {
        let timeInterval = await schedule.execute()
        try await Task.sleep(timeInterval)
        try await repeatedlyExecute(schedule)
    }

    private static func repeatedlyExecute<T: AsyncHintableSchedule>(_ schedule: T, hint: T.HintType?) async throws {
        let timeInterval = await schedule.execute(hint: hint)
        try await Task.sleep(timeInterval)
        try await repeatedlyExecute(schedule, hint: nil)
    }

}

//
//  AsyncScheduler.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import Foundation
import Combine

typealias TaskOperation = @Sendable () async throws -> Void

/// State relevant to an active schedule.
struct ScheduleState {
    let operation: TaskOperation
    let observations: Set<AnyCancellable>?
    let task: Task<(), Error>

    init(operation: @escaping TaskOperation,
         observations: Set<AnyCancellable>?) {
        self.operation = operation
        self.observations = observations
        self.task = Task(operation: operation)
    }
}

/// Tracks active schedules to retain them and support cancellation.
actor SchedulerState {
    var scheduleStateByID: [UUID: ScheduleState] = [:]

    func registerSchedule(id: UUID,
                          observations: Set<AnyCancellable>? = nil,
                          operation: @escaping TaskOperation) {
        cancelSchedule(id: id)
        scheduleStateByID[id] = ScheduleState(operation: operation, observations: observations)
    }

    func cancelSchedule(id: UUID) {
        guard let scheduleState = scheduleStateByID[id] else {
            return
        }

        scheduleState.task.cancel()
        scheduleStateByID[id] = nil
    }

    func restartTask(id: UUID, newOperation: TaskOperation? = nil) {
        guard let scheduleState = scheduleStateByID[id] else {
            return
        }

        scheduleStateByID[id] = ScheduleState(
            operation: newOperation ?? scheduleState.operation,
            observations: scheduleState.observations
        )
    }

    func cancelAll() {
        scheduleStateByID.keys.forEach { (id: UUID) in
            cancelSchedule(id: id)
        }

        scheduleStateByID = [:]
    }
}

final class AsyncScheduler: Sendable {


    // MARK: - Private Vars

    private let schedulerState = SchedulerState()


    // MARK: - Functions

    func schedule(_ asyncSchedule: AsyncSchedule) {
        start(asyncSchedule)
    }

    func schedule<T: AsyncHintableSchedule>(_ asyncSchedule: T) {
        start(asyncSchedule, hint: nil)
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

    private func start<T: AsyncHintableSchedule>(_ schedule: T, hint: T.HintType?) {
        Task {
            let taskOperation = makeTaskOperation(for: schedule, hint: hint)
            var observations = Set<AnyCancellable>()
            schedule
                .hint
                .sink { [weak self] hint in
                    self?.start(schedule, hint: hint)
                }
                .store(in: &observations)

            await schedulerState.registerSchedule(id: schedule.uuid, observations: observations, operation: taskOperation)
        }
    }

    private func start(_ schedule: AsyncSchedule) {
        Task {
            let taskOperation = makeTaskOperation(for: schedule)
            await schedulerState.registerSchedule(id: schedule.uuid, operation: taskOperation)
        }
    }

    /// This function will be repeated for each invocation of the schedule.
    /// Initially, this was written to recursively call itself. But to avoid deep
    /// stack depth, we spawn a new `Task` for each invocation.
    private func executeLoop(_ schedule: AsyncSchedule) async throws {
        let timeInterval = await schedule.execute()
        try await Task.sleep(timeInterval)
        await schedulerState.restartTask(id: schedule.uuid)
    }

    /// This function will be repeated for each invocation of the schedule.
    /// Initially, this was written to recursively call itself. But to avoid deep
    /// stack depth, we spawn a new `Task` for each invocation.
    private func executeLoop<T: AsyncHintableSchedule>(_ schedule: T, hint: T.HintType?) async throws {
        let timeInterval = await schedule.execute(hint: hint)
        try await Task.sleep(timeInterval)

        // Repeat without a hint
        let taskOperation = makeTaskOperation(for: schedule, hint: nil)
        await schedulerState.restartTask(id: schedule.uuid, newOperation: taskOperation)
    }

    private func makeTaskOperation(for schedule: AsyncSchedule) -> TaskOperation {
        return { [weak self] in
            try await self?.executeLoop(schedule)
        }
    }

    private func makeTaskOperation<T: AsyncHintableSchedule>(for schedule: T, hint: T.HintType?) -> TaskOperation {
        return { [weak self] in
            try await self?.executeLoop(schedule, hint: hint)
        }
    }

}

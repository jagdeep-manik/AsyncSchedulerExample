//
//  ColorSchedule.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import Foundation
import Combine
import SwiftUI

enum ColorType {
    case red
    case green
    case blue
}

actor ColorState {
    var currentColorType: ColorType = .red
    var colorValue: Double = 0.0
    var ascending: Bool = true

    func changeColorType(to colorType: ColorType) {
        currentColorType = colorType
    }

    func newColor() -> Color {
        // Pulsing behavior from 0.0 to 1.0 and back
        if ascending {
            colorValue += 0.01

            if colorValue > 1 {
                colorValue = 1.0
                ascending = false
            }
        } else {
            colorValue -= 0.01
            if colorValue < 0 {
                colorValue = 0.0
                ascending = true
            }
        }

        switch currentColorType {
        case .red:
            return Color(.sRGB, red: colorValue, green: 0.0, blue: 0.0, opacity: 1.0)
        case .green:
            return Color(.sRGB, red: 0.0, green: colorValue, blue: 0.0, opacity: 1.0)
        case .blue:
            return Color(.sRGB, red: 0.0, green: 0.0, blue: colorValue, opacity: 1.0)
        }
    }
}

final class ColorSchedule: AsyncHintableSchedule {


    // MARK: - Static Vars

    static let interval: DispatchTimeInterval = .milliseconds(16)

    static let colorHint = PassthroughSubject<ColorType, Never>()


    // MARK: - Vars/Lazy Vars

    let uuid = UUID()

    let latestColor = CurrentValueSubject<Color, Never>(.black)

    var hint: AnyPublisher<ColorType, Never> {
        return Self.colorHint.eraseToAnyPublisher()
    }


    // MARK: - Private Vars

    private let colorState = ColorState()


    // MARK: - Functions

    func execute(hint: ColorType?) async -> DispatchTimeInterval {
        if let requestedColorType = hint {
            await colorState.changeColorType(to: requestedColorType)
        }

        let newColor = await colorState.newColor()
        latestColor.value = newColor
        return Self.interval
    }

}

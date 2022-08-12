//
//  ContentView.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import SwiftUI
import Combine

struct ColorData {
    let uuid: UUID
    let color: Color
}

final class ContentViewModel: ObservableObject {

    @Published var colorData: [ColorData] = []

    private var schedules: [ColorSchedule] = []

    private let scheduler = AsyncScheduler()

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(
            withTimeInterval: ColorSchedule.interval.timeInterval,
            repeats: true
        ) { [weak self] timer in
            self?.refreshColorData()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func addSchedule() {
        let colorSchedule = ColorSchedule()
        scheduler.schedule(colorSchedule)
        schedules.append(colorSchedule)
        refreshColorData()
    }

    func removeAll() {
        scheduler.unscheduleAll()
        schedules = []
        refreshColorData()
    }

    func refreshColorData() {
        colorData = schedules.map {
            ColorData(uuid: UUID(), color: $0.latestColor.value)
        }
    }

    func updateColorType(_ colorType: ColorType) {
        ColorSchedule.colorHint.send(colorType)
    }
}

struct ColorView: View {

    @State var color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .foregroundColor(color)
            .frame(height: 50)
    }
}

struct ContentView: View {

    @StateObject var viewModel: ContentViewModel

    @State var color: Color = .white

    var columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Red") {
                    viewModel.updateColorType(.red)
                }
                Button("Green") {
                    viewModel.updateColorType(.green)
                }
                Button("Blue") {
                    viewModel.updateColorType(.blue)
                }
            }
            Button("Remove All Schedules") {
                viewModel.removeAll()
            }
            Button("Add Schedule") {
                viewModel.addSchedule()
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.colorData, id: \.uuid) { (colorData) in
                    ColorView(color: colorData.color)
                }
            }
        }
        .padding()
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ContentViewModel())
    }
}

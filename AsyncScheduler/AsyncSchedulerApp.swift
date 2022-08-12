//
//  AsyncSchedulerApp.swift
//  AsyncScheduler
//
//  Created by Jagdeep Manik on 8/11/22.
//

import SwiftUI

@main
struct AsyncSchedulerApp: App {

    let contentViewModel = ContentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: contentViewModel)
        }
    }
}

//
//  SalatTimeBarApp.swift
//  SalatTimeBar
//
//  Created by Aamir Jawaid on 8/2/23.
//

import SwiftUI

@main
struct SalatTimeBarApp: App {
    @StateObject var vm = AthanTimings.shared
    var body: some Scene {
        MenuBarExtra {
            PopupWindow().environmentObject(vm)
        } label: {
            AppIcon().environmentObject(vm).task {
                vm.scheduleTimer()
            }
        }
        .menuBarExtraStyle(.window)
        
        Window("Settings", id: "UserSettings", content: {
            UserSettingsContentView()
        })
    }
}
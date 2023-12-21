//
//  UserSettings.swift
//  SalatTimeBar
//
//  Created by Aamir Jawaid on 12/13/23.
//

import SwiftUI

public enum Format: String, Identifiable {
    
    public var id: Self {
        return self
    }
    
    case Long, Short, IconOnly
    
    var description: String {
        switch (self) {
        case .Long:
            return "Long (Maghrib)"
        case .Short:
            return "Short (M)"
        case .IconOnly:
            return "Icon only"
        }
    }
    
    static var allFormats: [Format] {
        return [
            Format.Long,
            Format.Short,
            Format.IconOnly
        ]
    }
}

public class UserSettings: ObservableObject {
    public static let shared = UserSettings()
    
    @AppStorage("address") var address: String = ""
    @AppStorage("format") var format: Format = .Long
}

@propertyWrapper
public struct UserSetting<T>: DynamicProperty {
    @ObservedObject var userSettings: UserSettings
    private let keyPath: ReferenceWritableKeyPath<UserSettings, T>
    public init(_ keyPath: ReferenceWritableKeyPath<UserSettings, T>, userSettings: UserSettings = .shared) {
        self.keyPath = keyPath
        self.userSettings = userSettings
    }

    public var wrappedValue: T {
        get { userSettings[keyPath: keyPath] }
        nonmutating set { userSettings[keyPath: keyPath] = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { userSettings[keyPath: keyPath] },
            set: { value in
                userSettings[keyPath: keyPath] = value
            }
        )
    }
}

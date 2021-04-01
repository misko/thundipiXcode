//
//  ThundipiControllerApp.swift
//  Shared
//
//  Created by Michael Dzamba on 3/26/21.
//

import SwiftUI

@main
struct ThundipiControllerApp: App {
    private lazy var bluetoothManager = CoreBluetoothManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        print("hello");
    }
}



//
//  ContentView.swift
//  Shared
//
//  Created by Michael Dzamba on 3/26/21.
//
import SwiftUI

struct ContentView: View {
    init() {
        print("WTF\n")
    }
    //@EnvironmentObject var bluetooth: BLEControl
    var body: some View {
        VStack {
            BluetoothView()
        }
        
         
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.device)
    }
    
}


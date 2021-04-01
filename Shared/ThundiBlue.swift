//
//  ThundiBlue.swift
//  ThundipiController
//
//  Created by Michael Dzamba on 3/29/21.
//

import CoreBluetooth
import Foundation
import SwiftUI

let UUID_relay_characteristic = "2A56"
let UUID_amp_characteristic = "2A58"

struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Color.blue : Color.white)
            .background(configuration.isPressed ? Color.white : Color.blue)
            .cornerRadius(6.0)
            .padding()
    }
}
struct NiceButtonStyle: ButtonStyle {
  var foregroundColor: Color
  var backgroundColor: Color
  var pressedColor: Color

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.headline)
      .padding(10)
      .foregroundColor(foregroundColor)
      .background(configuration.isPressed ? backgroundColor : backgroundColor)
      .cornerRadius(5)
  }
}
extension View {
  func niceButton(
    foregroundColor: Color = .white,
    backgroundColor: Color = .gray,
    pressedColor: Color = .accentColor
  ) -> some View {
    self.buttonStyle(
      NiceButtonStyle(
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        pressedColor: pressedColor
      )
    )
  }
}
struct BluetoothView: View {
    //private var bluetoothManager: CoreBluetoothManager
    //@State var textToUpdate = "Update me!"
    @ObservedObject var bluetoothManager = CoreBluetoothManager()
    init() {
        print("CREATE BM")
        //self.bluetoothManager = CoreBluetoothManager()
        //super.init(nibName: nil, bundle: nil)
        //bluetoothManager.delegate = self
        print("CREATE BM - start scan")
        bluetoothManager.startScanning()
    }


    var body: some View {
        VStack {
            Button(action: { bluetoothManager.readRelay() }) {
                Text("Read Relay")
            }
            Button(action: { bluetoothManager.readAmp() }) {
                Text("Read AMP")
            }
            HStack {
                ForEach((0..<bluetoothManager.relay_state.count),  id: \.self) { idx in
                    VStack {
                        Button(action: { bluetoothManager.toggleSingle(relay_idx: idx) }) {
                            if (bluetoothManager.relay_state[idx]==1) {
                                Text("ON").padding().frame(maxWidth: 100, maxHeight: 24).background(/*@START_MENU_TOKEN@*//*@PLACEHOLDER=View@*/Color.blue/*@END_MENU_TOKEN@*/)
                            } else {
                                Text("OFF").padding().frame(maxWidth: 100, maxHeight: 24)
                                
                            }
                        }.disabled(bluetoothManager.relay_state[idx] > 1).niceButton(backgroundColor: bluetoothManager.relay_state[idx]==1 ? .green : .red)
                        Text(bluetoothManager.get_amp_string(idx:idx)).padding()
                    }
                }
            }
        }

         
    }
    

}


class CoreBluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    // MARK: - Public properties
    @Published var relay_state : [UInt8] = [2,2,2,2] {
            didSet {
                //print("set relay")
            }
        }
    @Published var amp_state : [Int16] = [2,2,2,2] {
            didSet {
                //print("set amps")
            }
        }
    var connectedPeripheral: CBPeripheral?
    
    override init() {
        super.init()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            //self.readAmp()
        }
    }
    
    private(set) var peripherals = Dictionary<UUID, CBPeripheral>() {
        didSet {
            //print("SET SOMETHING!")
            //delegate?.peripheralsDidUpdate()
        }
    }
    func get_amp_string(idx: Int ) -> String {
        return String(format: "%.2fA", Float(amp_state[idx])/100)
    }

    func startScanning() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    // MARK: - Private properties
    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    private var name: String?
    private var connecting: Bool = false
    private var relay_characteristic: CBCharacteristic?
    private var amp_characteristic: CBCharacteristic?
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {

            if central.isScanning {
                central.stopScan()
            }

            central.scanForPeripherals(withServices:nil) //[CBUUID(data: 0x1815)]) //[uuid])
        } else {
            #warning("Error handling")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if (peripheral.name != nil) {
            var adv_name = ""
            if let val = advertisementData["kCBAdvDataLocalName"] {
                adv_name = val as! String
            }
            if (adv_name=="thundipi" || peripheral.name=="thundipi") { //Thunderboard #00000") { //thundipi") {
                print("FOUND PERI",peripheral.name!,peripheral.rssi,advertisementData,RSSI)
                connect(central:central, peripheral:peripheral)
            }
            //print(adv_name,peripheral.name!,RSSI,peripheral.identifier.uuidString)
        }
        peripherals[peripheral.identifier] = peripheral
    }
    
    
    func connect(central: CBCentralManager, peripheral: CBPeripheral) {
        if !connecting {
            central.connect(peripheral, options: nil)
            connecting = true
        }
     }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Successfully connected. Store reference to peripheral if not already done.
        print("CONNNECTED?")
        
        connecting = false
        peripheral.delegate=self
        if self.connectedPeripheral==nil {
            peripheral.discoverServices([CBUUID(string: "1815")])
            self.connectedPeripheral = peripheral
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        discoverCharacteristics(peripheral: peripheral)
    }
    
    func discoverCharacteristics(peripheral: CBPeripheral) {
        guard let services = peripheral.services else {
            return
        }
        for service in services {
            peripheral.discoverCharacteristics([CBUUID(string: UUID_relay_characteristic),CBUUID(string: UUID_amp_characteristic)], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in service.characteristics! {
            if (characteristic.uuid.uuidString == UUID_relay_characteristic) {
                print("FOUND RELAY CHAR")
                relay_characteristic = characteristic
                readValue(characteristic: characteristic)
            } else if (characteristic.uuid.uuidString == UUID_amp_characteristic) {
                print("FOUND AMP     CHAR")
                amp_characteristic=characteristic
                readValue(characteristic: characteristic)
            } else {
                print("Found unknown characteristic")
            }
        }
        
    }
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        print("OH OH NAME UPDATE!\n")
        
    }
    
    
    func readRelay() {
        self.connectedPeripheral?.readValue(for: relay_characteristic!)
    }
    func readAmp() {
        guard let thisPeripheral = self.connectedPeripheral, let thisCharacteristic = amp_characteristic else {
                //print("Hello, anonymous!")
                return
        }
        self.connectedPeripheral!.readValue(for: amp_characteristic!)
    }
    func readValue(characteristic: CBCharacteristic) {
        self.connectedPeripheral?.readValue(for: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            return
        }
        if (characteristic==relay_characteristic) {
            relay_state = [UInt8](characteristic.value!)
            print("Read in relay state as",relay_state)
        } else if (characteristic==amp_characteristic) {
            let i16array = characteristic.value!.withUnsafeBytes {
                UnsafeBufferPointer<Int16>(start: $0, count: characteristic.value!.count/2).map(Int16.init(littleEndian:))
            }
            amp_state = i16array
        } else {
            print("read an unknown characteristic")
        }
        
        /*for i in 0..<relay_state.count {
            relay_state[i]=1-relay_state[i]
        }
        write(value:Data(relay_state), characteristic: characteristic)*/
    }
    
    func toggleSingle(relay_idx: Int) {
        print(relay_state)
        if (relay_state[relay_idx]>1) {
            print("invalid value...")
        }
        relay_state[relay_idx]=1-relay_state[relay_idx]
        self.connectedPeripheral?.writeValue(Data(relay_state), for: relay_characteristic!, type: .withResponse)
        
     }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            return
        }
    }
    
    // In CBCentralManagerDelegate class/extension
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("LOST PERIPHERAL")
        startScanning()
        self.connectedPeripheral=nil
        if let error = error {
            // Handle error
            return
        }
        // Successfully disconnected
    }
}

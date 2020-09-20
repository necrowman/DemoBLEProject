//
//  ViewController.swift
//  DemoBLEProject
//
//  Created by Ruslan Yupyn on 28.07.2020.
//  Copyright © 2020 Ruslan Yupyn. All rights reserved.
//

import UIKit
import CoreBluetooth

let serviceUUID = CBUUID(string: "593F3A2E-1A9E-5BBF-1D79-EC8FE102FF42")
let infoCharachteristicUUID = CBUUID(string: "592A3B21-1A9E-5BBF-1D79-EC8FE102FF42")

class ViewController: UIViewController {
    
    @IBOutlet weak var tfSendingInfo: UITextField!
    @IBOutlet weak var lblGetInfo: UILabel!
    @IBOutlet weak var txtViewGetInfo: UITextView!

    var characteristic: CBMutableCharacteristic?
    
    var infoData: Data? {
        didSet {
            if let data = infoData {
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    DispatchQueue.main.async {
                        let newSTR = (self.lblGetInfo.text ?? "") + (self.lblGetInfo.text?.isEmpty ?? true ? "" : "\n") + str
                        self.lblGetInfo.text = newSTR
                        self.txtViewGetInfo.text = newSTR
                    }
                }
                
            }
        }
    }
    var duplexData: Data? {
        didSet {
            if let data = duplexData, let dupleCharacteristic = characteristic {
                self.peripheralManager?.updateValue(data, for: dupleCharacteristic, onSubscribedCentrals: nil)
            }
        }
    }
    
    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    
    var availablePeripherals = [CBPeripheral]()
    var savedDuplexCharacteristic = [CBPeripheral: CBCharacteristic]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    @IBAction func didTapSendInfo(_ sender: UIButton?) {
        DispatchQueue.main.async {
            self.duplexData = (self.tfSendingInfo.text ?? "").data(using: .utf8)
        }
        
    }
}

extension ViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        
        // Create service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        characteristic = CBMutableCharacteristic(type: infoCharachteristicUUID,
                                                           properties: [.write, .read],
                                                           value: nil,
                                                           permissions: [.writeable, .readable])
        
        if let duplexCharacteristic = characteristic {
            //registering characteristics in service
            service.characteristics = [duplexCharacteristic]
            // run manager
            peripheralManager?.add(service)
        }
        
        
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == infoCharachteristicUUID {
                print("Duplex channel info was sent: \(request.value!)")
                peripheralManager?.respond(to: request, withResult: .success)
                infoData = request.value
            }
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("peripheral \(peripheral) started advertising")
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        central.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        availablePeripherals.append(peripheral)
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            if serviceUUID == serviceUUID {
                // get all characteristics for our service
                peripheral.discoverCharacteristics([infoCharachteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == infoCharachteristicUUID {
                peripheral.readValue(for: characteristic)
                savedDuplexCharacteristic[peripheral] = characteristic
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("User info: \(characteristic.value!)")
        self.infoData = characteristic.value
    }
}

extension ViewController {
    func sendInfo(data: Data, forPeripheral peripheral: CBPeripheral) {
        if let characteristic = savedDuplexCharacteristic[peripheral] {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
}

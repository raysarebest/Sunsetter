//
//  SSStatusMenuController.swift
//  Sunsetter
//
//  Created by Michael Hulet on 9/28/18.
//  Copyright © 2018 Michael Hulet. All rights reserved.
//

import Cocoa
import CoreLocation
import Solar

class SSStatusMenuController: NSObject, CLLocationManagerDelegate{

    //MARK: - Properties

    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let locationManager = CLLocationManager()
    var infoItem: NSMenuItem?{
        get{
            return statusMenu.item(at: 0)
        }
    }
    var nextChange: Timer? = nil{
        didSet{
            if let timer = nextChange{
                nextChange?.tolerance = 60
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }

    //MARK: - Lifecycle methods

    @IBAction func quit(_ sender: NSMenuItem) -> Void{
        NSApplication.shared.terminate(self)
    }

    override func awakeFromNib() -> Void{
        super.awakeFromNib()
        statusItem.button?.image = #imageLiteral(resourceName: "Night")
        statusItem.menu = statusMenu

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        beginTrackingLocation()
    }

    //MARK: - CLLocationManagerDelegate conformance

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        beginTrackingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) -> Void{
        guard let currentLocation = locations.last, let sun = Solar(coordinate: currentLocation.coordinate) else{
            return // This should never happen, but we'll check for it to be safe
        }

        setDarkMode(from: sun)
    }

    //MARK: - Utilities

    private func beginTrackingLocation() -> Void{
        let locationAuthorizationStatus = CLLocationManager.authorizationStatus()
        switch locationAuthorizationStatus {
        case .authorizedAlways, .notDetermined:
            if CLLocationManager.significantLocationChangeMonitoringAvailable(){
                locationManager.startMonitoringSignificantLocationChanges()
            }
            else{
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            infoItem?.title = "Location authorization required"
        }
    }

    func setDarkMode(from: Solar?) -> Void{
        guard let sun = from else{
            return
        }
        return setDarkMode(from: sun)
    }

    func setDarkMode(from: Solar) -> Void{
        guard let script = NSAppleScript(source: """
                        tell application id "com.apple.systemevents"
                            tell appearance preferences
                                set dark mode to \(!from.isDaytime)
                            end tell
                        end tell
            """) else{
            return
        }

        var error: NSDictionary? = nil
        script.executeAndReturnError(&error)

        if let error = error, let code = error["NSAppleScriptErrorNumber"] as? Int{
            switch code{
            case -1743:
                infoItem?.title = "Automation authorization required"
            default:
                infoItem?.title = "Error setting appearance"
            }
        }
        else{
            DispatchQueue.main.async {
                self.statusItem.button?.image = from.isDaytime ? #imageLiteral(resourceName: "Day") : #imageLiteral(resourceName: "Night")
            }
        }

        guard let sunrise = from.sunrise, let sunset = from.sunset else{
            return
        }

        nextChange?.invalidate()

        let changeAction: (Timer) -> Void = {_ in
            guard let now = Solar(coordinate: from.coordinate) else{
                return
            }
            self.setDarkMode(from: now)
        }
        let nextEvent: String

        func createTimer(for date: Date) -> Void{
            nextChange = Timer(fire: date, interval: 1, repeats: false, block: changeAction)
        }

        if Date() < sunrise{
            // Sun is still down, but earlier than sunrise
            createTimer(for: sunrise)
            nextEvent = "Sunrise"
        }
        else if from.isDaytime{
            // The sun is up
            createTimer(for: sunset)
            nextEvent = "Sunset"
        }
        else{
            // It's after sunset, so we need to calculate tomorrow's sunrise
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: from.date), let tomorrowSunrise = Solar(for: tomorrow, coordinate: from.coordinate)?.sunrise else{ // This should never fail, but if it does, we'll try again in a minute
                createTimer(for: from.date + 60)
                return
            }
            createTimer(for: tomorrowSunrise)
            nextEvent = "Sunrise"
        }

        guard let changeDate = nextChange?.fireDate else{
            infoItem?.title = "Error calculating change time"
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        DispatchQueue.main.async {
            self.infoItem?.title = "\(nextEvent): \(formatter.string(from: changeDate))"
        }
    }
}

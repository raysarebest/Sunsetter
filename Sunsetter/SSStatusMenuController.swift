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
    var nextChange: NSBackgroundActivityScheduler?

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

        NotificationCenter.default.addObserver(self, selector: #selector(reactToPotentialTimeChangeEvent(_:)), name: .NSSystemClockDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reactToPotentialTimeChangeEvent(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)

        if let here = locationManager.location, let sun = Solar(coordinate: here.coordinate){
            setDarkMode(from: sun)
        }
    }

    deinit {
        nextChange?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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

    func setDarkMode(from: Solar? = nil, forCurrentTime: Bool = true) -> Void{

        let debugFormatter = DateFormatter()

        debugFormatter.timeStyle = .medium
        debugFormatter.dateStyle = .medium

        print("Analyzed sun position at: " + debugFormatter.string(from: Date()))

        guard let oldSunPosition = from else{
            return
        }

        let sunPosition: Solar

        if forCurrentTime, let currentSunPosition = Solar(coordinate: oldSunPosition.coordinate){
            sunPosition = currentSunPosition
        }
        else{
            sunPosition = oldSunPosition
        }

        print("Set dark mode to: \(!sunPosition.isDaytime) at: " + debugFormatter.string(from: Date()))

        setDarkMode(to: !sunPosition.isDaytime)

        guard let sunrise = sunPosition.sunrise, let sunset = sunPosition.sunset else{
            return
        }

        let nextEvent: String

        func createTask(for time: Date) -> Date{
            let taskTolerance: TimeInterval = 60
            let fireTime = time.timeIntervalSinceNow
            if taskTolerance < fireTime{ // The app will crash if we're within the error interval of the fire date when we schedule a task
                nextChange?.invalidate()
                nextChange = NSBackgroundActivityScheduler(identifier: "tech.hulet.Sunsetter.changer")
                nextChange?.interval = fireTime
                nextChange?.tolerance = taskTolerance
                nextChange?.schedule({(completion: NSBackgroundActivityScheduler.CompletionHandler) in
                    self.setDarkMode(from: sunPosition)
                    completion(.finished)
                })
            }
            return time
        }

        let changeDate: Date

        if Date() < sunrise{
            // Sun is still down, but earlier than sunrise
            changeDate = createTask(for: sunrise)
            nextEvent = "rise"
        }
        else if sunPosition.isDaytime{
            // The sun is up
            changeDate = createTask(for: sunset)
            nextEvent = "set"
        }
        else{
            // It's after sunset, so we need to calculate tomorrow's sunrise
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: sunPosition.date), let tomorrowSunrise = Solar(for: tomorrow, coordinate: sunPosition.coordinate)?.sunrise else{ // This should never fail, but if it does, we'll try again in a minute
                changeDate = createTask(for: sunPosition.date + 60)
                return
            }
            changeDate = createTask(for: tomorrowSunrise)
            nextEvent = "rise"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        DispatchQueue.main.async {
            self.infoItem?.title = "Sun\(nextEvent): \(formatter.string(from: changeDate))"
            self.statusItem.button?.image = sunPosition.isDaytime ? #imageLiteral(resourceName: "Day") : #imageLiteral(resourceName: "Night")
        }
    }

    @objc func reactToPotentialTimeChangeEvent(_ notification: Notification) -> Void{
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        print("Reacting to notification: \(notification.name.rawValue) at: " + formatter.string(from: Date()))
        guard let currentLocation = locationManager.location else{
            return
        }
        setDarkMode(from: Solar(coordinate: currentLocation.coordinate))
    }

    func setDarkMode(to: Bool? = nil) -> Void{ // Passing nil here means toggle it

        let action: String

        if let nextState = to{
            action = String(nextState)
        }
        else{
            action = "not dark mode"
        }
        guard let script = NSAppleScript(source: """
                            tell application id "com.apple.systemevents"
                                tell appearance preferences
                                    set dark mode to \(action)
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
    }

    @IBAction func toggleDarkMode(_ sender: NSMenuItem?) -> Void{
        setDarkMode()
    }
}

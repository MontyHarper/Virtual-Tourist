//
//  Settings.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/8/23.
//

import Foundation
import MapKit

// These settings are persisted in UserDefaults.standard
enum Settings: String {
    case currentMap // Current location and zoom shown on the map
    
    static var photosPerPage: Int {
        return 20
    }
}

// Converts between MKMapRect and Dictionary type for storage in UserDefaults
struct MapRectConverter {
    
    static func mapDict(from rect:MKMapRect) -> [String:Double] {
        let long = rect.origin.coordinate.longitude
        let lat = rect.origin.coordinate.latitude
        let width = rect.size.width
        let height = rect.size.height
        return ["longitude": long, "latitude": lat, "width": width, "height": height]
    }
    
    static func mapRect(from dict:[String:Double]) -> MKMapRect {
        let long = dict["longitude"]!
        let lat = dict["latitude"]!
        let width = dict["width"]!
        let height = dict["height"]!
        return MKMapRect(origin: MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: long)),size:MKMapSize(width: width, height: height))
    }
}

// This stores search parameters for distances to search around a pin. Used to search widening areas until at least one page of photos can be attributed to the pin.
struct Radius {
    static let distances = [
        "radius=0.01",
        "radius=0.05",
        "radius=0.1",
        "radius=0.2",
        "radius=0.5",
        "radius=1.0",
        "radius=1.5",
        "radius=2.0",
        "radius=3.0",
        "radius=4.0",
        "radius=8.0",
        "radius=16.0",
        "radius=32.0"
        ]
}



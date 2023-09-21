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
    case currentMap // Stores the current location and zoom shown on the map
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

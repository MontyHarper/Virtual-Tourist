//
//  GeocoderExtension.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/15/23.
//

import Foundation
import MapKit

extension CLGeocoder {
    
    // Returns via the closure a placemark for the given location.
    func fetchPlacemark(_ location: CLLocation, closure: @escaping (MKPlacemark) -> Void ) {
        
        // Set up default return value; empty placemark
        var placeMark = MKPlacemark(coordinate: location.coordinate)
        
        reverseGeocodeLocation(location) { (placemarks, error) in
            
            // Most geocoding requests contain only one placemark result.
            if let place = placemarks?.first {
                placeMark = MKPlacemark(placemark: place)
            }
            
            if error != nil {
                print("An error occurred trying to reverse geocode the location: \(error as Any)")
            }
            
            DispatchQueue.main.async { closure(placeMark) }
        }
    }
}
      

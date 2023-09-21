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
      
        
        // Original extension function no longer needed - tentatively commenting this out
        
        
//        func fetchTitle(_ location: CLLocation, closure: @escaping (String, String) -> Void ) {
//
//            reverseGeocodeLocation(location) { (placemarks, error) in
//
//                guard error == nil else {
//                    print(error as Any)
//                    DispatchQueue.main.async { closure("Unknown","") }
//                    return
//                }
//
//                var title = ""
//                var subTitle = ""
//
//                // Most geocoding requests contain only one placemark result.
//                if let place = placemarks?.first {
//
//                    if let country = place.country {
//                        title =  country
//
//                        if let area = place.administrativeArea {
//                            title = "\(area), \(country)"
//
//                            if let subArea = place.subAdministrativeArea {
//                                title = subArea
//                                subTitle = "in \(area), \(country)"
//
//                                if let city = place.locality {
//                                    title = city
//                                    subTitle = "in \(subArea), \(area), \(country)"
//
//                                    if let subCity = place.subLocality {
//                                        title = "\(subCity), \(city)"
//                                    }
//                                }
//                            }
//                        }
//                    }
//                } else {
//                    title = "Unknown"
//                }
//
//                print("We are at: \(title) \n \(subTitle)")
//                DispatchQueue.main.async { closure(title, subTitle) }
//            }
//        }
//    }
    


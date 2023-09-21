//
//  PinExtension.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/19/23.
//

import Foundation
import MapKit

extension Pin: MKAnnotation {
    
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
}

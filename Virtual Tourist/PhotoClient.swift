//
//  PhotoClient.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/25/23.
//

import Foundation
import MapKit
import SwiftUI


class PhotoClient {
        
    enum Endpoints {
        
        static let base = "https://www.flickr.com/services/rest/"
        static let photoBase = "https://live.staticflickr.com/"
        static let apiKey = "166ffffddfab4f8cf28281297d06b3e2"
        
        case searchPhotos
        case returnPhoto
        
        var urlString: String {
            switch self {
            case .searchPhotos:
                return Endpoints.base + "?method=flickr.photos.search&api_key=\(Endpoints.apiKey)"
            case .returnPhoto:
                return Endpoints.photoBase
            }
        }
    }
    
    // Assembles and returns the URL for a search request.
    class func searchURL(lat: Double, lon: Double, geoArea: String, page: Int) -> URL {
        let string = Endpoints.searchPhotos.urlString + "&lat=\(lat)&lon=\(lon)&\(geoArea)&per_page=20&page=\(page)&extras=geo&format=json"
        if let url = URL(string: string) {
            return url
        } else {
            fatalError("Invalid URL for photo search.")
        }
    }
    
    // Makes a search request for photos near the passed-in Pin; if successful returns an array of APhoto. APhoto is the data structure the json response is decoded into before the data gets persisted in Core Data as a Photo entity.
    class func photoSearch(_ pin: Pin, completion: @escaping (Bool,Error?,[APhoto]?,Pin) -> Void) {
        
        // set up search parameters
        let lat = pin.coordinate.latitude
        let lon = pin.coordinate.longitude
        // geoArea indicates how far out from the pin to search. This returns a search parameter from a list of distances to try.
        let geoArea = Radius.distances[Int(pin.radius)]
        let page = Int(pin.currentPage)
        
        // Set up request, session, task
        let url = searchURL(lat: lat, lon: lon, geoArea: geoArea, page: page)
        print("searching with this URL: \(url)")
        let request = URLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            
            // If data is returned,
            if let data = data {
                
                // Clean the json response of its wrapper; newData contains the result
                var newData = data
                if let responseString = String(data:data, encoding: .utf8) {
                    let prefix = "jsonFlickrApi("
                    let suffix = ")"
                    if responseString.hasPrefix(prefix) && responseString.hasSuffix(suffix) {
                        let startIndex = responseString.index(responseString.startIndex, offsetBy: prefix.count)
                        let endIndex = responseString.index(responseString.endIndex, offsetBy: -suffix.count)
                        let jsonSubstring = responseString[startIndex..<endIndex]
                        if let jsonData = jsonSubstring.data(using: .utf8) {
                            newData = jsonData
                        }
                    }
                }
                    
                // Decode JSON response
                let decoder = JSONDecoder()
                do {
                    let response = try decoder.decode(Response.self, from: newData)
                    let photos = response.photos.photo
                    
                    // Success!
                    // Update pin and return photos.
                    pin.numberOfPages = Int16(response.photos.pages)
                    DispatchQueue.main.async {completion(true, nil, photos, pin)}
                    
                } catch {
                    print("The data doesn't fit our response pattern")
                    DispatchQueue.main.async {completion(false, error, nil, pin)}
                }
            } else {
                print("Request failed")
                DispatchQueue.main.async {completion(false, error, nil, pin)}
            }
        }
        task.resume()
    }
    
    // Given the URL for a photo on flickr, this returns the actual image in Data format.
    class func returnImage(url: URL, completion: @escaping (Bool,Error?,Data?) -> Void) {
        
        // Set up request, session, task
        let request = URLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            
            if let data = data {
                DispatchQueue.main.async {completion(true,nil,data)}
                
            } else {
                DispatchQueue.main.async {completion(false,error,nil)}
                
            }
        }
        task.resume()
    }
    
    
    class func addPhotosToPin(photos:[APhoto],pin:Pin) {
        
        for photo in photos {
            
            let newPhoto = Photo(context:DataController.shared.viewContext)
            newPhoto.photoAlbum = pin
            newPhoto.title = photo.title
            
            // Calculate distance of photo from pin if photo has a location; otherwise leave distance as default value, which is 1000 just to put the photo far away.
            if let lat = Double(photo.latitude), let lon = Double(photo.longitude) {
                let locationPin = CLLocation(latitude:pin.latitude, longitude:pin.longitude)
                let locationPhoto = CLLocation(latitude: lat, longitude: lon)
                newPhoto.distance = locationPhoto.distance(from: locationPin)
            }
            
            // Calculate the url needed to fetch the actual image that goes with this photo.
            let urlString = PhotoClient.Endpoints.returnPhoto.urlString + "\(photo.server)/\(photo.id)_\(photo.secret)_b.jpg"
            newPhoto.url = urlString
                        
            if let url = URL(string: urlString) {
                returnImage(url: url) {success, error, data in
                    if success {
                        newPhoto.image = data
                        pin.numberOfPhotos += 1
                        DataController.shared.saveContexts()
                    } else {
                        print("error loading photo: \(String(describing: error))")
                    }
                } // End trailing closure
            } // End if
            
            DataController.shared.saveContexts()
        }
    }
    
    class func findPhotos(_ pin: Pin, _ closure: (() -> Void)?) {
        
        // if this is an established pin, advance the page and search for photos.
        if pin.new == false {
            
            pin.currentPage += 1
            if pin.currentPage > pin.numberOfPages {
                pin.currentPage = 1
            }
            
            PhotoClient.photoSearch(pin) {success,error,photos,pin in
                
                if let photos = photos {
                    PhotoClient.addPhotosToPin(photos: photos, pin: pin)
                } else {
                    print("Our search has failed to add any new photos. Error: \(String(describing: error))")
                    // This will fail silently. The pin will be re-set as new.
                    pin.new = true
                    pin.currentPage = 1
                }
            }
            
        // if this is a new pin, search for photos, then expand the search area and try again if we don't get enough results.
        } else {
            
            print("searching :\(Radius.distances[Int(pin.radius)])")
            PhotoClient.photoSearch(pin) {success,error,photos,pin in
                
                if success {
                    if let photos = photos {
                        
                        // If we didn't find enough photos...
                        if photos.count < Settings.photosPerPage {
                            
                            // Expand the radius and try again; if we're at max radius fall through.
                            if pin.radius + 1 < Radius.distances.count {
                                pin.radius += 1
                                self.findPhotos(pin, nil)
                            }
                            
                            // If we did find enough photos...
                        } else {
                            
                            // Add the photos to the pin.
                            pin.new = false
                            PhotoClient.addPhotosToPin(photos: photos, pin: pin)
                            
                        }
                    }
                    // Fall through if photos don't materialize
                } else {
                    // If the search was not successful
                    print("There was an error finding photos for this pin: \(String(describing: error))")
                }
            }
            // End of trailing closure
        }
        if let closure = closure {
            closure()
        }
    }
}

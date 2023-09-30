//
//  PhotoClient.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/25/23.
//

import Foundation
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
    
    class func searchURL(lat: Double, lon: Double, geoArea: String, page: Int) -> URL {
        let string = Endpoints.searchPhotos.urlString + "&lat=\(lat)&lon=\(lon)&\(geoArea)&per_page=20&page=\(page)&extras=geo&format=json"
        if let url = URL(string: string) {
            return url
        } else {
            fatalError("Invalid URL for photo search.")
        }
    }
    
    class func photoSearch(pin: Pin, completion: @escaping (Bool,Error?,[APhoto]?,Pin) -> Void) {
        
        let lat = pin.coordinate.latitude
        let lon = pin.coordinate.longitude
        let geoArea = "radius=0.4"
        let page = 1
        // Set up request, session, task
        let url = searchURL(lat: lat, lon: lon, geoArea: geoArea, page: page)
        print("request url: \(url)")
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
                    DispatchQueue.main.async {
                        completion(true, nil, photos, pin)
                    }
                } catch {
                    print("The data doesn't fit our response pattern")
                    completion(false, error, nil, pin)
                }
            } else {
                print("Request failed")
                completion(false, error, nil, pin)
            }
        }
        task.resume()
    }
    
    class func returnImage(url: URL, completion: @escaping (Bool,Error?,Data?) -> Void) {
        
        // Set up request, session, task
        let request = URLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            
            if let data = data {
                
                let image = data
                completion(true,nil,image)
                
            } else {
                completion(false,error,nil)
                
            }
        }
        task.resume()
    }
}

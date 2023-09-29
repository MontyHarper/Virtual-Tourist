//
//  PhotoClient.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/25/23.
//

import Foundation


class PhotoClient {
    
    enum Endpoints {
        
        static let base = "https://www.flickr.com/services/rest/"
        static let apiKey = "166ffffddfab4f8cf28281297d06b3e2"
        
        case searchPhotos
        case fetchPhoto
        
        var urlString: String {
            switch self {
            case .searchPhotos:
                return Endpoints.base + "?method=flickr.photos.search&api_key=\(Endpoints.apiKey)"
            case .fetchPhoto:
                return Endpoints.base + ""
            }
        }
    }
}

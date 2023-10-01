//
//  PhotoPageViewController.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/25/23.
//

import Foundation
import CoreData
import UIKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
 
    // MARK: - Properties
    
    @IBOutlet weak var photoAlbum: UICollectionView!
    
    let dataController = DataController.shared
    var pin: Pin!
    var fetchedPhotos: NSFetchedResultsController<Photo>!
    let defaultImage = UIImage(named:"shrug")
    
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
      
        self.title = "Photos From \(pin.title ?? "Somewhere")"
        
        // Fetch photos attatched to the pin
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "photoAlbum == %@", pin)
        fetchRequest.predicate = predicate
        
        // Sorting by distance from pin
        let sortDescriptor = NSSortDescriptor(key: "distance", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        self.fetchedPhotos = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(pin.id)")
        do {
            try self.fetchedPhotos.performFetch()
        } catch {
            assertionFailure("Unable to fetch photos from core data.")
        }
        
        photoAlbum.delegate = self
        fetchedPhotos.delegate = self
    }
    
    deinit {
        photoAlbum.delegate = nil
    }
    
    
    // MARK: - Collection View Delegate Methods
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let count = fetchedPhotos.fetchedObjects?.count {
            return count
        } else {
            return 0
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoAlbumCell
        
        if let imageData = fetchedPhotos.object(at: indexPath).image {
            let image = UIImage(data:imageData)
            cell.imageView.image = image
        } else {
            cell.imageView.image = defaultImage
            
            // If there's no available image in CoreData, fetch one now.
            if let urlString = fetchedPhotos.object(at: indexPath).url {
                if let url = URL(string:urlString) {
                    PhotoClient.returnImage(url: url) {(success: Bool, error: Error?, image: Data?) in
                        if success {
                            self.fetchedPhotos.object(at: indexPath).image = image
                            self.dataController.saveContexts()
                        } else {
                            print("image has failed to load: \(String(describing: error))")
                        }
                    }
                }
            }
        }
        
        return cell
    }
    
    
    // MARK: - Fetched Results Controller Delegate Methods
    
    // Updates the collectionView whenever a change in the data is detected by the fetched results controller.
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            photoAlbum.insertItems(at: [newIndexPath!])
        case .delete:
            photoAlbum.deleteItems(at: [indexPath!])
        case .update:
            photoAlbum.reloadItems(at: [indexPath!])
        case .move:
            photoAlbum.moveItem(at: indexPath!, to: newIndexPath!)
        @unknown default:
            break
        }
    }
}

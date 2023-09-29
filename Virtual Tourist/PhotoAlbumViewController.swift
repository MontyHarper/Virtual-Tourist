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
 

    @IBOutlet weak var photoAlbum: UICollectionView!
    
    var pin = Pin(context:AppDelegate.dataController.viewContext)
    var fetchedPhotos: NSFetchedResultsController<Photo>!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
      
        self.title = "Photos From \(pin.title ?? "Somewhere")"
        
        // feeling my way here. how do I specify photos attatched to this pin?
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "photoAlbum == %@", pin)
        fetchRequest.predicate = predicate
        
        // Maybe I'll sort by distance from the pin, if I want to make that a calculated property
        let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        self.fetchedPhotos = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: AppDelegate.dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(pin.id)")
        
        photoAlbum.delegate = self
        fetchedPhotos.delegate = self
        
    }
    
    deinit {
        photoAlbum.delegate = nil
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath)
        
        return cell
    }
}

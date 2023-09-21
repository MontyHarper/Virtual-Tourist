//
//  DataController.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 8/20/23.
//  Copyright © 2023 Udacity. All rights reserved.
//

import Foundation
import CoreData

class DataController {
    
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext!
    
    init(ModelName: String) {
        persistentContainer = NSPersistentContainer(name: ModelName)
    }
    
    func configureContexts() {
        backgroundContext = persistentContainer.newBackgroundContext()
        
        viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    func load(completion: (() -> Void)? = nil) {
        persistentContainer.loadPersistentStores { storeDescription, error in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            
 //           self.autoSaveViewContext()
            self.configureContexts()
            completion?()
            
        }
    }
}

// Not sure that I need autosave for this app

//extension DataController {
//
//    func autoSaveViewContext(interval:TimeInterval = 30) {
//        print("autosave")
//        guard interval > 0 else {
//            print("Cannot set negative autosave interval.")
//            return
//        }
//        if viewContext.hasChanges {
//            try? viewContext.save()
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
//            self.autoSaveViewContext(interval: interval)
//        }
//
//    }
//}

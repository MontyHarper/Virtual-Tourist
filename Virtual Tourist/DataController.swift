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
    
    static let shared = DataController(ModelName: "Virtual_Tourist")
    
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext!
    
    private init(ModelName: String) {
        persistentContainer = NSPersistentContainer(name: ModelName)
        load()
    }
    
    private func load() {
        persistentContainer.loadPersistentStores { storeDescription, error in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            
            self.configureContexts()
        }
    }
    
    private func configureContexts() {
        backgroundContext = persistentContainer.newBackgroundContext()
        
        viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    func saveContexts() {
        
        if viewContext.hasChanges {
            do {
                try self.viewContext.save()
            } catch {
                print("could not save viewContext: \(error)")
            }
        }
        if backgroundContext.hasChanges {
            do {
                try self.backgroundContext.save()
            } catch {
                print("could not save backgroundContext: \(error)")
            }
        }
    }
}

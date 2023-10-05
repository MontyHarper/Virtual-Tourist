//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/1/23.
//

import CoreData
import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {

    // MARK: - Properties
    
    var fetchedPins: NSFetchedResultsController<Pin>!
    let geocoder = CLGeocoder()
    
    // Used to give haptic feedback when a pin is dropped. Documentation says to create and destroy the generator as needed, so initializing as nil.
    var feedbackGenerator: UIImpactFeedbackGenerator? = nil
    
    
    @IBOutlet weak var longPress:UILongPressGestureRecognizer!
    @IBOutlet weak var mapView: MKMapView!
    
    
    // MARK: - Lifecycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Retreive the map view last set by the user, if there is one.
        var mapRect = MKMapRect()
        if let dict = UserDefaults.standard.dictionary(forKey: Settings.currentMap.rawValue) as? [String:Double] {
            mapRect = MapRectConverter.mapRect(from: dict)
        } else {
            // If not, load the default region (for first launch).
            mapRect = MKMapRect(origin: MKMapRect.world.origin, size: MKMapRect.world.size)
        }
        
        // Fetch pins from core data into fetched reuslts controller
        let pinFetch:NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        pinFetch.sortDescriptors = [sortDescriptor]
        self.fetchedPins = NSFetchedResultsController(fetchRequest: pinFetch, managedObjectContext: DataController.shared.viewContext, sectionNameKeyPath: nil, cacheName: "pincache")
        do {
            try self.fetchedPins.performFetch()
        } catch {
            assertionFailure("Unable to fetch pins from core data.")
        }
        
        // Set up mapView with persisted borders and pins
        mapView.setVisibleMapRect(mapRect, animated: true)
        if let pins = fetchedPins.fetchedObjects {
            mapView.addAnnotations(pins)
        } else {
            print("No map pins exist.")
        }
        
        // Set up delegation
        mapView.delegate = self
        longPress.delegate = self
        fetchedPins.delegate = self
    }
    
    
    deinit {
        // documentation says to set mapView's delegate to nil when you're done with it
        mapView.delegate = nil
        longPress.delegate = nil
    }
    
    
    // MARK: - @IBActions
    
    // This function shows an alert allowing the user to delete all pins currently visible in the mapView. The user triggers it with a trashcan button in the toolbar. Any photos attached to the pins are also deleted.
    
    @IBAction func deletePinsInView(_ sender: Any) {
                
        guard let pins = fetchedPins.fetchedObjects else {
            // No pins to delete.
            return
        }
        
        let pinsToDelete = pins.filter {mapView.visibleMapRect.contains(MKMapPoint($0.coordinate))}
            
        let alert = UIAlertController(title: "Delete Pins", message: "You're about to delete all \(pinsToDelete.count) pins located on the visible map along with any photos associated with those pins. This cannot be undone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertAction.Style.destructive, handler: { [self]_ in
                print("Deleting pins:")
                mapView.removeAnnotations(pinsToDelete)
                for pin in pinsToDelete {
                    DataController.shared.viewContext.delete(pin)
                }
                DataController.shared.saveContexts()
            }))
            alert.addAction(UIAlertAction(title: "Nevermind", style: UIAlertAction.Style.cancel, handler: {_ in
                self.dismiss(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
    }
    
    
    // This method responds to the long press gesture and initiates the process of creating a new pin.
    @IBAction func pinDrop(_ sender: UIGestureRecognizer) {
   
        switch sender.state {
                        
        case .began:
            
            // Prepare to buzz when a pin is created.
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            feedbackGenerator?.prepare()
            
            // Grab the location touched on screen.
            let touchLocation = longPress.location(in:mapView)
            // Convert that to a location on the map.
            let locationCoordinate = mapView.convert(touchLocation, toCoordinateFrom: mapView)
            // Convert that to a CLLocation for convenience
            let location = CLLocation(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude)
            
            // Buzz to indicate a pin has been dropped.
            feedbackGenerator?.impactOccurred()
            
            // Create the new pin
            findPlacemark(at: location) {name, placemark in
                self.createPinTitles(poiName: name, place: placemark) {title, subtitle in
                    self.createPin(at: placemark, title: title, subtitle: subtitle)
                }
            }
            
        case .cancelled, .ended, .failed:
            
            // Not sure this actually does anything, but I'm trying to ensure the gesture recognizer is ready for the next gesture.
            sender.reset()
            
            // Documentation says to kill the buzzer when you're done with it.
            feedbackGenerator = nil
            
        default:
            break
        }
    }

    
    // MARK: - @objc Gesture-triggered Methods
    
    
    // Presents an alert that allows a user to delete a pin using a long press.
    @objc private func deletePinAlert(_ sender: UILongPressGestureRecognizer) {
 
        guard let view = sender.view as? MKMarkerAnnotationView else {
            return assertionFailure("Gestured Failed: View is not MLMarkerAnnotationView")
        }
        
        guard let pin = view.annotation as? Pin else {
            return assertionFailure("Gesture Failed: AnnotationView is not a Pin")
        }
        
        // Check state in order to trigger the action only once, when state begins.
        if sender.state == .began {
            print("DELETE PIN: \(pin.title ?? "Untitled Pin")")
            
            let alert = UIAlertController(title: "Delete Pin at \(pin.title ?? "Untitled Pin")", message: "You will delete this map pin along with \(pin.numberOfPhotos) photos. This cannot be undone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertAction.Style.destructive, handler: { [self] _ in
                
                // Delete the pin, from the pins array, from the map, from CoreData
                mapView.removeAnnotation(pin)
                DataController.shared.viewContext.delete(pin)
                DataController.shared.saveContexts()
            }))
            alert.addAction(UIAlertAction(title: "Nevermind", style: UIAlertAction.Style.cancel, handler: {_ in
                self.dismiss(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // Tapping a pin takes the user to the photo album attached to that pin.
    @objc private func gotoPhotoPage(_ sender: UITapGestureRecognizer) {
        
        guard let view = sender.view as? MKMarkerAnnotationView else {
            return assertionFailure("Gesture Failed: View is not MKMarkerAnnotationView")
        }
        
        guard let pin = view.annotation as? Pin else {
            return assertionFailure("Gesture Failed: AnnotationView is not a Pin")
        }
                        
        // Set up a new photoAlbumView
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let photoAlbumView = storyboard.instantiateViewController(withIdentifier: "PhotoAlbum") as? PhotoAlbumViewController else {
                return
            }
        
        if pin.numberOfPhotos == 0 {
            
            // If this pin has no photos yet, download photos
            PhotoClient.findPhotos(pin, nil)
            
        }
        
        // Add pin to the view, and present!
        photoAlbumView.pin = pin
        navigationController?.pushViewController(photoAlbumView, animated: true)
        
        }
    
    
    // MARK: - Creation of New Map Annotation (Pin)
    
    
    // This method creates a Pin in the view context using the given location and title, saves the context, and updates the pins array and mapView.
    // Maybe part of this should be moved out of view controller.
    fileprivate func createPin (at location: MKPlacemark, title: String, subtitle: String) {
        let pin = Pin(context:DataController.shared.viewContext)
        pin.longitude = location.coordinate.longitude
        pin.latitude = location.coordinate.latitude
        pin.title = title
        pin.subtitle = subtitle
        DataController.shared.saveContexts()
        PhotoClient.findPhotos(pin, nil)
        mapView.addAnnotation(pin)
    }
    
    // Given a placemark and point of interest name, come up with the best title for our pin.
    // Probably should be moved out of view controller.
    fileprivate func createPinTitles(poiName: String?, place: CLPlacemark, closure: (String,String) -> Void) {
        
        var title = "B.F. Nowhere"
        var subtitle = ""
        
        // Best option: POI Name / City, State, Country
        // If not that: Neighborhood / City, State, Country
        // If not that: City / State, Country
        // If not that: State / Country
        // If not that: "Somewhere in" / Country
        
        let name = poiName ?? ""
        let city = place.locality ?? ""
        let neighborhood = place.subLocality ?? ""
        let state = place.administrativeArea ?? ""
        var country = place.country ?? "Planet Earth"
        country = (country == "United States") ? "USA" : country
        let cityComma = (city == "") ? ("") : (state == "") ? (city) : (city + ", ")
        let stateComma = (state == "") ? ("") : (state + ", ")
        let inOn = (country == "Planet Earth" && state == "" && city == "") ? "on" : "in"
        
        if name != "" {
            title = name
            subtitle = "\(inOn) \(cityComma)\(stateComma)\(country)"
        } else if neighborhood != "" {
            title = neighborhood
            subtitle = "\(inOn) \(cityComma)\(stateComma)\(country)"
        } else if city != "" {
            title = city
            subtitle = "\(inOn) \(stateComma)\(country)"
        } else if state != "" {
            title = state
            subtitle = "\(inOn) \(country)"
        } else {
            title = "Somewhere"
            subtitle = "\(inOn) \(country)"
        }
        
        print("We are at: \(title) \n \(subtitle)")
        closure(title, subtitle)
    }
        
    
    // This method attempts to find a point of interest (POI) near the user-selected location. If successful, it returns true into the completion handler, along with a name and MKPlacemark for the POI.
    fileprivate func searchPOI (_ location: CLLocation, completion: @escaping (Bool,String,MKPlacemark) -> Void) {
        
        // Set up the parameters for determining whether a Point of Interest lies "nearby". If the map is zoomed out beyond "maxZoom", we will assume POIs are not visible, so the user is not attempting to select one. The "searchRadius" determines how close the long press gesture needs to be to an actual POI in order to select it for the pin drop.
        let maxZoom = 0.065
        let searchRadius = 75.0 // meters
        
        // Default values to return if no POI is found.
        var found = false
        var name = ""
        var place = MKPlacemark(coordinate: location.coordinate)
        
        // If the map is not zoomed in close enough to distinguish points of interest (roughly speaking), return the defaults.
        // Note: I wanted to check that a POI was visible on the map before allowing it to become the title for a pin, but couldn't figure out how to access which POIs are currently visible. So this is the best I could do for now.
        guard self.mapView.region.span.longitudeDelta < maxZoom else {
            completion(found,name,place)
            return
        }
        
        // Otherwise, set up to search nearby
        
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: searchRadius)
        let search = MKLocalSearch(request: request)
        
        // Execute the search, with a closure to handle the results
        search.start { response, error in
            
            // If the search results in an error, return the defaults.
            guard error == nil else {
                print(error as Any)
                completion(found,name,place)
                return
            }
            
            if let POIs = response?.mapItems {

                // Sort POIs by distance from the given location.
                let sortedPOIs = POIs.sorted { (item1, item2) -> Bool in
                    let distance1 = location.distance(from: CLLocation(latitude: item1.placemark.coordinate.latitude, longitude: item1.placemark.coordinate.longitude))
                    let distance2 = location.distance(from: CLLocation(latitude: item2.placemark.coordinate.latitude, longitude: item2.placemark.coordinate.longitude))
                    return distance1 < distance2
                }
                
                // Set up new values to return, based on the closest POI.
                found = true
                name = sortedPOIs.first?.name ?? "A place with no name." // This default should never get used
                if let placeMark = sortedPOIs.first?.placemark {
                    place = placeMark
                }
            }
            completion(found,name,place)
        }
    }

    
    // This method uses a Point of Interest (POI) search or Reverse Geolocation to return (via closure) a name (if a POI exists nearby) and Placemark for the new pin.
    fileprivate func findPlacemark(at location: CLLocation, makePinTitles: @escaping (String?, MKPlacemark) -> Void) {
        
        // Match the placemark to a POI if it makes sense to
        searchPOI(location) {found, name, placemark in
            if found {
                makePinTitles(name, placemark)
            } else {
                // Otherwise fetch a placemark using the geocoder
                self.geocoder.fetchPlacemark(location) {placemark in
                    makePinTitles(nil, placemark)
                }
            }
        }
    }
 
 
    // MARK: - Gesture Recognizer Delegate Functions
    
    // This stops the unwanted behavior I was getting, which was that a long press only triggered a reaction every other time. Thank you StackFlow!
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        return gestureRecognizer.view === mapView && otherGestureRecognizer.view is MKMarkerAnnotationView
    }
    
    
    // MARK: - mapView Delegate Functions
    
    // When the mapView changes, convert the new map rect to a dictionary and store in the user defaults, thus persisting the current map.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Save the current region shown on the map.
        UserDefaults.standard.set(MapRectConverter.mapDict(from:mapView.visibleMapRect), forKey:Settings.currentMap.rawValue)
    }
    
    
    // Returns an annotation view for each map pin as needed. This is in progress - not sure how to do what I want. I'd like to show the number of photos available on the given pin, as well as some way of deleting the pin. Our requirement is that tapping the pin will open the photo album.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        // This provides access to the pin's properties.
        let pin = annotation as! Pin
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: pin, reuseIdentifier: reuseId)
            pinView!.subtitleVisibility = .visible
            pinView!.titleVisibility = .visible
            let longPress = UILongPressGestureRecognizer(target:self, action: #selector(deletePinAlert(_:)))
            // Delegate method allows more than one longPress to respond.
            longPress.delegate = self
            let tap = UITapGestureRecognizer(target: self, action: #selector(gotoPhotoPage(_:)))
            pinView!.addGestureRecognizer(longPress)
            pinView!.addGestureRecognizer(tap)
            pinView!.isUserInteractionEnabled = true
            pinView!.canShowCallout = false
        }
        
        pinView!.annotation = pin
        pinView!.glyphText = "\(pin.numberOfPhotos)"
        print("returning pin: \(pin.title ?? "unknown") with \(pin.numberOfPhotos) photos.")
        return pinView
    }
    

    
    // MARK: - Fetched Results Controller Delegate Methods
    
    // Updates the map whenever a change in the data is detected by the fetched results controller.
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        print("fetched results controller triggered")
        switch type {
        case .insert:
            print("insert at \(String(describing: indexPath))")
        case .delete:
            print("delete at \(String(describing: indexPath))")
            
        case .update:
            guard let indexPath = indexPath else {
                break
            }
            let pin = fetchedPins.object(at: indexPath)
            mapView.removeAnnotation(pin)
            mapView.addAnnotation(pin)
            
        case .move:
            print("move at \(String(describing: indexPath))")
        @unknown default:
            print("other at \(String(describing: indexPath))")
        }
    }
}




//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 9/1/23.
//

import CoreData
import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {

    // MARK: - Properties
    
    // One datacontroller to rule them all.
    let dataController = AppDelegate.dataController
    
    // All the persisted map pins get loaded into here.
    var pins:[Pin] = []
    
    // Used to persist the boundaries of mapView.
    var mapRect:MKMapRect!
    
    // Used to reverse geocode locations of map pins.
    let geocoder = CLGeocoder()
    
    // Used to give haptic feedback when a pin is dropped. Documentation says to create and destroy the generator as needed, so initializing as nil.
    var feedbackGenerator: UIImpactFeedbackGenerator? = nil
    
    
    @IBOutlet weak var longPress:UILongPressGestureRecognizer!
    @IBOutlet weak var mapView: MKMapView!
    
    
    // MARK: - Lifecycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Retreive the map view last set by the user, if there is one.
        if let dict = UserDefaults.standard.dictionary(forKey: Settings.currentMap.rawValue) as? [String:Double] {
            mapRect = MapRectConverter.mapRect(from: dict)
        } else {
            // If not, load the default region (for first launch).
            mapRect = MKMapRect(origin: MKMapRect.world.origin, size: MKMapRect.world.size)
        }
        
        // Set up delegation
        mapView.delegate = self
        longPress.delegate = self
        
        // Set up mapView with persisted borders and pins
        mapView.setVisibleMapRect(mapRect, animated: true)
        loadMapData()
        updateMapPins()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        // documentation says to set mapView's delegate to nil when you're done with it
        mapView.delegate = nil
    }
    
    // MARK: - Creation of New Map Annotation (Pin)
    
    
    // This method creates a Pin in the view context using the given location and title, saves the context, and updates the mapView.
    fileprivate func createPin (at location: MKPlacemark, title: String, subTitle: String) {
        let pin = Pin(context:dataController.viewContext)
        pin.longitude = location.coordinate.longitude
        pin.latitude = location.coordinate.latitude
        pin.title = title
        pin.subTitle = subTitle
        try! dataController.viewContext.save()
        print("I made this pin: \(pin)")
        pins.append(pin)
        mapView.addAnnotation(pin)
    }
    
    fileprivate func createPinTitles(poiName: String?, place: CLPlacemark, closure: (String,String) -> Void) {
        
        var title = "B.F. Nowhere"
        var subTitle = ""
        
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
            subTitle = "\(inOn) \(cityComma)\(stateComma)\(country)"
        } else if neighborhood != "" {
            title = neighborhood
            subTitle = "\(inOn) \(cityComma)\(stateComma)\(country)"
        } else if city != "" {
            title = city
            subTitle = "\(inOn) \(stateComma)\(country)"
        } else if state != "" {
            title = state
            subTitle = "\(inOn) \(country)"
        } else {
            title = "Somewhere"
            subTitle = "\(inOn) \(country)"
        }
        
        print("We are at: \(title) \n \(subTitle)")
        closure(title, subTitle)
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

    
    // This method uses a Point of Interest (POI) search or Reverse Geolocation to return via closure a name (if a POI exists nearby) and Placemark for the new pin.
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
    
        
    // This method responds to the long hold gesture and initiates the process of creating a new pin.
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
                self.createPinTitles(poiName: name, place: placemark) {title, subTitle in
                    self.createPin(at: placemark, title: title, subTitle: subTitle)
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

    // This stops the unwanted behavior I was getting, which was that a long press only triggered a reaction every other time. Thank you StackFlow!
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    
    // MARK: - Adding Annotations to MapView
    
    // Fetches all pins from persisted data to hold in pins array.
    func loadMapData() {
        let pinsFetch = NSFetchRequest<Pin>(entityName: "Pin")
        do {
            self.pins = try dataController.viewContext.fetch(pinsFetch)
        } catch {
            fatalError("Failed to fetch pins")
        }
    }
    
    // Updates mapView with current list of annotations.
    func updateMapPins() {
        mapView.addAnnotations(pins)
    }
    
    
    // MARK: - mapView Delegate Functions
    
    // When the mapView changes, convert the new map rect to a dictionary and store in the user defaults, thus persisting the current map.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Save the current region shown on the map.
        UserDefaults.standard.set(MapRectConverter.mapDict(from:mapView.visibleMapRect), forKey:Settings.currentMap.rawValue)
    }
    
    
    // Returns an annotation view for each map pin as needed. This is in progress - not sure how to do what I want. I'd like to show the number of photos available on the given pin, as well as some way of deleting the pin. Our requirement is that tapping the pin will open the photo album. The link stuff is a holdover from the previous "on the map" app.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.rightCalloutAccessoryView = UIButton()
        }
        
        pinView!.annotation = annotation
        
        pinView!.rightCalloutAccessoryView?.isHidden = (pinView!.annotation?.subtitle == "No Link Available")
        pinView!.rightCalloutAccessoryView?.isUserInteractionEnabled = (pinView!.annotation?.subtitle != "No Link Available")
        
        return pinView
    }
    
}




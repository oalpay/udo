//
//  RegionViewController.swift
//  udo
//
//  Created by Osman Alpay on 29/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class RegionViewController:UIViewController,UISearchDisplayDelegate,UITableViewDataSource,UITableViewDelegate,MKMapViewDelegate,CustomMapDelegate {
    @IBOutlet var mapView: MKMapView!
    var searchResults:[MKMapItem] = []
    var localSearch:MKLocalSearch!
    var circleOverlay:MKCircle!
    var resizableOverlayView:CustomMKCircleOverlay!
    var pointAnnotation:MKPointAnnotation!
    var pinAnnotationView:MKPinAnnotationView!
    var touchStartPoint:MKMapPoint!
    var touchStartRadius:Double!
    var radius:Double = 300
    
    override func viewDidLoad() {
        let wildcardGestureRecognizer = WildcardGestureRecognizer()
        wildcardGestureRecognizer.touchesBeganCallback = {(touches:NSSet!, event:UIEvent!) -> Void in
            
            let (touchPoint,touchMapPoint) = self.getTouchPointAndMapPoint(touches)
            
            let isPointInsidePinView = self.pinAnnotationView.pointInside(touchPoint, withEvent: event)
            
            let circleMapRect = self.resizableOverlayView.handleBounds
            let circleMapRectContainsTouch = MKMapRectContainsPoint(circleMapRect, touchMapPoint)
            
            /* Test if the touch was within the bounds of the circle */
            if(circleMapRectContainsTouch && !isPointInsidePinView){
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.mapView.scrollEnabled = false
                })
                self.touchStartPoint = touchMapPoint
                self.touchStartRadius = self.radius
            }else{
                self.touchStartPoint = nil
            }
        }
        wildcardGestureRecognizer.touchesMovedCallback = {(touches:NSSet!, event:UIEvent!) -> Void in
            if event.allTouches()?.count != 1 || self.touchStartPoint == nil {
                return
            }
            let (_,touchMapPoint) = self.getTouchPointAndMapPoint(touches)
            let meterDistance = (touchMapPoint.x - self.touchStartPoint.x)/MKMapPointsPerMeterAtLatitude(self.mapView.centerCoordinate.latitude) + self.touchStartRadius
            self.radius = meterDistance
            
            if(meterDistance > 0){
                self.resizableOverlayView.setCircleRadius(CGFloat(self.radius))
                self.radius = Double(self.resizableOverlayView.getCircleRadius()) // min,max controls
            }
        }
        
        wildcardGestureRecognizer.touchesEndedCallback = {(touches:NSSet!, evemt:UIEvent!) -> Void in
            if self.touchStartPoint == nil {
                return
            }
            self.touchStartPoint = nil
            self.mapView.scrollEnabled = true
            
            let circleMapRect = self.resizableOverlayView.circlebounds
            let visibleMapRect = self.mapView.visibleMapRect
            
            /* Check if the map needs to zoom */
            if(circleMapRect.size.width > visibleMapRect.size.width * 0.75){
                let span = MKCoordinateSpan(latitudeDelta: self.mapView.region.span.latitudeDelta * 1.5 , longitudeDelta: self.mapView.region.span.longitudeDelta * 1.5 )
                let region = MKCoordinateRegion(center: self.pointAnnotation.coordinate, span: span)
                self.mapView.setRegion(region, animated: true)
            }
            if(circleMapRect.size.width < visibleMapRect.size.width * 0.25){
                let span = MKCoordinateSpan(latitudeDelta: self.mapView.region.span.latitudeDelta / 3 , longitudeDelta: self.mapView.region.span.longitudeDelta / 3 )
                let region = MKCoordinateRegion(center: self.pointAnnotation.coordinate, span: span)
                self.mapView.setRegion(region, animated: true)
            }

        }
        
        self.mapView.addGestureRecognizer(wildcardGestureRecognizer)
    }
    
    private func getTouchPointAndMapPoint(touches:NSSet) -> (CGPoint,MKMapPoint){
        let touch = touches.anyObject() as UITouch
        let touchPoint = touch.locationInView(self.mapView)
        let coordinate = self.mapView.convertPoint(touchPoint, toCoordinateFromView: self.mapView)
        return (touchPoint,MKMapPointForCoordinate(coordinate))
    }
    
    override func viewDidAppear(animated: Bool) {
        self.mapView.showsUserLocation = true
    }
    
    func addCircleOverlayAtlocation(coordinate:CLLocationCoordinate2D){
        if let circleOverlay = self.circleOverlay {
            self.mapView.removeOverlay(circleOverlay)
        }
        self.circleOverlay = MKCircle(centerCoordinate: coordinate, radius: Double(self.radius))
        self.circleOverlay.title = "circle"
        self.mapView.addOverlay(self.circleOverlay)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.searchDisplayController?.setActive(false, animated: true)
        let mapItem = self.searchResults[indexPath.row]
        let coordinate = mapItem.placemark.coordinate
        self.mapView.centerCoordinate = coordinate
        let region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000)
        self.mapView.setRegion(region, animated: true)
        
        self.addCircleOverlayAtlocation(coordinate)
        
        if let pointAnnotation = self.pointAnnotation {
            self.mapView.removeAnnotation(self.pointAnnotation)
        }
        self.pointAnnotation = MKPointAnnotation()
        self.pointAnnotation.title = "pin"
        self.pointAnnotation.coordinate = coordinate
        self.mapView.addAnnotation(self.pointAnnotation)
       
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("defaultCellIdentifier") as? UITableViewCell
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "defaultCellIdentifier")
        }
        let mapItem = self.searchResults[indexPath.row]
        cell!.textLabel.text = mapItem.name
        return cell!
    }
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String!) -> Bool {
        if !searchString.isEmpty {
            let searchRequest = MKLocalSearchRequest()
            searchRequest.naturalLanguageQuery = searchString
            searchRequest.region = self.mapView.region
            
            self.localSearch?.cancel()
            self.localSearch = MKLocalSearch(request: searchRequest)
            self.localSearch.startWithCompletionHandler { (responde:MKLocalSearchResponse!, error:NSError!) -> Void in
                if error != nil {
                    return
                }
                self.searchResults = responde.mapItems as [MKMapItem]
                self.searchDisplayController?.searchResultsTableView.reloadData()
            }
        }
        return false
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if annotation.title == "pin" {
            self.pinAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("pin") as? MKPinAnnotationView
            if self.pinAnnotationView == nil {
                self.pinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
                self.pinAnnotationView.draggable = true
            }
            return self.pinAnnotationView
        }
        return nil
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if let circleOverlay = overlay as? MKCircle {
            self.resizableOverlayView = CustomMKCircleOverlay(circle: circleOverlay, withRadius: CGFloat(self.radius), withMin: 100, withMax: 10000)
            self.resizableOverlayView.fillColor = AppTheme.tintColor
            self.resizableOverlayView.alpha = 0.4
            self.resizableOverlayView.border = 60
            self.resizableOverlayView.delegate = self
            return  self.resizableOverlayView
        }
        return nil
    }
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch newState {
        case .Dragging:
            self.mapView.removeOverlay(self.circleOverlay)
        case .Ending:
            self.addCircleOverlayAtlocation(view.annotation.coordinate)
        default:
            break
        }
    }
    
    
    func onRadiusChange(radius: Double) {
        
    }

}

//
//  MapViewController.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 10/20/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "MapViewController.h"
#import <sqlite3.h>

@interface MapViewController ()
@end

@implementation MapViewController {
  GMSMapView        *mapView_;
  CLLocationManager *locationManager_;
  sqlite3           *mapDataDB_;
  NSMutableArray    *mapPolylines_;
  UIView            *markerInfoContentView_;
}

@synthesize mapView;

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.

  self.configModel = [ConfigModel getConfigModel];
  self.trailColorUtil = [TrailColorUtil getTrailColorUtil];

  UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  self.webViewController = [sb instantiateViewControllerWithIdentifier:@"POI Detail View"];

  if ([CLLocationManager locationServicesEnabled]) {
    if (locationManager_ == nil)
      locationManager_ = [[CLLocationManager alloc] init];
    locationManager_.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager_.distanceFilter = 1;
    locationManager_.delegate = self;
    if ([locationManager_ respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
      [locationManager_ requestWhenInUseAuthorization];
    }
    [locationManager_ startUpdatingLocation];
  }

  GMSCameraPosition *camera = [ GMSCameraPosition cameraWithLatitude:44.1525 longitude:-72.475 zoom:14];
  mapView_ =  [GMSMapView mapWithFrame:mapView.bounds camera:camera];
  mapView_.settings.compassButton = YES;
  mapView_.settings.myLocationButton = YES;
  mapView_.mapType = self.configModel.mapType;
  //mapView_.myLocationEnabled = YES;

  //[self drawMapObjects];

  //[mapView_ addObserver:self
  //           forKeyPath:@"myLocation"
  //              options:NSKeyValueObservingOptionNew
  //              context:NULL];

  [mapView addSubview:mapView_];
  mapView_.delegate = self;
  
  //dispatch_async(dispatch_get_main_queue(), ^{
  //    mapView_.myLocationEnabled = YES;
  //});
}

- (void)drawMapObjects {
  [mapView_ clear];
  if (markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }

  NSString *mapDataDBName_ = [[NSBundle mainBundle]
                              pathForResource:@"BarreForestGuide"
                                       ofType:@"sqlite"];
  if (sqlite3_open([mapDataDBName_ UTF8String], &mapDataDB_) == SQLITE_OK) {

    char *season = [self.configModel isSummerMapSeason] ? "summer" : "winter";

    NSString *trailQuerySQL =
        [NSString stringWithFormat:@"select map_object_id,lattitude,longitude from trail,coordinate " \
                                    "where coordinate.map_object_id=trail.id and summer_uses_id=? order by map_object_id,seq;"];
    NSString *trailTypeQuerySQL =
        [NSString stringWithFormat:@"select distinct %s_uses_id from trail;", season];
    sqlite3_stmt *trailQueryStmt = nil;
    sqlite3_stmt *trailTypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [trailQuerySQL UTF8String], -1, &trailQueryStmt, NULL) == SQLITE_OK) {
      if (sqlite3_prepare_v2(mapDataDB_, [trailTypeQuerySQL UTF8String], -1, &trailTypeQueryStmt, NULL) == SQLITE_OK) {
        while(sqlite3_step(trailTypeQueryStmt) == SQLITE_ROW) {
          int trail_type_id = sqlite3_column_int(trailTypeQueryStmt, 0);
          //NSLog(@"trail_type_id %d", trail_type_id);
          UIColor *trail_type_color = [self.trailColorUtil getTrailTypeColor:trail_type_id];
          //if (trail_type_color) NSLog(@"got color %@ for trail_type_id %d", trail_type_color, trail_type_id); // FIXME - remove
          //if (trail_type_color==nil) trail_type_color = [UIColor redColor];
          sqlite3_reset(trailQueryStmt);
          sqlite3_bind_int(trailQueryStmt, 1, trail_type_id);
          GMSMutablePath *trailpath = nil;
          int prev_trail_id = -1;
          while(sqlite3_step(trailQueryStmt) == SQLITE_ROW) {
            int trail_id = sqlite3_column_int(trailQueryStmt, 0);
            double lattitude = sqlite3_column_double(trailQueryStmt, 1);
            double longitude = sqlite3_column_double(trailQueryStmt, 2);
            //NSLog(@"trail_id %d (%f, %f)", trail_id, lattitude, longitude);
            if (prev_trail_id != trail_id) {
              if (trailpath && ([trailpath count]>1)) {
                GMSPolyline *trailpoly = [GMSPolyline polylineWithPath:trailpath];
                trailpoly.strokeColor = trail_type_color;
                trailpoly.map = mapView_;
                //NSLog(@"Putting Polyline on the map");
              }
              trailpath = [GMSMutablePath path];
              prev_trail_id = trail_id;
            }
            [trailpath addCoordinate:CLLocationCoordinate2DMake(lattitude, longitude)];
          }
          if (trailpath && ([trailpath count]>1)) {
            GMSPolyline *trailpoly = [GMSPolyline polylineWithPath:trailpath];
            trailpoly.strokeColor = trail_type_color;
            trailpoly.map = mapView_;
          }
        }
        sqlite3_finalize(trailTypeQueryStmt);
      } else
        NSLog(@"Failed to query database for trail types!");
      sqlite3_finalize(trailQueryStmt);
    } else
      NSLog(@"Failed to prepare database query for trails!");

    NSMutableDictionary *POI_Icons = [[NSMutableDictionary alloc] init];

    NSString *POITypeQuerySQL =
        [NSString stringWithFormat:@"select id,english_poi_type from poi_type;"];
    sqlite3_stmt *POITypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [POITypeQuerySQL UTF8String], -1, &POITypeQueryStmt, NULL) == SQLITE_OK) {
      while(sqlite3_step(POITypeQueryStmt) == SQLITE_ROW) {
        int type = sqlite3_column_int(POITypeQueryStmt, 0);
        char *name = (char*)sqlite3_column_text(POITypeQueryStmt, 1);
        NSString *iconName = [NSString stringWithFormat:@"%s.png", name];
        iconName = [iconName stringByReplacingOccurrencesOfString:@" " withString:@""];
        //NSLog(@"Icon name: %@, id: %d", iconName, type);
        UIImage *icon = [UIImage imageNamed:iconName];
        [POI_Icons setObject:icon forKey:[NSNumber numberWithInt:type]];
      }
      sqlite3_finalize(POITypeQueryStmt);
    } else {
      NSLog(@"Failed to query database for POI type data!");
    }

    NSString *POIQuerySQL =
        [NSString stringWithFormat:@"select name,type_id,lattitude,longitude,url from map_object,point_of_interest,coordinate where map_object.id=point_of_interest.id and coordinate.map_object_id=map_object.id;"];
    sqlite3_stmt *POIQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [POIQuerySQL UTF8String], -1, &POIQueryStmt, NULL) == SQLITE_OK) {
      while(sqlite3_step(POIQueryStmt) == SQLITE_ROW) {
        char *name = (char*)sqlite3_column_text(POIQueryStmt, 0);
        int type = sqlite3_column_int(POIQueryStmt, 1);
        double lattitude = sqlite3_column_double(POIQueryStmt, 2);
        double longitude = sqlite3_column_double(POIQueryStmt, 3);
        char *url = (char*)sqlite3_column_text(POIQueryStmt, 4);
        //NSLog(@"POI: %s [%d] (%f, %f) - %s", name, type, lattitude, longitude, url);

        CLLocationCoordinate2D pos = CLLocationCoordinate2DMake(lattitude, longitude);
        GMSMarker *marker = [GMSMarker markerWithPosition:pos];
        if (name) marker.title = [NSString stringWithUTF8String:name];
        if (url) marker.snippet = [NSString stringWithUTF8String:url];
        UIImage *icon = [POI_Icons objectForKey:[NSNumber numberWithInt:type]];
        if (icon) marker.icon = icon;
        marker.map = mapView_;

        // FIXME - remove
        /*
        if (strncmp(name, "Little John Parking Lot", 25)==0)
          mapView_.selectedMarker = marker;
        */
      }
      sqlite3_finalize(POIQueryStmt);
    } else
      NSLog(@"Failed to query database for POI data!");
  } else
    NSLog(@"Failed to open database!");
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  mapView_.mapType = self.configModel.mapType;
  [self drawMapObjects];
}

- (UIView*)mapView:(GMSMapView*)mapView
    markerInfoContents:(GMSMarker*)marker
{
  UIView *contents = [[UIView alloc] initWithFrame: CGRectZero];
  UILabel *title_label = [[UILabel alloc] initWithFrame: CGRectZero];
  title_label.text = marker.title;
  [title_label sizeToFit];
  UIButton *moreinfo = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [moreinfo setTitle:@"More info" forState:UIControlStateNormal];
  [moreinfo sizeToFit];
  [moreinfo addTarget:self action:@selector(launchWebView:) forControlEvents:UIControlEventTouchUpInside];
  int numbuttons = 1;
  UIButton *share = 0;
  share = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  if (share) {
    numbuttons++;
    [share setTitle:@"Share" forState:UIControlStateNormal];
    [share sizeToFit];
  }
  int w = title_label.bounds.size.width;
  int h = title_label.bounds.size.height;
  int bw = moreinfo.frame.size.width + share.frame.size.width;
  if (share) bw = bw + share.frame.size.width;
  if (w<bw) w=bw;
  int bh = moreinfo.frame.size.height;
  if ((share) && (bh<share.frame.size.height)) bh=share.frame.size.height;
  if (h<bh) h=bh;
  title_label.frame = CGRectMake(0, 0, w, h);
  moreinfo.frame = CGRectMake(0, h, w/numbuttons, h);
  if (share)
    share.frame = CGRectMake(w/numbuttons, h, w/numbuttons, h);
  contents.frame = CGRectMake(0, 0, w, 2*h);
  [contents addSubview:title_label];
  [contents addSubview:moreinfo];
  if (share)
    [contents addSubview:share];
  return(contents);
}

double markerInfoRiserSize = 10.0f;
double markerInfoRiserPad  =  5.0f;
double markerInfoWidthPad  = 20.0f;
double markerInfoHeightPad = 10.0f;

- (void)moveInfoWindowContentsToMarker:(GMSMarker*)marker {
  UIView *contents = markerInfoContentView_;
  CGPoint mpos = [mapView_.projection pointForCoordinate:[marker position]];
  double offset = markerInfoRiserSize * M_SQRT2;
  contents.center = CGPointMake(mpos.x, mpos.y-marker.icon.size.height-markerInfoRiserPad-(offset/2.0f)-(contents.frame.size.height+markerInfoHeightPad)/2.0f);
}

- (UIView*)mapView:(GMSMapView*)_mapView markerInfoWindow:(GMSMarker*)marker {
  UIView *content = [self mapView:_mapView markerInfoContents:marker];
  markerInfoContentView_ = content;
  [self moveInfoWindowContentsToMarker:marker];
  content.backgroundColor = [UIColor whiteColor];
  [_mapView addSubview:content];
  double content_width = content.frame.size.width;
  double content_height = content.frame.size.height;
  double offset = markerInfoRiserSize * M_SQRT2;
  UIView *contentGhost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, content_width+markerInfoWidthPad, content_height+markerInfoHeightPad)];
  CGAffineTransform rot45deg = CGAffineTransformMakeRotation(M_PI_4);
  UIView *riser = [[UIView alloc] initWithFrame:CGRectMake(((content_width+markerInfoWidthPad-markerInfoRiserSize)/2.0f),
                                                           (content_height+markerInfoHeightPad-(markerInfoRiserSize/2.0f)),
                                                           markerInfoRiserSize, markerInfoRiserSize)];
  UIView *riser_inset = [[UIView alloc] initWithFrame:CGRectInset(riser.frame, 0.5f, 0.5f)];
  riser.transform = rot45deg;
  riser_inset.transform = rot45deg;
  UIView *win = [[UIView alloc] initWithFrame:CGRectMake(0, 0, content_width+markerInfoWidthPad, content_height+markerInfoHeightPad+(offset/2.0f)+markerInfoRiserPad)];
  [win addSubview:riser];
  [win addSubview:contentGhost];
  [win addSubview:riser_inset];
  contentGhost.backgroundColor = [UIColor whiteColor];
  contentGhost.layer.borderColor = [UIColor lightGrayColor].CGColor;
  contentGhost.layer.borderWidth = 1.0f;
  riser.backgroundColor = [UIColor whiteColor];
  riser.layer.borderColor = [UIColor lightGrayColor].CGColor;
  riser.layer.borderWidth = 1.0f;
  riser_inset.backgroundColor = [UIColor whiteColor];
  return(win);
}

- (void)mapView:(GMSMapView*)_mapView didChangeCameraPosition:(GMSCameraPosition*)position {
  if (markerInfoContentView_) {
    if (_mapView.selectedMarker != nil)
      [self moveInfoWindowContentsToMarker:_mapView.selectedMarker];
    else {
      [markerInfoContentView_ removeFromSuperview];
      markerInfoContentView_ = nil;
    }
  }
}

- (void)mapView:(GMSMapView*)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  if (markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }
}

- (BOOL)mapView:(GMSMapView*)mapView didTapMarker:(GMSMarker*)marker {
  if (markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }
  return(NO);
}

/*
- (void)mapView:(GMSMapView*)mapView didTapInfoWindowOfMarker:(GMSMarker*)marker {
  NSLog(@"didTapInfoWindowOfMarker");
}
*/

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
  if (([keyPath isEqualToString:@"mapView.selectedMarker"]) && (!mapView_.selectedMarker) && markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }
}

- (void)launchWebView:(id)sender {
  NSLog(@"launchWebView");
  self.webViewController.url = mapView_.selectedMarker.snippet;
  [self.navigationController pushViewController:self.webViewController animated:YES];
}

- (void)locationManager:(CLLocationManager*)manager
     didUpdateLocations:(NSArray*)locations
{
  CLLocation* location = [locations lastObject];
  NSDate *locDate = location.timestamp;
  NSTimeInterval age = [locDate timeIntervalSinceNow];
  if (abs(age) < 15.0) {
    GMSCameraUpdate *locUpdate = [GMSCameraUpdate setTarget:location.coordinate zoom:17];
    //[mapView_ animateWithCameraUpdate:locUpdate];
  }
  NSLog(@"Got a new location update");
}

- (void)locationManager:(CLLocationManager*)manager
       didFailWithError:(NSError*)error
{
  NSLog(@"Got a location error");
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)dealloc {
  if (mapDataDB_)
    sqlite3_close(mapDataDB_);

  //[mapView_ removeObserver:self
  //              forKeyPath:@"myLocation"
  //                 context:NULL];
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

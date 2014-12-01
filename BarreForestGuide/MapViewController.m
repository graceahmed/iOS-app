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
  BOOL               GPStrackingEnabled;
  BOOL               GPStrackingJustEnabled;
  CLLocation        *barreForestCenter;
  GMSCameraPosition *defaultCamera;
}

@synthesize mapView;

- (void)viewDidLoad {
  NSLog(@"viewDidLoad");
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.

  self.configModel = [ConfigModel getConfigModel];
  self.trailColorUtil = [TrailColorUtil getTrailColorUtil];

  UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  self.webViewController = [sb instantiateViewControllerWithIdentifier:@"POI Detail View"];

  [self initializeLocationManager];

  mapView_ =  [GMSMapView mapWithFrame:mapView.bounds camera:nil];
  CLLocationCoordinate2D defaultCameraNE = CLLocationCoordinate2DMake(44.168,-72.455);
  CLLocationCoordinate2D defaultCameraSW = CLLocationCoordinate2DMake(44.133,-72.494);
  GMSCoordinateBounds *defaultCameraBounds = [[GMSCoordinateBounds alloc] initWithCoordinate:defaultCameraNE coordinate:defaultCameraSW];
  defaultCamera = [ mapView_ cameraForBounds:defaultCameraBounds insets:UIEdgeInsetsZero];
  mapView_.camera = defaultCamera;
  mapView_.settings.compassButton = YES;
  //mapView_.settings.myLocationButton = YES;
  mapView_.mapType = self.configModel.mapType;
  mapView_.padding = UIEdgeInsetsMake(20, 5, 5, 5);

  self.defaultCameraButton.hidden = YES;

  [mapView addSubview:mapView_];
  mapView_.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
  NSLog(@"viewWillAppear: animated=%d\n", animated);
  [self.navigationController setNavigationBarHidden:YES animated:animated];
  [super viewWillAppear:animated];
  mapView_.settings.compassButton = YES;
  mapView_.mapType = self.configModel.mapType;
  [self startStopLocationUpdates];
  [self drawMapObjects];
}

- (void)viewWillDisappear:(BOOL)animated {
  NSLog(@"viewWillDisappear: animated=%d\n", animated);
  [self.navigationController setNavigationBarHidden:NO animated:animated];
  [super viewWillDisappear:animated];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  //NSLog(@"viewWillTransitionToSize: size=(%f,%f)",size.width,size.height);
  mapView_.frame = CGRectMake(0, 0, size.width, size.height);
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
        [NSString stringWithFormat:@"select map_object_id,latitude,longitude from trail,coordinate " \
                                    "where coordinate.map_object_id=trail.id and %s_uses_id=? order by map_object_id,seq;", season];
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
          CGFloat  trail_type_width = [self.trailColorUtil getTrailTypeWidth:trail_type_id];
          //if (trail_type_color) NSLog(@"got color %@ for trail_type_id %d", trail_type_color, trail_type_id); // FIXME - remove
          //if (trail_type_color==nil) trail_type_color = [UIColor redColor];
          sqlite3_reset(trailQueryStmt);
          sqlite3_bind_int(trailQueryStmt, 1, trail_type_id);
          GMSMutablePath *trailpath = nil;
          int prev_trail_id = -1;
          while(sqlite3_step(trailQueryStmt) == SQLITE_ROW) {
            int trail_id = sqlite3_column_int(trailQueryStmt, 0);
            double latitude = sqlite3_column_double(trailQueryStmt, 1);
            double longitude = sqlite3_column_double(trailQueryStmt, 2);
            //NSLog(@"trail_id %d (%f, %f)", trail_id, latitude, longitude);
            if (prev_trail_id != trail_id) {
              if (trailpath && ([trailpath count]>1)) {
                GMSPolyline *trailpoly = [GMSPolyline polylineWithPath:trailpath];
                trailpoly.strokeColor = trail_type_color;
                trailpoly.strokeWidth = trail_type_width;
                trailpoly.map = mapView_;
                //NSLog(@"Putting Polyline on the map");
              }
              trailpath = [GMSMutablePath path];
              prev_trail_id = trail_id;
            }
            [trailpath addCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];
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

    NSString *enabledPOITypeIds = nil;
    NSString *POITypeQuerySQL =
        [NSString stringWithFormat:@"select id,english_poi_type from poi_type;"];
    sqlite3_stmt *POITypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [POITypeQuerySQL UTF8String], -1, &POITypeQueryStmt, NULL) == SQLITE_OK) {
      while(sqlite3_step(POITypeQueryStmt) == SQLITE_ROW) {
        int type = sqlite3_column_int(POITypeQueryStmt, 0);
        char *name = (char*)sqlite3_column_text(POITypeQueryStmt, 1);
        NSString *iconName = [NSString stringWithFormat:@"%s.png", name];
        NSNumber *type_num = [NSNumber numberWithInt:type];
        iconName = [iconName stringByReplacingOccurrencesOfString:@" " withString:@""];
        //NSLog(@"Icon name: %@, id: %d", iconName, type);
        UIImage *icon = [UIImage imageNamed:iconName];
        if (icon) [POI_Icons setObject:icon forKey:type_num];
        if ([[self.configModel.poiTypeEnabled objectForKey:type_num] boolValue]) {
          if (!enabledPOITypeIds)
            enabledPOITypeIds = [NSString stringWithFormat:@"%d", type];
          else
            enabledPOITypeIds = [enabledPOITypeIds stringByAppendingFormat:@",%d", type];
        }
      }
      sqlite3_finalize(POITypeQueryStmt);
    } else {
      NSLog(@"Failed to query database for POI type data!");
    }

    NSString *POIQuerySQL =
        [NSString stringWithFormat:@"select name,type_id,latitude,longitude,url from map_object,point_of_interest,coordinate where map_object.id=point_of_interest.id and coordinate.map_object_id=map_object.id and type_id in (%@);", enabledPOITypeIds];
    sqlite3_stmt *POIQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [POIQuerySQL UTF8String], -1, &POIQueryStmt, NULL) == SQLITE_OK) {
      while(sqlite3_step(POIQueryStmt) == SQLITE_ROW) {
        char *name = (char*)sqlite3_column_text(POIQueryStmt, 0);
        int type = sqlite3_column_int(POIQueryStmt, 1);
        double latitude = sqlite3_column_double(POIQueryStmt, 2);
        double longitude = sqlite3_column_double(POIQueryStmt, 3);
        char *url = (char*)sqlite3_column_text(POIQueryStmt, 4);
        //NSLog(@"POI: %s [%d] (%f, %f) - %s", name, type, latitude, longitude, url);

        CLLocationCoordinate2D pos = CLLocationCoordinate2DMake(latitude, longitude);
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

    NSString *discGolfQuerySQL =
        [NSString stringWithFormat:@"select map_object_id,hole,latitude,longitude from disc_golf_hole,coordinate " \
                                    "where coordinate.map_object_id=disc_golf_hole.id order by map_object_id,seq;"];
    sqlite3_stmt *discGolfQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [discGolfQuerySQL UTF8String], -1, &discGolfQueryStmt, NULL) == SQLITE_OK) {
      UIImage *tee_icon;
      UIImage *basket_icon;
      if (self.configModel.discGolfEnabled) {
        tee_icon = [UIImage imageNamed:@"DiscGolfTee.png"];
        basket_icon = [UIImage imageNamed:@"DiscGolfBasket.png"];
      }
      UIColor *hole_polyline_color = [self.trailColorUtil getDiscGolfPathColor];
      CGFloat  hole_polyline_width = [self.trailColorUtil getDiscGolfPathWidth];
      GMSMutablePath *hole_path = nil;
      int prev_hole_id = -1;
      int prev_hole_num = -1;
      while(sqlite3_step(discGolfQueryStmt) == SQLITE_ROW) {
        int hole_id = sqlite3_column_int(discGolfQueryStmt, 0);
        int hole_num = sqlite3_column_int(discGolfQueryStmt, 1);
        double latitude = sqlite3_column_double(discGolfQueryStmt, 2);
        double longitude = sqlite3_column_double(discGolfQueryStmt, 3);
        //NSLog(@"hole_id %d (hole %d) (%f, %f)", hole_id, hole_num, latitude, longitude);
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latitude, longitude);
        if (prev_hole_id != hole_id) {
          if (hole_path && ([hole_path count]>1)) {
            GMSPolyline *hole_poly = [GMSPolyline polylineWithPath:hole_path];
            hole_poly.strokeColor = hole_polyline_color;
            hole_poly.strokeWidth = hole_polyline_width;
            hole_poly.map = mapView_;

            if (self.configModel.discGolfIconsEnabled) {
              CLLocationCoordinate2D basketCoord = [hole_path coordinateAtIndex:([hole_path count]-1)];
              GMSMarker *basketMarker = [GMSMarker markerWithPosition:basketCoord];
              basketMarker.title = [NSString stringWithFormat:@"Disc Golf Hole %d Basket", prev_hole_num];
              basketMarker.icon = basket_icon;
              basketMarker.map = mapView_;
            }
          }
          hole_path = [GMSMutablePath path];
          prev_hole_id = hole_id;
          prev_hole_num = hole_num;

          if (self.configModel.discGolfIconsEnabled) {
            GMSMarker *basketTee = [GMSMarker markerWithPosition:coord];
            basketTee.title = [NSString stringWithFormat:@"Disc Golf Hole %d Tee", hole_num];
            basketTee.icon = tee_icon;
            basketTee.map = mapView_;
          }
        }
        [hole_path addCoordinate:coord];
      }
      if (hole_path && ([hole_path count]>1)) {
        GMSPolyline *hole_poly = [GMSPolyline polylineWithPath:hole_path];
        hole_poly.strokeColor = hole_polyline_color;
        hole_poly.map = mapView_;
      }
      sqlite3_finalize(discGolfQueryStmt);
    } else
      NSLog(@"Failed to prepare database query for disc golf holes!");

  } else
    NSLog(@"Failed to open database!");
}

- (UIView*)mapView:(GMSMapView*)mapView
    markerInfoContents:(GMSMarker*)marker
{
  UIView *contents = [[UIView alloc] initWithFrame: CGRectZero];
  UILabel *title_label = [[UILabel alloc] initWithFrame: CGRectZero];
  title_label.text = marker.title;
  title_label.textAlignment = NSTextAlignmentCenter;
  [title_label sizeToFit];
  NSArray *button_names = @[ @"More info", @"Share" ];
  NSDictionary *button_specs = @{
    @"More info" : @[ ^{return(marker.snippet!=nil);},             @"launchWebView:" ],
    @"Share"     : @[ ^{return(self.configModel.sharingEnabled);}, @"launchShare:"   ],
  };
  NSMutableArray *buttons = [[NSMutableArray alloc] init];
  for(NSString *name in button_names) {
    BOOL(^pred)(void) = button_specs[name][0];
    NSString *sel  = button_specs[name][1];
    if (pred()) {
      UIButton *btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
      [btn setTitle:name forState:UIControlStateNormal];
      [btn addTarget:self action:NSSelectorFromString(sel) forControlEvents:UIControlEventTouchUpInside];
      [buttons addObject:btn];
    }
  }
  int numbuttons = [buttons count];
  int tlw = title_label.bounds.size.width;
  int tlh = title_label.bounds.size.height;
  int cbw = 0; // Cumulative button widths
  int mbw = 0; // Maximum button width
  int mbh = 0; // Maximum button height
  for(UIButton *btn in buttons) {
    [btn sizeToFit];
    btn.frame = CGRectInset(btn.frame, -5.0f, 0);
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    int bw = btn.frame.size.width;
    int bh = btn.frame.size.height;
    cbw = cbw + bw;
    if (mbw<bw) mbw=bw;
    if (mbh<bh) mbh=bh;
  }
  int w = tlw;
  int h = tlh;
  if (w<cbw) w=cbw;
  if (h<mbh) h=mbh;
  title_label.frame = CGRectMake(0, 0, w, h);
  int offset = 0;
  for(UIButton *btn in buttons) {
    int btnw = btn.frame.size.width;
    int btnh = btn.frame.size.height;
    // If the label text is wider than all of the buttons, if they all are
    //   allocated the maximum button width, do that
    if (tlw > (mbw*numbuttons)) btnw = tlw/numbuttons;
    else if (tlw > cbw) btnw = btnw + (tlw-cbw)*(mbw-btnw)/((mbw*numbuttons)-cbw);
    btn.frame = CGRectMake(offset, h, btnw, btnh);
    offset += btnw;
  }
  if (numbuttons>0) h=2*h;
  contents.frame = CGRectMake(0, 0, w, h);
  [contents addSubview:title_label];
  for(UIButton *btn in buttons) [contents addSubview:btn];
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

- (void)mapView:(GMSMapView*)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  //NSLog(@"didTapAtCoordinate: (%f, %f)", coordinate.latitude, coordinate.longitude);
  if (markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }
}

- (BOOL)mapView:(GMSMapView*)mapView didTapMarker:(GMSMarker*)marker {
  //NSLog(@"didTapMarker: %@", marker);
  if (markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }
  return(NO);
}

/*
- (void)mapView:(GMSMapView*)mapView didTapInfoWindowOfMarker:(GMSMarker*)marker {
  //NSLog(@"didTapInfoWindowOfMarker");
}
*/

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
  if (([keyPath isEqualToString:@"mapView.selectedMarker"]) && (!mapView_.selectedMarker) && markerInfoContentView_) {
    [markerInfoContentView_ removeFromSuperview];
    markerInfoContentView_ = nil;
  }
}

- (void)launchWebView:(id)sender {
  //NSLog(@"launchWebView");
  self.webViewController.url = mapView_.selectedMarker.snippet;
  [self.navigationController pushViewController:self.webViewController animated:YES];
}

- (void)launchShare:(id)sender {
  NSLog(@"launchShare");
}

- (void)initializeLocationManager {
  GPStrackingEnabled = NO;
  if ([CLLocationManager locationServicesEnabled]) {
    if (locationManager_ == nil)
      locationManager_ = [[CLLocationManager alloc] init];
    locationManager_.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager_.distanceFilter = 1;
    locationManager_.delegate = self;
    if ([locationManager_ respondsToSelector:@selector(requestWhenInUseAuthorization)])
      [locationManager_ requestWhenInUseAuthorization];
    barreForestCenter = [[CLLocation alloc] initWithLatitude:44.15 longitude:-72.48];
  }
}

- (void)startStopLocationUpdates {
  if (locationManager_==nil) return;
  if ((self.configModel.mapTracksGPS)) {
    if (!GPStrackingEnabled) {
      [locationManager_ startUpdatingLocation];
      GPStrackingEnabled = YES;
      GPStrackingJustEnabled = YES;
    }
  } else {
    if (GPStrackingEnabled) {
      [locationManager_ stopUpdatingLocation];
      GPStrackingEnabled = NO;
    }
  }
}

- (void)mapView:(GMSMapView*)_mapView willMove:(BOOL)gesture {
  //NSLog(@"willMove: gesture=%d", gesture);
  if (gesture) {
    [locationManager_ stopUpdatingLocation];
    GPStrackingEnabled = NO;
  }
  self.myLocation.hidden = GPStrackingEnabled;
}

- (void)mapView:(GMSMapView*)_mapView didChangeCameraPosition:(GMSCameraPosition*)position {
  //NSLog(@"didChangeCameraPosition: %@", position);
  if (markerInfoContentView_) {
    if (_mapView.selectedMarker != nil)
      [self moveInfoWindowContentsToMarker:_mapView.selectedMarker];
    else {
      [markerInfoContentView_ removeFromSuperview];
      markerInfoContentView_ = nil;
    }
  }
  CLLocation *campos = [[CLLocation alloc] initWithLatitude:position.target.latitude longitude:position.target.longitude];
  self.defaultCameraButton.hidden = ([barreForestCenter distanceFromLocation:campos] < 2000);
  //NSLog(@"camera distance from barreForestCenter: %f", [barreForestCenter distanceFromLocation:campos]);
}

- (void)locationManager:(CLLocationManager*)manager
     didUpdateLocations:(NSArray*)locations
{
  CLLocation* location = [locations lastObject];
  NSDate *locDate = location.timestamp;
  NSTimeInterval age = [locDate timeIntervalSinceNow];
  //NSLog(@"didUpdateLocations: age=%f", age);
  if (abs(age) < 15.0) {
    GMSCameraUpdate *locUpdate;
    if (GPStrackingJustEnabled) {
      locUpdate = [GMSCameraUpdate setTarget:location.coordinate zoom:17];
      GPStrackingJustEnabled = NO;
    } else
      locUpdate = [GMSCameraUpdate setTarget:location.coordinate];
    [mapView_ animateWithCameraUpdate:locUpdate];
    [self startStopLocationUpdates];
  }
}

- (void)locationManager:(CLLocationManager*)manager
       didFailWithError:(NSError*)error
{
  NSLog(@"Got a location error: %@", error);
}

- (BOOL)didTapMyLocationButtonForMapView:(GMSMapView*)mapView {
  NSLog(@"didTapMyLocationButtonForMapView");
  [self didTapMyLocation];
  return YES;
}

- (IBAction)didTapMyLocation {
  NSLog(@"didTapMyLocation");
  [locationManager_ startUpdatingLocation];
  GPStrackingEnabled = YES;
  GPStrackingJustEnabled = !self.configModel.mapTracksGPS;
}

- (IBAction)didTapDefaultCamera {
  NSLog(@"didTapDefaultCamera");
  [mapView_ animateToCameraPosition:defaultCamera];
  [locationManager_ stopUpdatingLocation];
  GPStrackingEnabled = NO;
  self.myLocation.hidden = NO;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)dealloc {
  if (mapDataDB_)
    sqlite3_close(mapDataDB_);
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

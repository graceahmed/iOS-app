//
//  MapViewController.h
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 10/20/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <GoogleMaps/GoogleMaps.h>
#import "ConfigModel.h"
#import "TrailColorUtil.h"
#import "WebKitViewController.h"

@interface MapViewController : UIViewController
                                 <CLLocationManagerDelegate,
                                  GMSMapViewDelegate>

@property (nonatomic, weak) IBOutlet UIView               *mapView;
@property (nonatomic, weak) IBOutlet UIButton             *myLocation;
@property (nonatomic, weak) IBOutlet UIButton             *defaultCameraButton;
@property                            WebKitViewController *webViewController;
@property                            ConfigModel          *configModel;
@property                            TrailColorUtil       *trailColorUtil;

- (IBAction)didTapMyLocation;
- (IBAction)didTapDefaultCamera;

- (void)initializeLocationManager;
- (void)startStopLocationUpdates;
- (void)drawMapObjects;
- (void)launchWebView:(id)sender;
- (void)tapHandler:(UITapGestureRecognizer*)recognizer;

@end

/* vim: set ai si sw=2 ts=80 ru: */

//
//  WebKitViewController.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/21/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "WebKitViewController.h"

@interface WebKitViewController ()
@end

@implementation WebKitViewController {}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.webKit.delegate = self;
  //NSLog(@"self.view.frame=(%f,%f,%f,%f)",self.view.frame.origin.x,self.view.frame.origin.y,self.view.frame.size.width,self.view.frame.size.height);
  //NSLog(@"webKit.frame=(%f,%f,%f,%f)",self.webKit.frame.origin.x,self.webKit.frame.origin.y,self.webKit.frame.size.width,self.webKit.frame.size.height);
  self.webKit.frame = self.view.frame;
  self.webKit.scalesPageToFit = YES;
}

- (void)viewWillAppear:(BOOL)animated {
  if (self.url) {
    NSLog(@"viewWillAppear: loadRequest(%@)", self.url);
    [self.webKit loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.url]]];
  }
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  //NSLog(@"viewWillTransitionToSize: size=(%f,%f)",size.width,size.height);
}

- (void)webViewDidFinishLoad:(UIWebView*)webview
{
  CGSize contentSize = webview.scrollView.contentSize;
  CGSize viewSize = self.view.bounds.size;

  float rw = viewSize.width / contentSize.width;

  //NSLog(@"webViewDidFinishLoad: contentSize=(%f,%f), viewSize=(%f,%f), rw=%f", contentSize.width, contentSize.height, viewSize.width, viewSize.height, rw);

  webview.scrollView.minimumZoomScale = rw;
  webview.scrollView.zoomScale = rw;
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

//
//  WebKitViewController.h
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/21/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebKitViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, weak) IBOutlet UIWebView *webKit;
@property NSString *url;

@end

/* vim: set ai si sw=2 ts=80 ru: */

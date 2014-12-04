//
//  MenuViewController.m
//  BarreForestGuide
//
//  Created by Grace Ahmed on 11/26/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "MenuViewController.h"

@interface MenuViewController ()
@end

@implementation MenuViewController {}


- (IBAction)phoneCall {
    NSLog(@"Initiating phone call...");
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"telprompt://8024799331"]];
}

@end

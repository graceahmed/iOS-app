//
//  TrailColorUtil.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/23/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "TrailColorUtil.h"

@implementation TrailColorUtil

- (id) init {
  if (self = [super init]) {
    self.configModel = [ConfigModel getConfigModel];
    self.trailTypeColor = [[NSMutableDictionary alloc] init];
  }
  return(self);
}

+ (TrailColorUtil*)getTrailColorUtil {
  static TrailColorUtil *singleton = nil;
  static dispatch_once_t gate;
  dispatch_once(&gate, ^{ singleton = [[TrailColorUtil alloc] init]; });
  return(singleton);
}

- (void)invalidateColorCache {
  self.trailTypeColor = [[NSMutableDictionary alloc] init];
}

- (UIColor*)getTrailTypeColor:(int)trailTypeID {
  NSNumber *ttid = [NSNumber numberWithInt:trailTypeID];
  UIColor *color = [self.trailTypeColor objectForKey:ttid];
  if (color==nil) {
    BOOL enabled = [[self.configModel.trailTypeEnabled objectForKey:ttid] boolValue];
    if (!enabled) {
      color = [UIColor colorWithWhite:0.75f alpha:0.5f];
    } else {
      color = [UIColor redColor];
    }
    [self.trailTypeColor setObject:color forKey:ttid];
  }
  return(color);
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

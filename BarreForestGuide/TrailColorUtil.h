//
//  TrailColorUtil.h
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/23/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConfigModel.h"

@interface TrailColorUtil : NSObject

@property ConfigModel          *configModel;
@property NSMutableDictionary  *trailTypeColor;

+ (TrailColorUtil*)getTrailColorUtil;
- (void)invalidateColorCache;

- (UIColor*)getTrailTypeColor:(int)trailTypeID;

@end

/* vim: set ai si sw=2 ts=80 ru: */

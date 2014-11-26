//
//  FilterViewController.h
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/26/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConfigModel.h"
#import "TrailColorUtil.h"

@interface FilterViewController : UITableViewController
                                    <UITableViewDelegate, UITableViewDataSource>

@property                            ConfigModel     *configModel;
@property                            TrailColorUtil  *trailColorUtil;

@end

/* vim: set ai si sw=2 ts=80 ru: */

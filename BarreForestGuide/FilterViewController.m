//
//  FilterViewController.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/26/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "FilterViewController.h"

@interface FilterViewController ()
@end

@implementation FilterViewController {
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.configModel = [ConfigModel getConfigModel];
  self.trailColorUtil = [TrailColorUtil getTrailColorUtil];

  UITableView *tableView = (UITableView*)self.view;
  tableView.delegate = self;
  tableView.dataSource = self;

  if (self.configModel.trailTypeEnabled==nil)
    self.configModel.trailTypeEnabled = [[NSMutableDictionary alloc] init];

  // FIXME - remove
  //[self.configModel.trailTypeEnabled setObject:@1 forKey:@1];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  //self.configModel.mapTracksGPS = [self.autoFollowGPS isOn];
  [self.trailColorUtil invalidateColorCache];
  [self.configModel saveToDefaults];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return(2);
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  return(3);
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
  NSArray *title = @[ @"POI Type Filters", @"Trail Type Filters" ];
  return(title[section]);
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *MyIdentifier = @"FilterItem";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];

  NSUInteger section = [indexPath section];
  NSUInteger row = [indexPath row];

  char *ftype[] = { "POI", "Trail" };

  cell.textLabel.text = [NSString stringWithFormat:@"%s Filter Label %d", ftype[section], row];
  if (row==0)
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
  else
    cell.accessoryType = UITableViewCellAccessoryNone;

  return cell;
}

- (void)tableView:(UITableView*)tableView
        didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  NSUInteger section = [indexPath section];
  NSUInteger row = [indexPath row];

/*
  switch (section) {
    case 0:
      currentMapTypeRow = row;
      self.configModel.mapType = rowToMapType(row);
      break;
    case 1:
      currentSeasonRow = row;
      self.configModel.mapSeason = rowToSeason(row);
      break;
    default: break;
  }

  */
  [self.tableView reloadData];
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

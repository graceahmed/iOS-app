//
//  SettingsViewController.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/20/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "SettingsViewController.h"

@interface SettingsViewController ()
@end

@implementation SettingsViewController {
  int currentMapTypeRow;
}

int mapTypeToRow(GMSMapViewType mapType) {
  switch (mapType) {
    case kGMSTypeNormal:    return(0);  break;
    case kGMSTypeSatellite: return(1);  break;
    case kGMSTypeTerrain:   return(2);  break;
    default:                return(-1); break;
  }
}

GMSMapViewType rowToMapType(int row) {
  switch (row) {
    case 0:  return(kGMSTypeNormal);    break;
    case 1:  return(kGMSTypeSatellite); break;
    case 2:  return(kGMSTypeTerrain);   break;
    default: return(kGMSTypeNormal);    break;
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.configModel = [ConfigModel getConfigModel];
  self.trailColorUtil = [TrailColorUtil getTrailColorUtil];
  currentMapTypeRow = mapTypeToRow(self.configModel.mapType);
  [self.autoFollowGPS setOn:self.configModel.mapTracksGPS animated:NO];

  // FIXME - remove
  self.configModel.mapSeason = summer_map_season;
  if (self.configModel.trailTypeEnabled==nil)
    self.configModel.trailTypeEnabled = [[NSMutableDictionary alloc] init];
  [self.configModel.trailTypeEnabled setObject:@1 forKey:@1];
  [self.configModel.trailTypeEnabled setObject:@1 forKey:@6];
  [self.trailColorUtil invalidateColorCache];
  self.configModel.sharingEnabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  self.configModel.mapTracksGPS = [self.autoFollowGPS isOn];
  [self.configModel saveToDefaults];
}

- (UITableViewCell*)tableView:(UITableView*)tableView 
        cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
  UITableViewCell *cell = [super tableView:tableView
                           cellForRowAtIndexPath:indexPath];

  NSUInteger section = [indexPath section];
  NSUInteger row = [indexPath row];

  if (section==0) {
    if (row==currentMapTypeRow)
      cell.accessoryType = UITableViewCellAccessoryCheckmark;
    else
      cell.accessoryType = UITableViewCellAccessoryNone;
  }

  return cell;
}

- (void)tableView:(UITableView*)tableView
        didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  NSUInteger section = [indexPath section];
  NSUInteger row = [indexPath row];

  if (section==0) {
    currentMapTypeRow = row;
    self.configModel.mapType = rowToMapType(row);
  }

  [self.tableView reloadData];
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

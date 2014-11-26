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
  int currentSeasonRow;
}

int mapTypeToRow(GMSMapViewType mapType) {
  switch (mapType) {
    case kGMSTypeNormal:    return(0);  break;
    case kGMSTypeTerrain:   return(1);  break;
    case kGMSTypeSatellite: return(2);  break;
    case kGMSTypeHybrid:    return(3);  break;
    default:                return(-1); break;
  }
}

GMSMapViewType rowToMapType(int row) {
  switch (row) {
    case 0:  return(kGMSTypeNormal);    break;
    case 1:  return(kGMSTypeTerrain);   break;
    case 2:  return(kGMSTypeSatellite); break;
    case 3:  return(kGMSTypeHybrid);    break;
    default: return(kGMSTypeNormal);    break;
  }
}

int seasonToRow(map_season_t season) {
  switch (season) {
    case auto_map_season:   return(0);  break;
    case summer_map_season: return(1);  break;
    case winter_map_season: return(2);  break;
    default:                return(-1); break;
  }
}

map_season_t rowToSeason(int row) {
  switch (row) {
    case 0:  return(auto_map_season);   break;
    case 1:  return(summer_map_season); break;
    case 2:  return(winter_map_season); break;
    default: return(auto_map_season);   break;
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.configModel = [ConfigModel getConfigModel];
  self.trailColorUtil = [TrailColorUtil getTrailColorUtil];
  currentMapTypeRow = mapTypeToRow(self.configModel.mapType);
  currentSeasonRow = seasonToRow(self.configModel.mapSeason);
  [self.autoFollowGPS setOn:self.configModel.mapTracksGPS animated:NO];

  // FIXME - remove
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

  switch (section) {
    case 0:
      if (row==currentMapTypeRow)
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      else
        cell.accessoryType = UITableViewCellAccessoryNone;
      break;
    case 1:
      if (row==currentSeasonRow)
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      else
        cell.accessoryType = UITableViewCellAccessoryNone;
      break;
    default: break;
  }

  return cell;
}

- (void)tableView:(UITableView*)tableView
        didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  NSUInteger section = [indexPath section];
  NSUInteger row = [indexPath row];

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

  [self.tableView reloadData];
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

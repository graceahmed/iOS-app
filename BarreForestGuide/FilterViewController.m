//
//  FilterViewController.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/26/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "FilterViewController.h"
#import <sqlite3.h>

@interface FilterViewController ()
@end

@implementation FilterViewController {
  NSMutableDictionary *trailTypeIdToName;
  NSArray             *trailTypeIds;

  NSMutableDictionary *poiTypeIdToName;
  NSMutableArray      *poiTypeIds;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.configModel = [ConfigModel getConfigModel];
  self.trailColorUtil = [TrailColorUtil getTrailColorUtil];

  [self queryDatabaseForTypeNames];

  UITableView *tableView = (UITableView*)self.view;
  tableView.delegate = self;
  tableView.dataSource = self;

  // FIXME - remove
  //[self.configModel.trailTypeEnabled setObject:@1 forKey:@1];
}

- (void)queryDatabaseForTypeNames {
  sqlite3      *mapDataDB_;

  char *season = [self.configModel isSummerMapSeason] ? "summer" : "winter";

  NSString *mapDataDBName_ = [[NSBundle mainBundle]
                              pathForResource:@"BarreForestGuide"
                                       ofType:@"sqlite"];
  if (sqlite3_open([mapDataDBName_ UTF8String], &mapDataDB_) == SQLITE_OK) {

    NSString *trailTypeQuerySQL =
        [NSString stringWithFormat:@"select trail_uses.id,english_uses from trail_uses,trail where trail.%s_uses_id=trail_uses.id group by trail_uses.id;", season];
    sqlite3_stmt *trailTypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [trailTypeQuerySQL UTF8String], -1, &trailTypeQueryStmt, NULL) == SQLITE_OK) {
      NSMutableArray *trailTypeIdsMut = [[NSMutableArray alloc] init];
      trailTypeIdToName = [[NSMutableDictionary alloc] init];
      while(sqlite3_step(trailTypeQueryStmt) == SQLITE_ROW) {
        int trail_type_id = sqlite3_column_int(trailTypeQueryStmt, 0);
        char *trail_type_name = (char*)sqlite3_column_text(trailTypeQueryStmt, 1);
        NSLog(@"trail_type_id %d : %s", trail_type_id, trail_type_name);
        if ((![self.trailColorUtil isTrailTypeIdSpan:trail_type_id]) &&
            (![self.trailColorUtil isTrailTypeIdOther:trail_type_id]))
        {
          NSNumber *trail_type_id_num = [NSNumber numberWithInt:trail_type_id];
          NSString *trail_type_name_str =
            [self.trailColorUtil
              getTrailTypeRename:[NSString
                                    stringWithUTF8String:trail_type_name]];
          [trailTypeIdToName setObject:trail_type_name_str forKey:trail_type_id_num];
          [trailTypeIdsMut addObject:trail_type_id_num];
        }
      }
      sqlite3_finalize(trailTypeQueryStmt);
      NSNumber *other_type_id_num = [NSNumber numberWithInt:[self.trailColorUtil getTrailTypeOtherId]];
      [trailTypeIdToName setObject:@"Other" forKey:other_type_id_num];
      [trailTypeIdsMut addObject:other_type_id_num];
      trailTypeIds = [trailTypeIdsMut
                        sortedArrayUsingComparator: ^(id obj1, id obj2) {
                          int ord1 = [self.trailColorUtil getTrailTypeSortOrder:[obj1 intValue]];
                          int ord2 = [self.trailColorUtil getTrailTypeSortOrder:[obj2 intValue]];
                          if      (ord1<ord2) return(NSOrderedAscending);
                          else if (ord1>ord2) return(NSOrderedDescending);
                          else                return(NSOrderedSame);
                        } ];
    } else
      NSLog(@"Failed to query database for trail types!");

    NSString *POITypeQuerySQL =
        [NSString stringWithFormat:@"select id,english_poi_type from poi_type order by id;"];
    sqlite3_stmt *POITypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [POITypeQuerySQL UTF8String], -1, &POITypeQueryStmt, NULL) == SQLITE_OK) {
      NSMutableArray *poiTypeIdsMut = [[NSMutableArray alloc] init];
      poiTypeIdToName = [[NSMutableDictionary alloc] init];
      while(sqlite3_step(POITypeQueryStmt) == SQLITE_ROW) {
        int poi_type_id = sqlite3_column_int(POITypeQueryStmt, 0);
        char *poi_type_name = (char*)sqlite3_column_text(POITypeQueryStmt, 1);
        NSLog(@"poi_type_id %d : %s", poi_type_id, poi_type_name);
        NSNumber *poi_type_id_num = [NSNumber numberWithInt:poi_type_id];
        NSString *poi_type_name_str = [NSString stringWithUTF8String:poi_type_name];
        [poiTypeIdToName setObject:poi_type_name_str forKey:poi_type_id_num];
        [poiTypeIdsMut addObject:poi_type_id_num];
      }
      sqlite3_finalize(POITypeQueryStmt);
      poiTypeIds = [poiTypeIdsMut
                      sortedArrayUsingComparator: ^(id obj1, id obj2) {
                        int ord1 = [self.trailColorUtil getPoiTypeSortOrder:[obj1 intValue]];
                        int ord2 = [self.trailColorUtil getPoiTypeSortOrder:[obj2 intValue]];
                        if      (ord1<ord2) return(NSOrderedAscending);
                        else if (ord1>ord2) return(NSOrderedDescending);
                        else                return(NSOrderedSame);
                      } ];
    } else
      NSLog(@"Failed to query database for POI type data!");
  } else
    NSLog(@"Failed to open database!");
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  //self.configModel.mapTracksGPS = [self.autoFollowGPS isOn];
  [self.trailColorUtil invalidateColorCache];
  [self.configModel saveToDefaults];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return(3);
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  int rv=0;
  switch(section) {
    case 0: rv = [  poiTypeIds count]; break;
    case 1: rv = [trailTypeIds count]; break;
    case 2: rv = 1;                    break;
    default:                           break;
  }
  return(rv);
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
  NSArray *title = @[ @"POI Type Filters", @"Trail Type Filters", @"Disc Golf Filter" ];
  return(title[section]);
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *MyIdentifier = @"FilterItem";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];

  NSUInteger section = [indexPath section];
  NSUInteger row = [indexPath row];

  BOOL enabled = false;

  switch (section) {
    case 0:
      cell.textLabel.text = poiTypeIdToName[poiTypeIds[row]];
      enabled = [self.configModel.poiTypeEnabled[poiTypeIds[row]] boolValue];
      break;
    case 1:
      cell.textLabel.text = trailTypeIdToName[trailTypeIds[row]];
      enabled = [self.configModel.trailTypeEnabled[trailTypeIds[row]] boolValue];
      break;
    case 2:
      cell.textLabel.text = @"Disc Golf Holes";
      enabled = self.configModel.discGolfEnabled;
      break;
    default: break;
  }
  if (enabled)
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

  switch (section) {
    case 0:
      [self.trailColorUtil togglePoiTypeIdEnable:[poiTypeIds[row] intValue]];
      break;
    case 1:
      [self.trailColorUtil toggleTrailTypeIdEnable:[trailTypeIds[row] intValue]];
      break;
    case 2:
      self.configModel.discGolfEnabled = !self.configModel.discGolfEnabled;
      break;
    default: break;
  }

  [self.tableView reloadData];
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

//
//  TrailColorUtil.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/23/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "TrailColorUtil.h"
#import <sqlite3.h>

@implementation TrailColorUtil {
  NSDictionary *trailTypeNameToId;
  NSDictionary *poiTypeNameToId;

  int           maxTrailTypeId;
  int           maxPoiTypeId;

  int          *trailTypeIdSortOrder;
  int          *trailTypeIdToDifficultyGroup;
  int          *trailTypeIdToSpanId;
  int          *trailTypeIdIsSpan;

  int          *poiTypeIdSortOrder;
}

/*
 * Things I want to query from this object
 *   From MapViewController
 *    - Color for Trail Type ID
 *   From FilterViewController
 *    - Ordering of trail type IDs (-1 means type ID is a span)
 *    - Enable/Disable trail type ID
 *    - Enable/Disable trail difficulty group
 *
 *    - Ordering of POI type IDs
 *    - Enable/Disable of POI type ID
 */

- (id) init {
  if (self = [super init]) {
    self.configModel = [ConfigModel getConfigModel];
    self.trailTypeColor = [[NSMutableDictionary alloc] init];

    if (self.configModel.trailTypeEnabled==nil)
      self.configModel.trailTypeEnabled = [[NSMutableDictionary alloc] init];
    if (self.configModel.poiTypeEnabled==nil)
      self.configModel.poiTypeEnabled = [[NSMutableDictionary alloc] init];

    maxTrailTypeId = -1;
    maxPoiTypeId = -1;
    [self queryDatabaseForTypeNames];

    trailTypeIdSortOrder         = (int*)calloc(maxTrailTypeId+1, sizeof(int));
    trailTypeIdToDifficultyGroup = (int*)calloc(maxTrailTypeId+1, sizeof(int));
    trailTypeIdToSpanId          = (int*)calloc(maxTrailTypeId+1, sizeof(int));
    trailTypeIdIsSpan            = (int*)calloc(maxTrailTypeId+1, sizeof(int));

    poiTypeIdSortOrder           = (int*)calloc(maxPoiTypeId+1, sizeof(int));

    NSArray *t_grps = @[ @[ @"Easy", @"Walking", @"Shoe" ],
                         @[ @"Moderate", @"BikePath", @"Ski" ],
                         @[ @"Hard", @"Motor" ],
                         @[ @"PvtRd" ],
                         @[ @"Extreme", @"Unmaintained" ] ];
    NSDictionary *t_spans = @{ @"SkiShoe":      @[ @"Ski", @"Shoe" ],
                               @"MotorSkiShoe": @[ @"Motor", @"Ski", @"Shoe" ] };
    NSArray *t_poi = @[ @"Overlook", @"Parking Lot", @"Store" ];

    for(int i=0; i<=maxTrailTypeId; i++) {
      trailTypeIdSortOrder[i] = maxTrailTypeId+1;
      trailTypeIdToDifficultyGroup[i] = -1;
      trailTypeIdToSpanId[i] = -1;
    }
    for(int i=0; i<=maxPoiTypeId; i++) {
      poiTypeIdSortOrder[i] = maxPoiTypeId+1;
    }

    int order = 0;
    int groupnum = 0;
    for(NSArray *grp in t_grps) {
      for(NSString *tname in grp) {
        //NSLog(@"tname=%@", tname);
        int id = [trailTypeNameToId[tname] intValue];
        trailTypeIdSortOrder[id] = order++;
        trailTypeIdToDifficultyGroup[id] = groupnum;
      }
      groupnum++;
    }

    for(NSString *span in t_spans) {
      int span_id = [trailTypeNameToId[span] intValue];
      trailTypeIdIsSpan[span_id] = 1;
      for(NSString *tname in t_spans[span]) {
        int type_id = [trailTypeNameToId[tname] intValue];
        trailTypeIdToSpanId[type_id] = span_id;
      }
    }

    order = 0;
    for(NSString *pname in t_poi) {
      //NSLog(@"pname=%@", pname);
      int id = [poiTypeNameToId[pname] intValue];
      poiTypeIdSortOrder[id] = order++;
    }
  }
  return(self);
}

- (void)dealloc {
  free(trailTypeIdSortOrder);
  free(trailTypeIdToDifficultyGroup);
  free(trailTypeIdToSpanId);
  free(trailTypeIdIsSpan);
  //[super dealloc]; // Not available to do in conjunction with ARC
}

- (void)queryDatabaseForTypeNames {
  sqlite3      *mapDataDB_;

  NSString *mapDataDBName_ = [[NSBundle mainBundle]
                              pathForResource:@"BarreForestGuide"
                                       ofType:@"sqlite"];
  if (sqlite3_open([mapDataDBName_ UTF8String], &mapDataDB_) == SQLITE_OK) {

    NSString *trailTypeQuerySQL =
        [NSString stringWithFormat:@"select id,english_uses from trail_uses;"];
    sqlite3_stmt *trailTypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [trailTypeQuerySQL UTF8String], -1, &trailTypeQueryStmt, NULL) == SQLITE_OK) {
      NSMutableDictionary *trailTypeNameToIdMut = [[NSMutableDictionary alloc] init];
      while(sqlite3_step(trailTypeQueryStmt) == SQLITE_ROW) {
        int trail_type_id = sqlite3_column_int(trailTypeQueryStmt, 0);
        char *trail_type_name = (char*)sqlite3_column_text(trailTypeQueryStmt, 1);
        //NSLog(@"trail_type_id %d : %s", trail_type_id, trail_type_name);
        NSString *trail_type_str = [NSString stringWithUTF8String:trail_type_name];
        [trailTypeNameToIdMut setObject:[NSNumber numberWithInt:trail_type_id] forKey:trail_type_str];
        if (trail_type_id>maxTrailTypeId) maxTrailTypeId=trail_type_id;
      }
      sqlite3_finalize(trailTypeQueryStmt);
      trailTypeNameToId = [NSDictionary dictionaryWithDictionary:trailTypeNameToIdMut];
    } else
      NSLog(@"Failed to query database for trail types!");

    NSString *POITypeQuerySQL =
        [NSString stringWithFormat:@"select id,english_poi_type from poi_type order by id;"];
    sqlite3_stmt *POITypeQueryStmt = nil;
    if (sqlite3_prepare_v2(mapDataDB_, [POITypeQuerySQL UTF8String], -1, &POITypeQueryStmt, NULL) == SQLITE_OK) {
      NSMutableDictionary *poiTypeNameToIdMut = [[NSMutableDictionary alloc] init];
      while(sqlite3_step(POITypeQueryStmt) == SQLITE_ROW) {
        int poi_type_id = sqlite3_column_int(POITypeQueryStmt, 0);
        char *poi_type_name = (char*)sqlite3_column_text(POITypeQueryStmt, 1);
        //NSLog(@"poi_type_id %d : %s", poi_type_id, poi_type_name);
        NSString *poi_type_str = [NSString stringWithUTF8String:poi_type_name];
        [poiTypeNameToIdMut setObject:[NSNumber numberWithInt:poi_type_id] forKey:poi_type_str];
        if (poi_type_id>maxPoiTypeId) maxPoiTypeId=poi_type_id;
      }
      sqlite3_finalize(POITypeQueryStmt);
      poiTypeNameToId = [NSDictionary dictionaryWithDictionary:poiTypeNameToIdMut];
    } else
      NSLog(@"Failed to query database for POI type data!");
  } else
    NSLog(@"Failed to open database!");
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

- (UIColor*)getTrailTypeColor:(int)trailTypeId {
  NSNumber *ttid = [NSNumber numberWithInt:trailTypeId];
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

- (int)getTrailTypeSortOrder:(int)trailTypeId {
  int rv = maxTrailTypeId+1;
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId))
    rv = trailTypeIdSortOrder[trailTypeId];
  return(rv);
}

- (BOOL)isTrailTypeIdSpan:(int)trailTypeId {
  BOOL rv = NO;
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId))
    rv = trailTypeIdIsSpan[trailTypeId];
  return(rv);
}

- (void)toggleTrailTypeIdEnable:(int)trailTypeId {
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId)) {
    NSNumber *ttid = [NSNumber numberWithInt:trailTypeId];
    BOOL enabled = [[self.configModel.trailTypeEnabled objectForKey:ttid] boolValue];
    NSNumber *val;
    if (enabled) val = @0;
      else       val = @1;
    [self.configModel.trailTypeEnabled setObject:val forKey:ttid];
  }
}

- (int)getPoiTypeSortOrder:(int)poiTypeId {
  int rv = maxPoiTypeId+1;
  if ((poiTypeId>=0) && (poiTypeId<=maxPoiTypeId))
    rv = poiTypeIdSortOrder[poiTypeId];
  return(rv);
}

- (void)togglePoiTypeIdEnable:(int)poiTypeId {
  if ((poiTypeId>=0) && (poiTypeId<=maxPoiTypeId)) {
    NSNumber *ptid = [NSNumber numberWithInt:poiTypeId];
    BOOL enabled = [[self.configModel.poiTypeEnabled objectForKey:ptid] boolValue];
    NSNumber *val;
    if (enabled) val = @0;
      else       val = @1;
    [self.configModel.poiTypeEnabled setObject:val forKey:ptid];
  }
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

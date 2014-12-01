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

  int           numTrailDifficultyGroups;
  int          *trailTypeIdSortOrder;
  int          *trailTypeIdToDifficultyGroup;
  int          *trailTypeIdIsSpan;
  int          *trailTypeIdIsOther;
  NSDictionary *trailTypeIdToSpanIds;
  NSDictionary *trailSpanIdToTypeIds;
  NSDictionary *trailTypeRename;
  int           trailTypeOtherId;

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
    self.trailTypeWidth = [[NSMutableDictionary alloc] init];
    self.discGolfPathColor = nil;

    maxTrailTypeId = -1;
    maxPoiTypeId = -1;
    [self queryDatabaseForTypeNames];

    trailTypeIdSortOrder         = (int*)calloc(maxTrailTypeId+1, sizeof(int));
    trailTypeIdToDifficultyGroup = (int*)calloc(maxTrailTypeId+1, sizeof(int));
    trailTypeIdIsSpan            = (int*)calloc(maxTrailTypeId+1, sizeof(int));
    trailTypeIdIsOther           = (int*)calloc(maxTrailTypeId+1, sizeof(int));

    poiTypeIdSortOrder           = (int*)calloc(maxPoiTypeId+1, sizeof(int));

    NSArray *t_grps = @[ @[ @"Easy", @"Walking", @"Shoe" ],
                         @[ @"Moderate", @"BikePath", @"Ski" ],
                         @[ @"Hard", @"Motor" ],
                         @[ @"PvtRd" ],
                         @[ @"Extreme", @"Unmaintained", @"Other" ] ];
    NSDictionary *t_spans = @{ @"SkiShoe":      @[ @"Ski", @"Shoe" ],
                               @"MotorSkiShoe": @[ @"Motor", @"Ski", @"Shoe" ],
                               @"Other":        @[ @"Not", @"Skip" ] };
    trailTypeRename = @{ @"BikePath": @"Bike Path",
                         @"PvtRd": @"Private Road" };
    NSArray *t_poi = @[ @"Overlook", @"Historical Sign", @"Parking Lot", @"Store" ];

    for(int i=0; i<=maxTrailTypeId; i++) {
      trailTypeIdSortOrder[i] = maxTrailTypeId+1;
      trailTypeIdToDifficultyGroup[i] = -1;
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
    numTrailDifficultyGroups = groupnum;

    for(NSString *tname in t_spans[@"Other"]) {
      int id = [trailTypeNameToId[tname] intValue];
      trailTypeIdIsOther[id] = 1;
    }

    NSMutableDictionary *trailTypeIdToSpanIdsMut = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *trailSpanIdToTypeIdsMut = [[NSMutableDictionary alloc] init];
    for(NSString *span in t_spans) {
      NSNumber *span_id_num = trailTypeNameToId[span];
      int span_id = [span_id_num intValue];
      trailTypeIdIsSpan[span_id] = 1;
      for(NSString *tname in t_spans[span]) {
        NSNumber *ttid_num = trailTypeNameToId[tname];
        NSMutableArray *span_ids = trailTypeIdToSpanIdsMut[ttid_num];
        if (span_ids==nil) {
          span_ids = [[NSMutableArray alloc] init];
          [trailTypeIdToSpanIdsMut setObject:span_ids forKey:ttid_num];
        }
        [span_ids addObject:span_id_num];
        NSMutableArray *type_ids = trailSpanIdToTypeIdsMut[span_id_num];
        if (type_ids==nil) {
          type_ids = [[NSMutableArray alloc] init];
          [trailSpanIdToTypeIdsMut setObject:type_ids forKey:span_id_num];
        }
        [type_ids addObject:ttid_num];
      }
    }
    NSArray *ttid_nums = [trailTypeIdToSpanIdsMut allKeys];
    for(NSNumber *ttid_num in ttid_nums)
      trailTypeIdToSpanIdsMut[ttid_num] = [NSArray arrayWithArray:trailTypeIdToSpanIdsMut[ttid_num]];
    trailTypeIdToSpanIds = [NSDictionary dictionaryWithDictionary:trailTypeIdToSpanIdsMut];
    NSArray *span_id_nums = [trailSpanIdToTypeIdsMut allKeys];
    for(NSNumber *span_id_num in span_id_nums)
      trailSpanIdToTypeIdsMut[span_id_num] = [NSArray arrayWithArray:trailSpanIdToTypeIdsMut[span_id_num]];
    trailSpanIdToTypeIds = [NSDictionary dictionaryWithDictionary:trailSpanIdToTypeIdsMut];

    order = 0;
    for(NSString *pname in t_poi) {
      //NSLog(@"pname=%@", pname);
      int id = [poiTypeNameToId[pname] intValue];
      poiTypeIdSortOrder[id] = order++;
    }

    // Must have a fresh, uninitialized ConfigModel, so set the defaults
    if (self.configModel.trailTypeEnabled==nil) {
      self.configModel.trailTypeEnabled = [[NSMutableDictionary alloc] init];
      for(int ttid=0; ttid<=maxTrailTypeId; ttid++)
        if (trailTypeIdSortOrder[ttid]<=maxTrailTypeId)
          [self setTrailTypeIdEnable:ttid enable:YES];
      // If we are having to create the trailTypeEnabled object, we'll assume
      //   that we've got a fresh ConfigModel, so we'll set the discGolfEnabled
      //   to the default too
      self.configModel.discGolfEnabled = true;
    }
    if (self.configModel.poiTypeEnabled==nil) {
      self.configModel.poiTypeEnabled = [[NSMutableDictionary alloc] init];
      for(int ptid=0; ptid<=maxPoiTypeId; ptid++)
        if (poiTypeIdSortOrder[ptid]<=maxPoiTypeId)
          [self setPoiTypeIdEnable:ptid enable:YES];
    }

  }
  return(self);
}

- (void)dealloc {
  free(trailTypeIdSortOrder);
  free(trailTypeIdToDifficultyGroup);
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

      if (trailTypeNameToIdMut[@"Other"]==nil) {
        trailTypeOtherId = ++maxTrailTypeId;
        [trailTypeNameToIdMut setObject:[NSNumber numberWithInt:trailTypeOtherId] forKey:@"Other"];
      }

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
  self.trailTypeWidth = [[NSMutableDictionary alloc] init];
  self.discGolfPathColor = nil;
  self.discGolfPathWidth = nil;
}

- (UIColor*)getTrailTypeColor:(int)trailTypeId {
  NSNumber *ttid = [NSNumber numberWithInt:trailTypeId];
  UIColor *color = [self.trailTypeColor objectForKey:ttid];
  if (color==nil) {
    BOOL enabled = [[self.configModel.trailTypeEnabled objectForKey:ttid] boolValue];
    if (!enabled) {
      color = [UIColor colorWithWhite:0.75f alpha:0.5f];
    } else {
      int difficulty = trailTypeIdToDifficultyGroup[trailTypeId];
      if (difficulty==-1) difficulty=numTrailDifficultyGroups-1;
      double hue = (1.0f-(((double)difficulty)/((double)(numTrailDifficultyGroups-1))))*0.20f+0.0333f+0.025;
      //NSLog(@"difficulty=%d, hue=%f", difficulty, hue);
      if ((self.configModel.mapType==kGMSTypeNormal) ||
          (self.configModel.mapType==kGMSTypeTerrain))
      {
        color = [UIColor colorWithHue:hue saturation:1.0f brightness:0.8f alpha:1.0f];
      } else {
        color = [UIColor colorWithHue:hue saturation:0.8f brightness:0.9f alpha:1.0f];
      }
    }
    [self.trailTypeColor setObject:color forKey:ttid];
  }
  return(color);
}

- (CGFloat )getTrailTypeWidth:(int)trailTypeId {
  NSNumber *ttid = [NSNumber numberWithInt:trailTypeId];
  NSNumber *width = [self.trailTypeWidth objectForKey:ttid];
  if (width==nil) {
    BOOL enabled = [[self.configModel.trailTypeEnabled objectForKey:ttid] boolValue];
    if (!enabled) {
      width = @1.0f;
    } else {
      int difficulty = trailTypeIdToDifficultyGroup[trailTypeId];
      if (difficulty==-1) difficulty=numTrailDifficultyGroups-1;
      if ((self.configModel.mapType==kGMSTypeNormal) ||
          (self.configModel.mapType==kGMSTypeTerrain))
      {
        width = @1.0f;
      } else {
        width = @2.0f;
      }
    }
    [self.trailTypeWidth setObject:width forKey:ttid];
  }
  return([width floatValue]);
}

- (UIColor*)getDiscGolfPathColor {
  if (self.discGolfPathColor==nil) {
    if (!self.configModel.discGolfEnabled) {
      self.discGolfPathColor = [UIColor colorWithWhite:0.0f alpha:0.0f];
    } else {
      if ((self.configModel.mapType==kGMSTypeNormal) ||
          (self.configModel.mapType==kGMSTypeTerrain))
      {
        self.discGolfPathColor = [UIColor colorWithHue:0.833f saturation:1.0f brightness:0.8f alpha:1.0f];
      } else {
        self.discGolfPathColor = [UIColor colorWithHue:0.833f saturation:5.0f brightness:1.0f alpha:1.0f];
      }
    }
  }
  return(self.discGolfPathColor);
}

- (CGFloat )getDiscGolfPathWidth {
  if (self.discGolfPathWidth==nil) {
    if (!self.configModel.discGolfEnabled) {
      self.discGolfPathWidth = @1.0f;
    } else {
      if ((self.configModel.mapType==kGMSTypeNormal) ||
          (self.configModel.mapType==kGMSTypeTerrain))
      {
        self.discGolfPathWidth = @2.0f;
      } else {
        self.discGolfPathWidth = @2.0f;
      }
    }
  }
  return([self.discGolfPathWidth floatValue]);
}

- (int)getTrailTypeSortOrder:(int)trailTypeId {
  int rv = maxTrailTypeId+1;
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId))
    rv = trailTypeIdSortOrder[trailTypeId];
  return(rv);
}

- (int)getTrailTypeOtherId { return(trailTypeOtherId); }

- (BOOL)isTrailTypeIdSpan:(int)trailTypeId {
  BOOL rv = NO;
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId))
    rv = trailTypeIdIsSpan[trailTypeId];
  return(rv);
}

- (BOOL)isTrailTypeIdOther:(int)trailTypeId {
  BOOL rv = NO;
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId))
    rv = trailTypeIdIsOther[trailTypeId];
  return(rv);
}

- (void)setTrailTypeIdEnable:(int)trailTypeId enable:(BOOL)enable {
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId)) {
    NSNumber *ttidnum = [NSNumber numberWithInt:trailTypeId];
    if (enable) [self.configModel.trailTypeEnabled setObject:@1 forKey:ttidnum];
      else      [self.configModel.trailTypeEnabled removeObjectForKey:ttidnum];
    for(NSNumber *span_id_num in trailTypeIdToSpanIds[ttidnum]) {
      BOOL span_enable = enable;
      for(NSNumber *spanttidnum in trailSpanIdToTypeIds[span_id_num]) {
        span_enable = span_enable || [self.configModel.trailTypeEnabled[spanttidnum] boolValue];
      }
      if (span_enable) [self.configModel.trailTypeEnabled setObject:@1 forKey:span_id_num];
        else           [self.configModel.trailTypeEnabled removeObjectForKey:span_id_num];
    }
    if (trailTypeId==trailTypeOtherId) {
      for(NSNumber *otheridnum in trailSpanIdToTypeIds[ttidnum]) {
        if (enable) [self.configModel.trailTypeEnabled setObject:@1 forKey:otheridnum];
          else      [self.configModel.trailTypeEnabled removeObjectForKey:otheridnum];
      }
    }
  }
}

- (void)toggleTrailTypeIdEnable:(int)trailTypeId {
  if ((trailTypeId>=0) && (trailTypeId<=maxTrailTypeId)) {
    NSNumber *ttidnum = [NSNumber numberWithInt:trailTypeId];
    BOOL enabled = [[self.configModel.trailTypeEnabled objectForKey:ttidnum] boolValue];
    [self setTrailTypeIdEnable:trailTypeId enable:!enabled];
  }
}

- (NSString*)getTrailTypeRename:(NSString*)trailTypeName {
  NSString *rv = trailTypeRename[trailTypeName];
  if (rv==nil) rv=trailTypeName;
  return(rv);
}

- (int)getPoiTypeSortOrder:(int)poiTypeId {
  int rv = maxPoiTypeId+1;
  if ((poiTypeId>=0) && (poiTypeId<=maxPoiTypeId))
    rv = poiTypeIdSortOrder[poiTypeId];
  return(rv);
}

- (void)setPoiTypeIdEnable:(int)poiTypeId enable:(BOOL)enable {
  if ((poiTypeId>=0) && (poiTypeId<=maxPoiTypeId)) {
    NSNumber *ptidnum = [NSNumber numberWithInt:poiTypeId];
    if (enable) [self.configModel.poiTypeEnabled setObject:@1 forKey:ptidnum];
      else      [self.configModel.poiTypeEnabled removeObjectForKey:ptidnum];
  }
}

- (void)togglePoiTypeIdEnable:(int)poiTypeId {
  if ((poiTypeId>=0) && (poiTypeId<=maxPoiTypeId)) {
    NSNumber *ptidnum = [NSNumber numberWithInt:poiTypeId];
    BOOL enabled = [[self.configModel.poiTypeEnabled objectForKey:ptidnum] boolValue];
    [self setPoiTypeIdEnable:poiTypeId enable:!enabled];
  }
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

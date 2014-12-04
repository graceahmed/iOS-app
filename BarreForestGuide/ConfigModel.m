//
//  ConfigModel.m
//  BarreForestGuide
//
//  Created by Craig B. Agricola on 11/17/14.
//  Copyright (c) 2014 Town of Barre. All rights reserved.
//

#import "ConfigModel.h"

@implementation ConfigModel

#pragma mark - NSCoding

- (id) init {
  if (self = [super init]) {
    self.mapTracksGPS = NO;
    self.mapType = kGMSTypeNormal;
    self.mapSeason = auto_map_season;
    self.sharingEnabled = NO;
    self.trailTypeEnabled = nil;
    self.poiTypeEnabled = nil;
    self.discGolfEnabled = NO;
    self.discGolfIconsEnabled = NO;
  }
  return(self);
}

+ (ConfigModel*)getConfigModel {
  static ConfigModel *singleton = nil;
  static dispatch_once_t gate;
  dispatch_once(&gate, ^{ singleton = [[ConfigModel alloc] initFromDefaults]; });
  return(singleton);
}

- (id) initWithCoder:(NSCoder*)decoder {
  self.mapTracksGPS = [decoder decodeBoolForKey:@"mapTracksGPS"];
  self.mapType = [decoder decodeIntForKey:@"mapType"];
  self.mapSeason = [decoder decodeIntForKey:@"mapSeason"];
  self.sharingEnabled = [decoder decodeBoolForKey:@"sharingEnabled"];
  self.trailTypeEnabled = [decoder decodeObjectForKey:@"trailTypeEnabled"];
  self.poiTypeEnabled = [decoder decodeObjectForKey:@"poiTypeEnabled"];
  self.discGolfEnabled = [decoder decodeBoolForKey:@"discGolfEnabled"];
  self.discGolfIconsEnabled = [decoder decodeBoolForKey:@"discGolfIconsEnabled"];
  return(self);
}

- (id) initFromDefaults {
  NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"config"];
  if (data) {
    self = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  } else {
    self = [self init];
  }
  NSLog(@"initFromDefaults: mapTracksGPS=%d, mapType=%d, mapSeason=%d, sharingEnabled=%d, trailTypeEnabled=%@, poiTypeEnabled=%@, discGolfEnabled=%d, discGolfIconsEnabled=%d", self.mapTracksGPS, self.mapType, self.mapSeason, self.sharingEnabled, self.trailTypeEnabled, self.poiTypeEnabled, self.discGolfEnabled, self.discGolfIconsEnabled);
  return(self);
}

- (void) encodeWithCoder:(NSCoder*)encoder {
  [encoder encodeBool:_mapTracksGPS forKey:@"mapTracksGPS"];
  [encoder encodeInt:_mapType forKey:@"mapType"];
  [encoder encodeInt:_mapSeason forKey:@"mapSeason"];
  [encoder encodeBool:_sharingEnabled forKey:@"sharingEnabled"];
  [encoder encodeObject:_trailTypeEnabled forKey:@"trailTypeEnabled"];
  [encoder encodeObject:_poiTypeEnabled forKey:@"poiTypeEnabled"];
  [encoder encodeBool:_discGolfEnabled forKey:@"discGolfEnabled"];
  [encoder encodeBool:_discGolfIconsEnabled forKey:@"discGolfIconsEnabled"];
}

- (void) saveToDefaults {
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];

  /*
  NSData *data = [NSMutableData data];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  [archiver setOutputFormat:NSPropertyListXMLFormat_v1_0];
  [archiver encodeObject:self forKey:@"config"];
  [archiver finishEncoding];
  */

  [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"config"];
  NSLog(@"saveToDefaults: mapTracksGPS=%d, mapType=%d, mapSeason=%d, sharingEnabled=%d, trailTypeEnabled=%@, poiTypeEnabled=%@, discGolfEnabled=%d, discGolfIconsEnabled=%d", self.mapTracksGPS, self.mapType, self.mapSeason, self.sharingEnabled, self.trailTypeEnabled, self.poiTypeEnabled, self.discGolfEnabled, self.discGolfIconsEnabled);
}

- (BOOL) isSummerMapSeason {
  if (self.mapSeason==summer_map_season) return(YES);
  else if (self.mapSeason==winter_map_season) return(NO);
  else {
    NSDate *now = [NSDate date];
    NSCalendar *userCal = [NSCalendar currentCalendar];
    int yearDay = [userCal ordinalityOfUnit:NSDayCalendarUnit inUnit: NSYearCalendarUnit forDate: now];
    if ((yearDay > 79) && (yearDay < 266)) return(YES);  // FIXME - these are just the equinoxes, and probably aren't realistic times to switch over
    else                                   return(NO);
  }
}

@end

/* vim: set ai si sw=2 ts=80 ru: */

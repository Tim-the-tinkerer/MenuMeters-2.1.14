//
//  MenuMeterDiskSpace.m
//
// 	Reader object for disk space statistics
//
//	Copyright (c) 2002-2014 Alex Harper
//
// 	This file is part of MenuMeters.
//
// 	MenuMeters is free software; you can redistribute it and/or modify
// 	it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
// 	MenuMeters is distributed in the hope that it will be useful,
// 	but WITHOUT ANY WARRANTY; without even the implied warranty of
// 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// 	GNU General Public License for more details.
//
// 	You should have received a copy of the GNU General Public License
// 	along with MenuMeters; if not, write to the Free Software
// 	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "MenuMeterDiskSpace.h"
#import <sys/mount.h>


///////////////////////////////////////////////////////////////
//
//	Private methods and functions
//
///////////////////////////////////////////////////////////////

@interface MenuMeterDiskSpace (PrivateMethods)
- (NSString *)spaceString:(double)space;
- (BOOL)shouldIncludeMountPath:(NSString *)mountPath statfs:(const struct statfs *)fs;
@end


static NSComparisonResult SortDiskEntryByName(NSDictionary *a, NSDictionary *b, void *context) {
	NSString *na = a[@"name"] ?: @"";
	NSString *nb = b[@"name"] ?: @"";
	return [na localizedStandardCompare:nb];
}


///////////////////////////////////////////////////////////////
//
//	Localized strings
//
///////////////////////////////////////////////////////////////

#define	kUsedSpaceFormat		@"%@ Used"
#define	kFreeSpaceFormat		@"%@ Free"
#define	kTotalSpaceFormat		@"%@ Total"
#define kKBLabel				@"KB"
#define kMBLabel				@"MB"
#define kGBLabel				@"GB"
#define kTBLabel				@"TB"


///////////////////////////////////////////////////////////////
//
//	init/dealloc
//
///////////////////////////////////////////////////////////////

@implementation MenuMeterDiskSpace

- (id)init {

	self = [super init];
	if (!self) {
		return nil;
	}

	// NumberFormatter for localization (no archive cycle needed on modern macOS).
	NSNumberFormatter *tempFormat = [[NSNumberFormatter alloc] init];
	[tempFormat setLocalizesFormat:YES];
	[tempFormat setFormat:@"####0.00"];
	spaceFormatter = tempFormat;
	if (!spaceFormatter) {
		return nil;
	}

	return self;

} // init

///////////////////////////////////////////////////////////////
//
//	Disk space info
//
///////////////////////////////////////////////////////////////

- (BOOL)shouldIncludeMountPath:(NSString *)mountPath statfs:(const struct statfs *)fs {
	if (!mountPath.length || !fs) {
		return NO;
	}

	// Only local-ish block filesystems users care about.
	const char *fstype = fs->f_fstypename;
	BOOL knownFS =
		!strcmp(fstype, "hfs") ||
		!strcmp(fstype, "apfs") ||
		!strcmp(fstype, "ufs") ||
		!strcmp(fstype, "msdos") ||
		!strcmp(fstype, "exfat") ||
		!strcmp(fstype, "ntfs") ||
		!strcmp(fstype, "cd9660") ||
		!strcmp(fstype, "cddafs") ||
		!strcmp(fstype, "udf");
	if (!knownFS) {
		return NO;
	}

	// Skip volumes marked nobrowse / automounted system mounts.
	if (fs->f_flags & MNT_DONTBROWSE) {
		return NO;
	}

	// Hard-filter known macOS system volume mount points that still leak through.
	// (APFS system role volumes: Preboot, VM, Update, xarts, Hardware, iSCPreboot, Data, …)
	if ([mountPath hasPrefix:@"/System/Volumes/"]) {
		return NO;
	}
	if ([mountPath hasPrefix:@"/private/var/vm"] ||
		[mountPath isEqualToString:@"/private/var/vm"]) {
		return NO;
	}
	// Autofs / network home stubs
	if ([mountPath hasPrefix:@"/System/Volumes/Data/home"] ||
		[mountPath isEqualToString:@"/home"]) {
		return NO;
	}

	return YES;
}

- (NSMutableArray *)diskSpaceData {

	// Prefer NSFileManager with SkipHiddenVolumes so we match Finder (no
	// Preboot / VM / Update / sealed-system APFS roles). Fall back to getmntinfo
	// filtering if that API returns nothing unexpected.
	NSArray<NSURLResourceKey> *keys = @[
		NSURLVolumeNameKey,
		NSURLVolumeLocalizedNameKey,
		NSURLVolumeTotalCapacityKey,
		NSURLVolumeAvailableCapacityKey,
		NSURLVolumeIsBrowsableKey,
		NSURLVolumeIsLocalKey,
	];

	NSArray<NSURL *> *volumeURLs =
		[[NSFileManager defaultManager]
			mountedVolumeURLsIncludingResourceValuesForKeys:keys
			options:NSVolumeEnumerationSkipHiddenVolumes];

	NSMutableArray *diskSpaceDetails = [NSMutableArray array];
	NSMutableSet<NSString *> *seenPaths = [NSMutableSet set];

	for (NSURL *url in volumeURLs) {
		NSString *mountPath = url.path;
		if (!mountPath.length) {
			continue;
		}

		// Resolve resource values
		NSNumber *browsable = nil;
		[url getResourceValue:&browsable forKey:NSURLVolumeIsBrowsableKey error:NULL];
		if (browsable && !browsable.boolValue) {
			continue;
		}

		// Cross-check with statfs for fstype / flags / device name / block counts.
		struct statfs fs = {0};
		if (statfs(mountPath.fileSystemRepresentation, &fs) != 0) {
			continue;
		}
		if (![self shouldIncludeMountPath:mountPath statfs:&fs]) {
			continue;
		}

		// De-dupe (symlinks / multiple URLs to same mount).
		NSString *canonical = [mountPath stringByStandardizingPath];
		if ([seenPaths containsObject:canonical]) {
			continue;
		}
		[seenPaths addObject:canonical];

		NSString *volName = nil;
		[url getResourceValue:&volName forKey:NSURLVolumeLocalizedNameKey error:NULL];
		if (!volName.length) {
			[url getResourceValue:&volName forKey:NSURLVolumeNameKey error:NULL];
		}
		if (!volName.length) {
			volName = mountPath.lastPathComponent.length ? mountPath.lastPathComponent : mountPath;
		}

		NSNumber *totalCap = nil;
		NSNumber *availCap = nil;
		[url getResourceValue:&totalCap forKey:NSURLVolumeTotalCapacityKey error:NULL];
		[url getResourceValue:&availCap forKey:NSURLVolumeAvailableCapacityKey error:NULL];

		// Prefer NSURL capacities when present; else statfs.
		double totalBytes = totalCap ? totalCap.doubleValue : ((double)fs.f_blocks * (double)fs.f_bsize);
		double freeBytes  = availCap ? availCap.doubleValue : ((double)fs.f_bavail * (double)fs.f_bsize);
		if (totalBytes <= 0) {
			// Empty / pseudo volumes
			continue;
		}
		double usedBytes = totalBytes - freeBytes;
		if (usedBytes < 0) usedBytes = 0;

		NSMutableDictionary *diskStats = [NSMutableDictionary dictionary];
		diskStats[@"name"] = volName;
		diskStats[@"path"] = mountPath;
		diskStats[@"fstype"] = [NSString stringWithUTF8String:fs.f_fstypename];
		diskStats[@"device"] = [NSString stringWithUTF8String:fs.f_mntfromname];

		NSImage *volIcon = [[NSWorkspace sharedWorkspace] iconForFile:mountPath];
		if (volIcon) {
			diskStats[@"icon"] = volIcon;
		}

		diskStats[@"total"] = [NSString stringWithFormat:[localizedStrings objectForKey:kTotalSpaceFormat],
								[self spaceString:totalBytes]];
		diskStats[@"free"] = [NSString stringWithFormat:[localizedStrings objectForKey:kFreeSpaceFormat],
								[self spaceString:freeBytes]];
		diskStats[@"used"] = [NSString stringWithFormat:[localizedStrings objectForKey:kUsedSpaceFormat],
								[self spaceString:usedBytes]];

		[diskSpaceDetails addObject:diskStats];
	}

	// Fallback: if NSFileManager returned nothing usable, walk getmntinfo with filters.
	if (diskSpaceDetails.count == 0) {
		struct statfs *mountInfo = NULL;
		int mountCount = getmntinfo(&mountInfo, MNT_WAIT);
		for (int i = 0; i < mountCount; i++) {
			NSString *mountPath = [[NSFileManager defaultManager]
				stringWithFileSystemRepresentation:mountInfo[i].f_mntonname
				length:strlen(mountInfo[i].f_mntonname)];
			if (![self shouldIncludeMountPath:mountPath statfs:&mountInfo[i]]) {
				continue;
			}
			double totalBytes = (double)mountInfo[i].f_blocks * (double)mountInfo[i].f_bsize;
			double freeBytes  = (double)mountInfo[i].f_bavail * (double)mountInfo[i].f_bsize;
			if (totalBytes <= 0) continue;
			double usedBytes = totalBytes - freeBytes;
			if (usedBytes < 0) usedBytes = 0;

			NSMutableDictionary *diskStats = [NSMutableDictionary dictionary];
			diskStats[@"name"] = mountPath.lastPathComponent.length ? mountPath.lastPathComponent : mountPath;
			diskStats[@"path"] = mountPath;
			diskStats[@"fstype"] = [NSString stringWithUTF8String:mountInfo[i].f_fstypename];
			diskStats[@"device"] = [NSString stringWithUTF8String:mountInfo[i].f_mntfromname];
			NSImage *volIcon = [[NSWorkspace sharedWorkspace] iconForFile:mountPath];
			if (volIcon) diskStats[@"icon"] = volIcon;
			diskStats[@"total"] = [NSString stringWithFormat:[localizedStrings objectForKey:kTotalSpaceFormat],
									[self spaceString:totalBytes]];
			diskStats[@"free"] = [NSString stringWithFormat:[localizedStrings objectForKey:kFreeSpaceFormat],
									[self spaceString:freeBytes]];
			diskStats[@"used"] = [NSString stringWithFormat:[localizedStrings objectForKey:kUsedSpaceFormat],
									[self spaceString:usedBytes]];
			[diskSpaceDetails addObject:diskStats];
		}
	}

	// Sort by display name (matches Finder better than raw device id).
	[diskSpaceDetails sortUsingFunction:&SortDiskEntryByName context:NULL];

	return diskSpaceDetails;

} // diskSpaceData

- (void)setBaseTen:(BOOL)baseTen {

	useBaseTen = baseTen;

} // setBaseTen

///////////////////////////////////////////////////////////////
//
//	Utility
//
///////////////////////////////////////////////////////////////

- (NSString *)spaceString:(double)space {

	if (useBaseTen) {
		if (space >= 1000000000000.0) {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1000000000000.0]],
					[localizedStrings objectForKey:kTBLabel] ?: @"TB"];
		} else if (space >= 1000000000.0) {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1000000000.0]],
					[localizedStrings objectForKey:kGBLabel]];
		} else if (space >= 1000000.0) {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1000000.0]],
					[localizedStrings objectForKey:kMBLabel]];
		} else {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1000.0]],
					[localizedStrings objectForKey:kKBLabel]];
		}
	} else {
		if (space >= 1099511627776.0) {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1099511627776.0]],
					[localizedStrings objectForKey:kTBLabel] ?: @"TB"];
		} else if (space >= 1073741824.0) {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1073741824.0]],
					[localizedStrings objectForKey:kGBLabel]];
		} else if (space >= 1048576.0) {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1048576.0]],
					[localizedStrings objectForKey:kMBLabel]];
		} else {
			return [NSString stringWithFormat:@"%@%@",
					[spaceFormatter stringForObjectValue:[NSNumber numberWithDouble:space / 1024.0]],
					[localizedStrings objectForKey:kKBLabel]];
		}
	}

} // spaceString

@end

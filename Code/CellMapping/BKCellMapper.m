//
// Created by Bruno Wernimont on 2012
// Copyright 2012 BaseKit
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "BKCellMapper.h"

#import "BKCellMapping.h"
#import "BKCellAttributeMapping.h"
#import "BKDynamicCellMapping.h"
#import "BKMacrosDefinitions.h"


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface BKCellMapper ()

+ (void)mapLabelAttributeOfTypeDefaultWithObject:(id)object
                                attributeMapping:(BKCellAttributeMapping *)attributeMapping
                                            cell:(UITableViewCell *)cell;

+ (void)setCell:(UITableViewCell *)cell value:(id)value forKeyPath:(NSString *)keyPath;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation BKCellMapper

@synthesize cellMapping = _cellMapping;
@synthesize object = _object;
@synthesize cell = _cell;


////////////////////////////////////////////////////////////////////////////////////////////////////
#if !BK_HAS_ARC
- (void)dealloc {
    [_cellMapping release];
    [_cell release];
    
    [super dealloc];
}
#endif


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSSet *)cellMappingsForObject:(id)object mappings:(NSDictionary *)mappings {
    NSString *objectStringName = NSStringFromClass([object class]);
    return [mappings objectForKey:objectStringName];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BKCellMapping *)cellMappingForObject:(id)object mappings:(NSSet *)mappings {
    BK_UNRETAINED_BLOCK_IVAR BKCellMapping *cellMappingForObject = [mappings anyObject];
    BOOL isDynamicMapping = mappings.count > 1;
    
    if (isDynamicMapping) {
        [mappings enumerateObjectsUsingBlock:^(id cellMapping, BOOL *stop) {
            if ([cellMapping isKindOfClass:[BKDynamicCellMapping class]]) {
                NSString *dynamicKeyPath = [[cellMapping dynamicKeyPath] description];
                NSString *dynamicKeyPathValue = [cellMapping keyPathEqualTo];
                
                if ([[object valueForKeyPath:dynamicKeyPath] isEqualToString:dynamicKeyPathValue]) {
                    cellMappingForObject = cellMapping;
                }
            }
        }];
    }
    
    return cellMappingForObject;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (void)mapCellAttributeWithMapping:(BKCellMapping *)cellMapping
                             object:(id)object
                               cell:(UITableViewCell *)cell {

    [cellMapping.attributeMappings enumerateKeysAndObjectsUsingBlock:^(id key, BKCellAttributeMapping *cellAttributeMapping, BOOL *stop) {
        if (cellAttributeMapping.mappingType == BKCellAttributeMappingTypeDefault) {
            [self mapLabelAttributeOfTypeDefaultWithObject:object
                                          attributeMapping:cellAttributeMapping
                                                      cell:cell];
        }
    }];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (void)mapSourceValue:(id)sourceValue toDestinationValue:(id)destinationValue fromCell:(UITableViewCell *)cell {
}


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (void)setCell:(UITableViewCell *)cell value:(id)value forKeyPath:(NSString *)keyPath {
    @try {
        [cell setValue:value forKeyPath:keyPath];
    }
    @catch (NSException *exception) {
        NSLog(@"Error BaseKitCellMapping attribute %@ doesn't exist for cell name %@",
              keyPath, NSStringFromClass([cell class]));
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (void)mapLabelAttributeOfTypeDefaultWithObject:(id)object
                                attributeMapping:(BKCellAttributeMapping *)attributeMapping
                                            cell:(UITableViewCell *)cell {
    
    id keyPathValue = nil;
    
    @try {
        keyPathValue = [object valueForKeyPath:attributeMapping.keyPath];
    }
    @catch (NSException *exception) {
        NSLog(@"Error BaseKitCellMapping keyPath %@ doesn't exist for object name %@",
              attributeMapping.keyPath, NSStringFromClass([object class]));
    }
    
    if (attributeMapping.valueBlock != nil) {
        keyPathValue = attributeMapping.valueBlock(keyPathValue);
    }
    
    if (attributeMapping.objectBlock != nil) {
        keyPathValue = attributeMapping.objectBlock(keyPathValue, object);
    }
    
    id cellValue = nil;
    
    cellValue = keyPathValue;
    
    [self setCell:cell value:cellValue forKeyPath:attributeMapping.attribute];
}

@end

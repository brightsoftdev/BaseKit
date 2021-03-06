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

#import "BKFormMapper.h"

#import "BKFormMapping.h"
#import "BKFormAttributeMapping.h"
#import "UITableViewCell+BaseKit.h"
#import "NSDictionary+BaseKit.h"
#import "BaseKitFormField.h"
#import "NSObject+BKFormAttributeMapping.h"
#import "BKFormModel.h"
#import "BKMacrosDefinitions.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface BKFormMapper ()

@property (nonatomic, retain) NSArray *titles;
@property (nonatomic, retain) NSArray *sections;

- (void)mapAttributeMapping:(BKFormAttributeMapping *)attributeMapping
                      value:(id)value
                  withField:(BKSimpleField *)field;

- (BKSimpleField *)cellWithAttributeMapping:(BKFormAttributeMapping *)attributeMapping sourceClass:(Class)sourceClass;

- (Class)classFromSourcePropertyAtIndexPath:(NSIndexPath *)indexPath keyPath:(NSString *)keyPath;

- (id)valueOfObjectForKeyPath:(NSString *)keyPath;

- (void)splitFieldsIntoSections;

- (NSString *)formattedStringDate:(NSDate *)date usingFormat:(NSString *)dateFormat;

- (id)convertValueIfneeded:(id)value attributeMapping:(BKFormAttributeMapping *)attributeMapping;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation BKFormMapper

@synthesize formMapping = _formMapping;
@synthesize tableView = _tableView;
@synthesize object = _object;
@synthesize titles = _titles;
@synthesize sections = _sections;


////////////////////////////////////////////////////////////////////////////////////////////////////
#if !BK_HAS_ARC
- (void)dealloc {
    [_formMapping release];
    [_tableView release];
    [_object retain];
    self.titles = nil;
    self.sections = nil;
    
    [super dealloc];
}
#endif


////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithFormMapping:(BKFormMapping *)formMapping
                tabelView:(UITableView *)tableView
                   object:(id)object
                formModel:(BKFormModel *)formModel {
    
    self = [super init];
    
    if (self) {
        _formModel = formModel; // weak ivar
        _formMapping = BK_RETAIN(formMapping);
        _tableView = BK_RETAIN(tableView);
        _object = BK_RETAIN(object);
        [self splitFieldsIntoSections];
    }
    
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSInteger)numberOfSections {
    return self.formMapping.sectionTitles.count;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSInteger)numberOfRowsInSection:(NSInteger)section {
    return [(NSArray *)[self.sections objectAtIndex:section] count];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)titleForHeaderInSection:(NSInteger)section {
    return [self.titles objectAtIndex:section];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BKFormAttributeMapping *attributeMapping = [self attributeMappingAtIndexPath:indexPath];
    Class sourceClass = [self classFromSourcePropertyAtIndexPath:indexPath keyPath:attributeMapping.attribute];
    BKSimpleField *field = [self cellWithAttributeMapping:attributeMapping sourceClass:sourceClass];
    id value = [self valueForAttriteMapping:attributeMapping];
    [self mapAttributeMapping:attributeMapping value:value withField:field];
    field.textLabel.text = attributeMapping.title;
    
    return field;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (BKFormAttributeMapping *)attributeMappingAtIndexPath:(NSIndexPath *)indexPath {
    return [[self.sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)valueForAttriteMapping:(BKFormAttributeMapping *)attributeMapping {
    return [self valueOfObjectForKeyPath:attributeMapping.attribute];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setValue:(id)value forAttributeMapping:(BKFormAttributeMapping *)attributeMapping {
    [self.object setValue:value forKeyPath:attributeMapping.attribute];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Actions


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didPressSave:(id)sender {
    self.formMapping.saveAttribute.saveBtnHandler();
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Getters and setters


////////////////////////////////////////////////////////////////////////////////////////////////////
- (BKFormModel *)formModel {
    return _formModel;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)formattedStringDate:(NSDate *)date usingFormat:(NSString *)dateFormat {
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:dateFormat];
    [formatter setCalendar:cal];
    [formatter setLocale:[NSLocale currentLocale]];
    NSString *stringDate = [formatter stringFromDate:date];
    BK_RELEASE(cal);
    BK_RELEASE(formatter);
    return stringDate;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapAttributeMapping:(BKFormAttributeMapping *)attributeMapping
                      value:(id)value
                  withField:(BKSimpleField *)field {
    
    id convertedValue = [self convertValueIfneeded:value attributeMapping:attributeMapping];
    BK_RETAIN_WITHOUT_RETURN(convertedValue);
    
    // Value attribution
    if ([field isKindOfClass:[BKTextField class]]) {
        [(BKTextField *)field textField].text = convertedValue;
        [(BKTextField *)field textField].placeholder = attributeMapping.placeholderText;
        
    } else if ([field isKindOfClass:[BKSwitchField class]] && [convertedValue isKindOfClass:[NSNumber class]]) {
        UISwitch *switchControl = [(BKSwitchField *)field switchControl];
        switchControl.on = [(NSNumber *)convertedValue boolValue];
        switchControl.formAttributeMapping = attributeMapping;
        [switchControl addTarget:self
                          action:@selector(switchFieldValueDidChange:)
                forControlEvents:UIControlEventValueChanged];
        
    } else if ([field isKindOfClass:[BKSaveButtonField class]]) {
        [(BKSaveButtonField *)field setTitle:attributeMapping.title];
        
    } else if ([field isKindOfClass:[BKButtonField class]]) {
        field.textLabel.text = attributeMapping.title;
        field.accessoryType = attributeMapping.accesoryType;
        
    } else /*if ([field isKindOfClass:[BKLabelField class]])*/ {
        if (![convertedValue isKindOfClass:[NSString class]]) {
            convertedValue = [convertedValue description];
        }
        
        field.detailTextLabel.text = convertedValue;
        
    }
    
    BK_RELEASE(convertedValue);
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (BKSimpleField *)cellWithAttributeMapping:(BKFormAttributeMapping *)attributeMapping
                                sourceClass:(Class)sourceClass {
    
    BKSimpleField *field = nil;
    BKFormAttributeMappingType type = attributeMapping.type;
    
    if (type == BKFormAttributeMappingTypeText) {
        field = [BKTextField cellForTableView:self.tableView];
        [[(BKTextField *)field textField] setDelegate:self];
        [[(BKTextField *)field textField] setFormAttributeMapping:attributeMapping];
        
    } else if (type == BKFormAttributeMappingTypeFloat) {
        field = [BKFloatField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeInteger) {
        field = [BKIntegerField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeLabel) {
        field = [BKLabelField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypePassword) {
        field = [BKPasswordTextField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeBoolean) {
        field = [BKSwitchField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeSaveButton) {
        field = [BKSaveButtonField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeButton) {
        field = [BKButtonField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeSelect ||
               type == BKFormAttributeMappingTypeTimePicker ||
               type == BKFormAttributeMappingTypeDatePicker ||
               type == BKFormAttributeMappingTypeDateTimePicker) {
        field = [BKLabelField cellForTableView:self.tableView];
        
    } else if (type == BKFormAttributeMappingTypeBigText) {
        field = [BKBigTextField cellForTableView:self.tableView];
        
    } else {
        field = [BKLabelField cellForTableView:self.tableView];
    }
    
    return field;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)convertValueIfneeded:(id)value attributeMapping:(BKFormAttributeMapping *)attributeMapping {
    id convertedValue = value;
    
    if (attributeMapping.type == BKFormAttributeMappingTypeInteger) {
        NSInteger integerValue = [(NSNumber *)value integerValue];
        convertedValue = [NSString stringWithFormat:@"%d", integerValue];
        
    } else if (attributeMapping.type == BKFormAttributeMappingTypeFloat) {
        float floatValue = [(NSNumber *)value floatValue];
        convertedValue = [NSString stringWithFormat:@"%d", floatValue];
        
    } else if (attributeMapping.type == BKFormAttributeMappingTypeDateTimePicker ||
               attributeMapping.type == BKFormAttributeMappingTypeDatePicker ||
               attributeMapping.type == BKFormAttributeMappingTypeTimePicker) {
        
        if (nil != attributeMapping.dateFormat) {
            convertedValue = [self formattedStringDate:value usingFormat:attributeMapping.dateFormat];
        } else if (nil != attributeMapping.dateFormatBlock) {
            NSString *dataFormat = attributeMapping.dateFormatBlock();
            convertedValue = [self formattedStringDate:value usingFormat:dataFormat];
        } else {
            convertedValue = [value description];
        }
        
    }
    
    return convertedValue;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (Class)classFromSourcePropertyAtIndexPath:(NSIndexPath *)indexPath keyPath:(NSString *)keyPath {
    return [NSObject class]; // Unused at the moment
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)valueOfObjectForKeyPath:(NSString *)keyPath {
    id value = nil;
    
    @try {
        value = [self.object valueForKeyPath:keyPath];
    }
    @catch (NSException *exception) {
        NSLog(@"Error BaseKitFormMapping keyPath %@ doesn't exist for object name %@",
              keyPath, NSStringFromClass([self.object class]));
        
        value = nil;
    }
    
    return value;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSIndexPath *)indexPathOfAttributeMapping:(BKFormAttributeMapping *)attributeMapping {
    __block NSUInteger sectionIndex = 0;
    __block NSUInteger rowIndex = 0;
    __block BOOL found = NO;
    
    [self.sections enumerateObjectsUsingBlock:^(NSArray *sectionAttributeMappings, NSUInteger currentSectionIndex, BOOL *stop) {
        [sectionAttributeMappings enumerateObjectsUsingBlock:^(id obj, NSUInteger currentAttributeMappingIndex, BOOL *stop) {
            if (obj == attributeMapping) {
                sectionIndex = currentSectionIndex;
                rowIndex = currentAttributeMappingIndex;
                *stop = YES;
            }
        }];
        
        if (found) {
            *stop = YES;
        }
    }];
    
    return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)splitFieldsIntoSections {
    NSMutableArray *titles = [[NSMutableArray alloc] init];
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    
    [self.formMapping.fieldsOrder enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger idx, BOOL *stop) {
        if ([self.formMapping.sectionTitles containsObjectForKey:identifier]) {
            [titles addObject:[self.formMapping.sectionTitles objectForKey:identifier]];
            [sections addObject:[NSMutableArray array]];
        } else if ([self.formMapping.attributeMappings containsObjectForKey:identifier]) {
            NSMutableArray *currentSection = [sections lastObject];
            [currentSection addObject:[self.formMapping.attributeMappings objectForKey:identifier]];
        }
    }];
    
    self.titles = [NSArray arrayWithArray:titles];
    self.sections = [NSArray arrayWithArray:sections];
    
    BK_RELEASE(titles);
    BK_RELEASE(sections);
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIEvent


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)switchFieldValueDidChange:(UISwitch *)sender {
    [self setValue:[NSNumber numberWithBool:sender.isOn] forAttributeMapping:sender.formAttributeMapping];
    [self.formModel reloadRowWithAttributeMapping:sender.formAttributeMapping];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITextFieldDelegate


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self setValue:textField.text forAttributeMapping:textField.formAttributeMapping];
    [self.formModel reloadRowWithAttributeMapping:textField.formAttributeMapping];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITextViewDelegate


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidEndEditing:(UITextView *)textView {
    [self setValue:textView.text forAttributeMapping:textView.formAttributeMapping];
    [self.formModel reloadRowWithAttributeMapping:textView.formAttributeMapping];
}


@end

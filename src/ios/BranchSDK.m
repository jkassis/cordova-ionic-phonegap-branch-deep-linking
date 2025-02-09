//
//  BranchSDK.m
//  Cordova-Ionic-PhoneGap-Deferred-Deep-Linking-SDK
//
//  Copyright © 2016 Branch Metrics. All rights reserved.
//

#import "BranchSDK.h"
#import "FBSDKAppLinkUtility.h"

@interface BranchSDK()

- (void)doShareLinkResponse:(int)callbackId sendResponse:(NSDictionary*)response;

@end

@implementation BranchSDK

- (void)pluginInitialize
{
    self.branchUniversalObjArray = [[NSMutableArray alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postUnhandledURL:) name:@"BSDKPostUnhandledURL" object:nil];
}

#pragma mark - Private APIs
#pragma mark - Global Instance Accessors

- (Branch *)getInstance
{
    return [Branch getInstance];
}

- (Branch *)getInstance:(NSString *)branchKey
{
    if (branchKey) {
        return [Branch getInstance:branchKey];
    }
    else {
        return [Branch getInstance];
    }
}

- (Branch *)getTestInstance
{
    return [Branch getTestInstance];
}

#pragma mark - Deep Linking Handlers

- (id)handleDeepLink:(CDVInvokedUrlCommand*)command
{
    NSString *arg = [command.arguments objectAtIndex:0];
    NSURL *url = [NSURL URLWithString:arg];

    Branch *branch = [self getInstance];
    return [NSNumber numberWithBool:[branch handleDeepLink:url]];
}

- (void)continueUserActivity:(CDVInvokedUrlCommand*)command
{

    NSString *activityType = (NSString *)[command.arguments objectAtIndex:0];
    NSDictionary *userInfo = (NSDictionary*)[command.arguments objectAtIndex:1];

    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:activityType];
    [userActivity setUserInfo:userInfo];

    Branch *branch = [self getInstance];

    [branch continueUserActivity:userActivity];
}

#pragma mark - Public APIs
#pragma mark - Branch Basic Methods

- (void)initSession:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];
    
    [branch registerFacebookDeepLinkingClass:[FBSDKAppLinkUtility class]];

    [branch initSessionWithLaunchOptions:nil andRegisterDeepLinkHandler:^(NSDictionary *params, NSError *error) {

        BOOL isFromBranchLink = NO;
        NSString *resultString = nil;
        CDVPluginResult *pluginResult = nil;

        // NOTE: For Universal Links. Using clicked_branch_link key as condition at the moment to identify if block is run due to Universal Links.
        isFromBranchLink = [[params objectForKey:@"+clicked_branch_link"] boolValue];

        if (!error) {
            if (params != nil && [params count] > 0 && isFromBranchLink) {
 
                NSError *err;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&err];

                if (!jsonData) {
                    NSLog(@"Parsing Error: %@", [err localizedDescription]);
                    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:[err localizedDescription], @"error", nil];
                    NSData* errorJSON = [NSJSONSerialization dataWithJSONObject:errorDict
                                                                        options:NSJSONWritingPrettyPrinted
                                                                          error:&err];

                    resultString = [[NSString alloc] initWithData:errorJSON encoding:NSUTF8StringEncoding];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:resultString];
                } else {
                    resultString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
                }
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:FALSE];
            }
        }
        else {
            NSLog(@"Init Error: %@", [error localizedDescription]);

            // We create a JSON string result, because we're getting an error if we directly return a string result.
            NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:[error localizedDescription], @"error", nil];
            NSData* errorJSON = [NSJSONSerialization dataWithJSONObject:errorDict
                                                                options:NSJSONWritingPrettyPrinted
                                                                  error:&error];

            resultString = [[NSString alloc] initWithData:errorJSON encoding:NSUTF8StringEncoding];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:resultString];
        }

        if (isFromBranchLink) {
            [self.commandDelegate evalJs:[NSString stringWithFormat:@"DeepLinkHandler(%@)", resultString]];
        }

        if (command != nil) {
            [self.commandDelegate sendPluginResult: pluginResult callbackId: command.callbackId];
        }
    }];
}

- (void)setDebug:(CDVInvokedUrlCommand*)command
{
    bool enableDebug = [[command.arguments objectAtIndex:0] boolValue] == YES;
    if (enableDebug) {
        [[Branch getInstance] setDebug];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:enableDebug];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getAutoInstance:(CDVInvokedUrlCommand*)command
{
    [self initSession:nil];
}

- (void)getLatestReferringParams:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];
    NSDictionary *sessionParams = [branch getLatestReferringParams];

    CDVPluginResult* pluginResult = nil;

    if (sessionParams != nil && [sessionParams count] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sessionParams];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:FALSE];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getFirstReferringParams:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];
    NSDictionary *installParams = [branch getFirstReferringParams];

    CDVPluginResult* pluginResult = nil;

    if (installParams != nil && [installParams count] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:installParams];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:FALSE];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setIdentity:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];

    [branch setIdentity:[command.arguments objectAtIndex:0] withCallback:^(NSDictionary *params, NSError *error) {

        CDVPluginResult* pluginResult = nil;
        if (!error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
        }
        else {
            
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)registerDeepLinkController:(CDVInvokedUrlCommand*)command
{
    UIViewController<BranchDeepLinkingController> *controller = (UIViewController<BranchDeepLinkingController>*)self.viewController;
    Branch *branch = [self getInstance];
    [branch registerDeepLinkController:controller forKey:[command.arguments objectAtIndex:0]];
}

- (void)userCompletedAction:(CDVInvokedUrlCommand*)command
{
    NSString *name;
    NSDictionary *state;
    // if a state dictionary is passed as an argument
    if ([command.arguments count] == 2) {
        name = [command.arguments objectAtIndex:0];
        state = [command.arguments objectAtIndex:1];
    }
    else {
        name = (NSString *)command.arguments;
    }

    Branch *branch = [self getInstance];

    if (state) {
        [branch userCompletedAction:name withState:state];
    }
    else {
        [branch userCompletedAction:name];
    }

    // TODO: need to resolve according to result of userCompletedAction, but no callback version of the method is exposed.
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"Success"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)logout:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];
    [branch logoutWithCallback:^(BOOL changed, NSError *error) {
        CDVPluginResult *pluginResult = nil;
        if (!error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:changed];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    self.branchUniversalObjArray = [[NSMutableArray alloc] init];
}

#pragma mark - Branch Referral Reward System

- (void)loadRewards:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];

    [branch loadRewardsWithCallback:^(BOOL changed, NSError *error) {

        CDVPluginResult* pluginResult = nil;
        if(!error) {
            int credits = (int)[branch getCredits];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:credits];
        }
        else {
            NSLog(@"Load Rewards Error: %@", [error localizedDescription]);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)redeemRewards:(CDVInvokedUrlCommand*)command
{

    NSInteger amount = ((NSNumber *)[command.arguments objectAtIndex:0]).integerValue;
    Branch *branch = [self getInstance];

    if ([command.arguments count] == 2) {

        NSString *bucket = [command.arguments objectAtIndex:1];

        [branch redeemRewards:(NSInteger)amount forBucket:(NSString *)bucket callback:^(BOOL changed, NSError *error) {
            CDVPluginResult* pluginResult = nil;
            if (!error) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:changed];
            }
            else {
                NSLog(@"Redeem Rewards Error: %@", [error localizedDescription]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        [branch redeemRewards:amount callback:^(BOOL changed, NSError *error) {
            CDVPluginResult* pluginResult = nil;
            if (!error) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:changed];
            }
            else {
                NSLog(@"Redeem Rewards Error: %@", [error localizedDescription]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }
}

- (void)getCreditHistory:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];

    [branch getCreditHistoryWithCallback:^(NSArray *list, NSError *error) {
        CDVPluginResult* pluginResult = nil;
        if (!error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:list];
        }
        else {
            NSLog(@"Credit History Error: %@", [error localizedDescription]);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

#pragma mark - Branch Universal Object Methods

- (void)createBranchUniversalObject:(CDVInvokedUrlCommand*)command
{
    NSDictionary *properties = [command.arguments objectAtIndex:0];
    BranchUniversalObject *branchUniversalObj = [[BranchUniversalObject alloc] init];

    for (id key in properties) {
        if ([key isEqualToString:@"contentMetadata"]){
            NSDictionary *metadata = (NSDictionary *)[properties valueForKey:key];

            for (id key_ in metadata) {
                [branchUniversalObj addMetadataKey:key_ value:[metadata valueForKey:key_]];
            }
        }
        else if ([key isEqualToString:@"contentIndexingMode"]) {
            NSString *indexingMode = [properties valueForKey:key];
            // Default contentIndexMode is always public
            if ([indexingMode isEqualToString:@"private"]) {
                branchUniversalObj.contentIndexMode = ContentIndexModePrivate;
            }
            else {
                branchUniversalObj.contentIndexMode = ContentIndexModePublic;
            }
        }
        else if ([key isEqualToString:@"canonicalIdentifier"]) {
            branchUniversalObj.canonicalIdentifier = [properties valueForKey:key];
        }
        else if ([key isEqualToString:@"title"]) {
            branchUniversalObj.title = [properties valueForKey:key];
        }
        else if ([key isEqualToString:@"contentDescription"]) {
            branchUniversalObj.contentDescription = [properties valueForKey:key];
        }
        else if ([key isEqualToString:@"contentImageUrl"]){
            NSString *imageUrl = [properties valueForKey:key];
            branchUniversalObj.imageUrl = imageUrl;
        }
        else {
            [branchUniversalObj setValue:[properties objectForKey:key] forKey:key];
        }
    }

    // [self.branchUniversalObjArray addObject:branchUniversalObj];

    // Instantiate callback ids
    NSMutableDictionary *branchUniversalObjDict = [NSMutableDictionary dictionaryWithDictionary:@{
        @"branchUniversalObj": branchUniversalObj,
        @"onShareSheetDismissed": command.callbackId,
        @"onShareSheetLaunched": command.callbackId,
        @"onLinkShareResponse": command.callbackId,
        @"onChannelSelected": command.callbackId
    }];
    [self.branchUniversalObjArray addObject:branchUniversalObjDict];

    NSNumber *branchUniversalObjectId = [[NSNumber alloc] initWithInteger:([self.branchUniversalObjArray count] - 1)];
    NSString *message = @"createBranchUniversalObject Success";
    NSDictionary *params = [[NSDictionary alloc] initWithObjectsAndKeys:message, @"message", branchUniversalObjectId, @"branchUniversalObjectId", nil];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registerView:(CDVInvokedUrlCommand*)command
{
    int branchUniversalObjectId = [[command.arguments objectAtIndex:0] intValue];
    
    NSMutableDictionary *branchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:branchUniversalObjectId];
    BranchUniversalObject *branchUniversalObj = [branchUniversalObjDict objectForKey:@"branchUniversalObj"];

    [branchUniversalObj registerViewWithCallback:^(NSDictionary *params, NSError *error) {
        CDVPluginResult *pluginResult = nil;
        if (!error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)generateShortUrl:(CDVInvokedUrlCommand*)command
{

    int branchUniversalObjectId = [[command.arguments objectAtIndex:0] intValue];
    NSDictionary *arg1 = [command.arguments objectAtIndex:1];
    NSDictionary *arg2 = [command.arguments objectAtIndex:2];

    NSMutableDictionary *branchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:branchUniversalObjectId];
    BranchUniversalObject *branchUniversalObj = [branchUniversalObjDict objectForKey:@"branchUniversalObj"];

    BranchLinkProperties *props = [[BranchLinkProperties alloc] init];

    for (id key in arg1) {
        if ([key isEqualToString:@"duration"]) {
            props.matchDuration = (NSUInteger)[((NSNumber *)[arg1 objectForKey:key]) integerValue];
        }
        else if ([key isEqualToString:@"feature"]) {
            props.feature = [arg1 objectForKey:key];
        }
        else if ([key isEqualToString:@"stage"]) {
            props.stage = [arg1 objectForKey:key];
        }
        else if ([key isEqualToString:@"alias"]) {
            props.alias = [arg1 objectForKey:key];
        }
        else if ([key isEqualToString:@"channel"]) {
            props.channel = [arg1 objectForKey:key];
        }
        else if ([key isEqualToString:@"tags"] && [[arg1 objectForKey:key] isKindOfClass:[NSArray class]]) {
            props.tags = [arg1 objectForKey:key];
        }
    }
    if (arg2) {
        for (id key in arg2) {
            [props addControlParam:key withValue:[arg2 objectForKey:key]];
        }
    }

    [branchUniversalObj getShortUrlWithLinkProperties:props andCallback:^(NSString *url, NSError *error) {
        CDVPluginResult* pluginResult = nil;
        if (!error) {
            NSError *err;
            NSDictionary *jsonObj = [[NSDictionary alloc] initWithObjectsAndKeys:url, @"url", 0, @"options", &err, @"error", nil];

            if (!jsonObj) {
                NSLog(@"Parsing Error: %@", [err localizedDescription]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[err localizedDescription]];
            } else {
                NSLog(@"Success");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonObj];
            }
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)showShareSheet:(CDVInvokedUrlCommand*)command
{
    NSString *shareText = @"Share Link";

    if ([command.arguments count] >= 4) {
        shareText = [command.arguments objectAtIndex:3];
    }

    int branchUniversalObjectId = [[command.arguments objectAtIndex:0] intValue];
    NSDictionary *arg1 = [command.arguments objectAtIndex:1];
    NSDictionary *arg2 = [command.arguments objectAtIndex:2];

    NSMutableDictionary *branchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:branchUniversalObjectId];
    BranchUniversalObject *branchUniversalObj = [branchUniversalObjDict objectForKey:@"branchUniversalObj"];

    BranchLinkProperties *linkProperties = [[BranchLinkProperties alloc] init];

    for (id key in arg1) {
        if ([key isEqualToString:@"duration"]) {
            linkProperties.matchDuration = (NSUInteger)[((NSNumber *)[arg1 objectForKey:key]) integerValue];
        }
        else {
            [linkProperties setValue:[arg1 objectForKey:key] forKey:key];
        }
    }

    if (arg2) {
        for (id key in arg2) {
            [linkProperties addControlParam:key withValue:[arg2 objectForKey:key]];
        }
    }

    [branchUniversalObj showShareSheetWithLinkProperties:linkProperties
                                                andShareText:shareText
                                                fromViewController:self.viewController
                                                completion:^(NSString *activityType, BOOL completed) {

        int listenerCallbackId = [[command.arguments objectAtIndex:0] intValue];
        
        if (completed) {
            NSLog(@"Share link complete");
            [branchUniversalObj getShortUrlWithLinkProperties:linkProperties andCallback:^(NSString *url, NSError *error) {
                if (!error) {
                    NSDictionary *response = [[NSDictionary alloc] initWithObjectsAndKeys:url, @"sharedLink", activityType, @"sharedChannel", nil];
                    [self doShareLinkResponse:listenerCallbackId sendResponse:response];
                }
            }];
        }
        
        CDVPluginResult *shareDialogDismissed = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

        NSMutableDictionary *branchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:listenerCallbackId];

        [shareDialogDismissed setKeepCallbackAsBool:TRUE];

        [self.commandDelegate sendPluginResult:shareDialogDismissed callbackId:[branchUniversalObjDict objectForKey:@"onShareSheetDismissed"]];
    }];
}

- (void)doShareLinkResponse:(int)callbackId sendResponse:(NSDictionary*)response {
    CDVPluginResult *linkShareResponse = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
    NSMutableDictionary *branchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:callbackId];

    [linkShareResponse setKeepCallbackAsBool:TRUE];

    [self.commandDelegate sendPluginResult:linkShareResponse callbackId:[branchUniversalObjDict objectForKey:@"onLinkShareResponse"]];
}

- (void)onShareLinkDialogDismissed:(CDVInvokedUrlCommand*)command
{
    int listenerCallbackId = [[command.arguments objectAtIndex:0] intValue];

    NSMutableDictionary *newBranchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:listenerCallbackId];
    [newBranchUniversalObjDict setObject:command.callbackId forKey:@"onShareSheetDismissed"];

    [self.branchUniversalObjArray replaceObjectAtIndex:listenerCallbackId withObject:newBranchUniversalObjDict];
}

- (void)onLinkShareResponse:(CDVInvokedUrlCommand*)command
{
    int listenerCallbackId = [[command.arguments objectAtIndex:0] intValue];

    NSMutableDictionary *newBranchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:listenerCallbackId];
    [newBranchUniversalObjDict setObject:command.callbackId forKey:@"onLinkShareResponse"];

    [self.branchUniversalObjArray replaceObjectAtIndex:listenerCallbackId withObject:newBranchUniversalObjDict];
}

- (void)listOnSpotlight:(CDVInvokedUrlCommand*)command {
    int branchUniversalObjectId = [[command.arguments objectAtIndex:0] intValue];

    NSMutableDictionary *branchUniversalObjDict = [self.branchUniversalObjArray objectAtIndex:branchUniversalObjectId];
    BranchUniversalObject *branchUniversalObj = [branchUniversalObjDict objectForKey:@"branchUniversalObj"];

    [branchUniversalObj listOnSpotlightWithCallback:^(NSString *string, NSError *error) {
        CDVPluginResult* pluginResult = nil;
        if (!error) {
            NSError *err;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"result":string}
                                                               options:0
                                                                 error:&err];
            if (!jsonData) {
                NSLog(@"Parsing Error: %@", [err localizedDescription]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[err localizedDescription]];
            } else {
                NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
            }
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

#pragma mark - Private Methods
- (void)postUnhandledURL:(NSNotification *)notification {
    // We create a JSON string result, because we're unable to handle the url. We will include the url in the return string.
    NSError *error;
    NSString *urlString;

    if ([notification.object respondsToSelector:@selector(absoluteString:)]) {
        urlString = [notification.object absoluteString];
    } else {
        urlString = notification.object;
    }

    if ([urlString isKindOfClass:[NSString class]]) {
        NSDictionary *returnDict = [NSDictionary dictionaryWithObjectsAndKeys:@"Unable to process URL", @"error", urlString, @"url", nil];
        NSData* returnJSON = [NSJSONSerialization dataWithJSONObject:returnDict
                                                             options:NSJSONWritingPrettyPrinted
                                                               error:&error];

        NSString *resultString = [[NSString alloc] initWithData:returnJSON encoding:NSUTF8StringEncoding];
        [self.commandDelegate evalJs:[NSString stringWithFormat:@"NonBranchLinkHandler(%@)", resultString]];
    }
}

#pragma mark - URL Methods (not fully implemented YET!)

- (NSString *)getShortURL:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];
    return [branch getShortURL];
}

- (id)getShortURLWithParams:(CDVInvokedUrlCommand*)command
{
    Branch *branch = [self getInstance];
    NSDictionary *params = [command.arguments objectAtIndex:0];

    return [branch getShortURLWithParams:params];
}

- (NSString *)getLongURLWithParams:(CDVInvokedUrlCommand*)command
{
    id params = [command.arguments objectAtIndex:0];
    return [[self getInstance] getLongURLWithParams:params];
}

- (NSString *)getContentUrlWithParams:(CDVInvokedUrlCommand*)command
{
    NSDictionary *params = [command.arguments objectAtIndex:0];
    NSString *channel = [command.arguments objectAtIndex:1];

    Branch *branch = [self getInstance];
    return [branch getContentUrlWithParams:params andChannel:channel];
}

- (void)getBranchActivityItemWithParams:(CDVInvokedUrlCommand*)command
{
    UIActivityItemProvider *provider = [Branch getBranchActivityItemWithParams:[command.arguments objectAtIndex:0]];

    UIActivityViewController *shareViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ provider ] applicationActivities:nil];

    [self.viewController presentViewController:shareViewController animated:YES completion:nil];
}

@end

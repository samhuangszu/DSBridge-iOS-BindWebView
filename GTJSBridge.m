//
//  GTJSBridge.m
//  GTKit
//
//  Created by sam on 2020/7/9.
//  Copyright © 2020 GoIoT. All rights reserved.
//
#import "GTJSBridge.h"
#import "GTJSBUtil.h"
#import "GTDSCallInfo.h"
#import "GTInternalApis.h"
#import <objc/message.h>
@interface GTJSBridge()
@property (nonatomic, weak) WKWebView *webView;
@end

@implementation GTJSBridge
{
    int callId;
    bool jsDialogBlock;
    NSMutableDictionary<NSString *,id> *javaScriptNamespaceInterfaces;
    NSMutableDictionary *handerMap;
    NSMutableArray<GTDSCallInfo *> * callInfoList;
    UInt64 lastCallTime ;
    NSString *jsCache;
    bool isPending;
    bool isDebug;
}

#pragma mark - Public
+ (instancetype)bindWithWebView:(WKWebView *)webView {
    if ([webView isKindOfClass:[WKWebView class]]) {
        GTJSBridge *bridge = [[self alloc] initBridgeWithWebView:webView];
        return bridge;
    }
    [NSException raise:@"BadWebView" format:@"Unknown web view."];
    return nil;
}

-(instancetype)initBridgeWithWebView:(WKWebView *)webView
{
    if (self = [super init]) {
        self.webView = webView;
        callId=0;
        jsDialogBlock=true;
        callInfoList=[NSMutableArray array];
        javaScriptNamespaceInterfaces=[NSMutableDictionary dictionary];
        handerMap=[NSMutableDictionary dictionary];
        lastCallTime = 0;
        jsCache=@"";
        isPending=false;
        isDebug=false;

        WKWebViewConfiguration *webViewConfiguration = webView.configuration;
        if (webViewConfiguration && !webViewConfiguration.userContentController) {
            webView.configuration.userContentController = [WKUserContentController new];
        }
        WKUserScript *script = [[WKUserScript alloc] initWithSource:@"window._dswk=true;"
           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:YES];
        [webView.configuration.userContentController addUserScript:script];
        // add internal Javascript Object
        GTInternalApis * interalApis= [[GTInternalApis alloc] init];
        interalApis.bridge= self;
        [self addJavascriptObject:interalApis namespace:@"_dsb"];
    }
    return self;
}

- (void)evalJavascript:(int) delay{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        @synchronized(self){
            if([jsCache length]!=0){
                [self.webView evaluateJavaScript :jsCache completionHandler:nil];
                isPending=false;
                jsCache=@"";
                lastCallTime=[[NSDate date] timeIntervalSince1970]*1000;
            }
        }
    });
}

-(NSString *)call:(NSString*)method argStr:(NSString*)argStr
{
    NSArray *nameStr=[GTJSBUtil parseNamespace:[method stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

    id JavascriptInterfaceObject=javaScriptNamespaceInterfaces[nameStr[0]];
    NSString *error=[NSString stringWithFormat:@"Error! \n Method %@ is not invoked, since there is not a implementation for it",method];
    NSMutableDictionary*result =[NSMutableDictionary dictionaryWithDictionary:@{@"code":@-1,@"data":@""}];
    if(!JavascriptInterfaceObject){
        NSLog(@"Js bridge  called, but can't find a corresponded JavascriptObject , please check your code!");
    }else{
        method=nameStr[1];
        NSString *methodOne = [GTJSBUtil methodByNameArg:1 selName:method class:[JavascriptInterfaceObject class]];
        NSString *methodTwo = [GTJSBUtil methodByNameArg:2 selName:method class:[JavascriptInterfaceObject class]];
        SEL sel=NSSelectorFromString(methodOne);
        SEL selasyn=NSSelectorFromString(methodTwo);
        NSDictionary * args=[GTJSBUtil jsonStringToObject:argStr];
        id arg=args[@"data"];
        if(arg==[NSNull null]){
            arg=nil;
        }
        NSString * cb;
        do{
            if(args && (cb= args[@"_dscbstub"])){
                if([JavascriptInterfaceObject respondsToSelector:selasyn]){
                    __weak typeof(self) weakSelf = self;
                    void (^completionHandler)(id,BOOL) = ^(id value,BOOL complete){
                        NSString *del=@"";
                        result[@"code"]=@0;
                        if(value!=nil){
                            result[@"data"]=value;
                        }
                        value=[GTJSBUtil objToJsonString:result];
                        value=[value stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
                        
                        if(complete){
                            del=[@"delete window." stringByAppendingString:cb];
                        }
                        NSString*js=[NSString stringWithFormat:@"try {%@(JSON.parse(decodeURIComponent(\"%@\")).data);%@; } catch(e){};",cb,(value == nil) ? @"" : value,del];
                        __strong typeof(self) strongSelf = weakSelf;
                        @synchronized(self)
                        {
                            UInt64  t=[[NSDate date] timeIntervalSince1970]*1000;
                            jsCache=[jsCache stringByAppendingString:js];
                            if(t-lastCallTime<50){
                                if(!isPending){
                                    [strongSelf evalJavascript:50];
                                    isPending=true;
                                }
                            }else{
                                [strongSelf evalJavascript:0];
                            }
                        }
                        
                    };
                    void(*action)(id,SEL,id,id) = (void(*)(id,SEL,id,id))objc_msgSend;
                    action(JavascriptInterfaceObject,selasyn,arg,completionHandler);
                    break;
                }
            }else if([JavascriptInterfaceObject respondsToSelector:sel]){
                id ret;
                id(*action)(id,SEL,id) = (id(*)(id,SEL,id))objc_msgSend;
                ret=action(JavascriptInterfaceObject,sel,arg);
                [result setValue:@0 forKey:@"code"];
                if(ret!=nil){
                    [result setValue:ret forKey:@"data"];
                }
                break;
            }
            NSString*js=[error stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
            if(isDebug){
                js=[NSString stringWithFormat:@"window.alert(decodeURIComponent(\"%@\"));",js];
                [self.webView evaluateJavaScript :js completionHandler:nil];
            }
            NSLog(@"%@",error);
        }while (0);
    }
    return [GTJSBUtil objToJsonString:result];
}

- (void)setDebugMode:(bool)debug{
    isDebug=debug;
}


- (void)callHandler:(NSString *)methodName arguments:(NSArray *)args{
    [self callHandler:methodName arguments:args completionHandler:nil];
}

- (void)callHandler:(NSString *)methodName completionHandler:(void (^)(id _Nullable))completionHandler{
    [self callHandler:methodName arguments:nil completionHandler:completionHandler];
}

-(void)callHandler:(NSString *)methodName arguments:(NSArray *)args completionHandler:(void (^)(id  _Nullable value))completionHandler
{
    GTDSCallInfo *callInfo=[[GTDSCallInfo alloc] init];
    callInfo.id=[NSNumber numberWithInt: callId++];
    callInfo.args=args==nil?@[]:args;
    callInfo.method=methodName;
    if(completionHandler){
        [handerMap setObject:completionHandler forKey:callInfo.id];
    }
    if(callInfoList!=nil){
        [callInfoList addObject:callInfo];
    }else{
        [self dispatchJavascriptCall:callInfo];
    }
    [self dispatchJavascriptCall:callInfo];

}

- (void)dispatchStartupQueue{
    if(callInfoList==nil) return;
    for (GTDSCallInfo * callInfo in callInfoList) {
        [self dispatchJavascriptCall:callInfo];
    }
    callInfoList=nil;
}

- (void)dispatchJavascriptCall:(GTDSCallInfo*) info{
    NSString * json=[GTJSBUtil objToJsonString:@{@"method":info.method,@"callbackId":info.id,
                                               @"data":[GTJSBUtil objToJsonString: info.args]}];
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"window._handleMessageFromNative(%@)",json]
           completionHandler:nil];
}

- (void)addJavascriptObject:(id)object namespace:(NSString *)namespace{
    if(namespace==nil){
        namespace=@"";
    }
    if(object!=NULL){
        [javaScriptNamespaceInterfaces setObject:object forKey:namespace];
    }
}

- (void)removeJavascriptObject:(NSString *)namespace {
    if(namespace==nil){
        namespace=@"";
    }
    [javaScriptNamespaceInterfaces removeObjectForKey:namespace];
}

- (id)onMessage:(NSDictionary *)msg type:(int)type{
    id ret=nil;
    switch (type) {
        case DSB_API_HASNATIVEMETHOD:
            ret= [self hasNativeMethod:msg]?@1:@0;
            break;
        case DSB_API_CLOSEPAGE:
            [self closePage:msg];
            break;
        case DSB_API_RETURNVALUE:
            ret=[self returnValue:msg];
            break;
        case DSB_API_DSINIT:
            ret=[self dsinit:msg];
            break;
        case DSB_API_DISABLESAFETYALERTBOX:
            [self disableJavascriptDialogBlock:[msg[@"disable"] boolValue]];
            break;
        default:
            break;
    }
    return ret;
}

- (bool)hasNativeMethod:(NSDictionary *) args
{
    NSArray *nameStr=[GTJSBUtil parseNamespace:[args[@"name"]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    NSString * type= [args[@"type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    id JavascriptInterfaceObject= [javaScriptNamespaceInterfaces objectForKey:nameStr[0]];
    if(JavascriptInterfaceObject){
        bool syn=[GTJSBUtil methodByNameArg:1 selName:nameStr[1] class:[JavascriptInterfaceObject class]]!=nil;
        bool asyn=[GTJSBUtil methodByNameArg:2 selName:nameStr[1] class:[JavascriptInterfaceObject class]]!=nil;
        if(([@"all" isEqualToString:type]&&(syn||asyn))
           ||([@"asyn" isEqualToString:type]&&asyn)
           ||([@"syn" isEqualToString:type]&&syn)
           ){
            return true;
        }
    }
    return false;
}

- (id)closePage:(NSDictionary *) args{
    return nil;
}

- (id)returnValue:(NSDictionary *) args{
    void (^ completionHandler)(NSString *  _Nullable)= handerMap[args[@"id"]];
    if(completionHandler){
        if(isDebug){
            completionHandler(args[@"data"]);
        }else{
            @try{
                completionHandler(args[@"data"]);
            }@catch (NSException *e){
                NSLog(@"%@",e);
            }
        }
        if([args[@"complete"] boolValue]){
            [handerMap removeObjectForKey:args[@"id"]];
        }
    }
    return nil;
}

- (id)dsinit:(NSDictionary *) args{
    [self dispatchStartupQueue];
    return nil;
}

- (void)disableJavascriptDialogBlock:(bool) disable{
    jsDialogBlock=!disable;
}

- (void)hasJavascriptMethod:(NSString *)handlerName methodExistCallback:(void (^)(bool exist))callback{
    [self callHandler:@"_hasJavascriptMethod" arguments:@[handlerName] completionHandler:^(NSNumber* _Nullable value) {
        callback([value boolValue]);
    }];
}
#pragma mark - GTJSBridgeDelegate methods
- (BOOL)handlePrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText completionHandler:(void (^)(NSString * _Nullable result))completionHandler{
    NSString * prefix=@"_dsbridge=";
    if ([prompt hasPrefix:prefix])
    {
        NSString *method= [prompt substringFromIndex:[prefix length]];
        NSString *result=nil;
        if(isDebug){
            result =[self call:method argStr:defaultText];
        }else{
            @try {
                result =[self call:method argStr:defaultText];
            }@catch(NSException *exception){
                NSLog(@"%@", exception);
            }
        }
        if (completionHandler!=nil ) {
            completionHandler(result);
        }
        return true;
    }
    return false;
}

@end

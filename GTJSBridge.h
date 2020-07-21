//
//  GTJSBridge.h
//  GTKit
//
//  Created by sam on 2020/7/9.
//  Copyright © 2020 GoIoT. All rights reserved.
//
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^JSCallback)(NSString * _Nullable result,BOOL complete);

@interface GTJSBridge : NSObject

/**
 初始化绑定方法
 
 @param webView webView
 @return bridge
 */
+(instancetype)bindWithWebView:(WKWebView *)webView;

- (BOOL)handlePrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText completionHandler:(void (^)(NSString * _Nullable result))completionHandler;

// Call javascript handler
-(void)callHandler:(NSString * _Nonnull) methodName  arguments:(NSArray * _Nullable)args;
-(void)callHandler:(NSString * _Nonnull) methodName  completionHandler:(void (^ _Nullable)(id _Nullable value))completionHandler;
-(void)callHandler:(NSString * _Nonnull) methodName  arguments:(NSArray * _Nullable) args completionHandler:(void (^ _Nullable)(id _Nullable value))completionHandler;

/**
 * Add a Javascript Object to dsBridge with namespace.
 * @param object
 * which implemented the javascript interfaces
 * @param namespace
 * if empty, the object have no namespace.
 **/
- (void)addJavascriptObject:(id _Nullable ) object namespace:(NSString *  _Nullable) namespace;

// Remove the Javascript Object with the supplied namespace
- (void)removeJavascriptObject:(NSString *  _Nullable) namespace;

// Test whether the handler exist in javascript
- (void)hasJavascriptMethod:(NSString * _Nonnull) handlerName methodExistCallback:(void(^ _Nullable)(bool exist))callback;

// Set debug mode. if in debug mode, some errors will be prompted by a dialog
// and the exception caused by the native handlers will not be captured.
- (void)setDebugMode:(bool) debug;

- (void)disableJavascriptDialogBlock:(bool) disable;

// private method, the developer shoudn't call this method
- (id _Nullable)onMessage:(NSDictionary *_Nonnull) msg type:(int) type;

@end

NS_ASSUME_NONNULL_END

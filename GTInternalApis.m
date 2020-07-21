#import "GTInternalApis.h"
#import "GTJSBUtil.h"

@implementation GTInternalApis
- (id) hasNativeMethod:(id) args
{
    return [self.bridge onMessage:args type: DSB_API_HASNATIVEMETHOD];
}

- (id) closePage:(id) args{
    return [self.bridge onMessage:args type:DSB_API_CLOSEPAGE];
}

- (id) returnValue:(NSDictionary *) args{
    return [self.bridge onMessage:args type:DSB_API_RETURNVALUE];
}

- (id) dsinit:(id) args{
    return [self.bridge onMessage:args type:DSB_API_DSINIT];
}

- (id) disableJavascriptDialogBlock:(id) args{
    return [self.bridge onMessage:args type:DSB_API_DISABLESAFETYALERTBOX];
}
@end

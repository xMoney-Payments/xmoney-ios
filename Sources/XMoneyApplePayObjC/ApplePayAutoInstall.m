#import <Foundation/Foundation.h>
#include <dlfcn.h>

@interface XMoneyApplePayAutoInstall : NSObject
@end

@implementation XMoneyApplePayAutoInstall
+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        typedef void (*XMoneyApplePayInstallFn)(void);
        XMoneyApplePayInstallFn install = (XMoneyApplePayInstallFn)dlsym(RTLD_DEFAULT, "XMoneyApplePayInstall");
        if (install) {
            install();
        }
    });
}
@end

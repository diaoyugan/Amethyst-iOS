#import <Foundation/Foundation.h>
#import "UIKit+hook.h"

#include "jni.h"
#include "utils.h"
#include "external/fishhook/fishhook.h"

UIViewController* currentVC() {
    return UIWindow.mainWindow.visibleViewController;
}

JNIEXPORT jlong JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1getGlobalChar(JNIEnv *__env, jclass clazz, jlong aCharVariableNameAddress) {
    return 0;
}

JNIEXPORT jint JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1getGlobalInt(JNIEnv *__env, jclass clazz, jlong aIntVariableNameAddress) {
    return -1;
}

JNIEXPORT jint JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1setGlobalInt(JNIEnv *__env, jclass clazz, jlong aIntVariableNameAddress, jint aValue) {
    return -1;
}

JNIEXPORT void JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_tinyfd_1beep(JNIEnv *__env, jclass clazz) {
    //UNUSED_PARAMS(__env, clazz)
    //tinyfd_beep();
}

JNIEXPORT jint JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1notifyPopup(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aMessageAddress, jlong aIconTypeAddress) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aMessage = (char const *)(uintptr_t)aMessageAddress;
    char const *aIconType = (char const *)(uintptr_t)aIconTypeAddress;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* title = aTitle ? @(aTitle) : @"";
        NSString* message = aMessage ? @(aMessage) : @"";
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            dispatch_group_leave(group);
        }]];
        [currentVC() presentViewController:alert animated:YES completion:nil];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return 1;
}

JNIEXPORT jint JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1messageBox(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aMessageAddress, jlong aDialogTypeAddress, jlong aIconTypeAddress, jint aDefaultButton) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aMessage = (char const *)(uintptr_t)aMessageAddress;
    char const *aDialogType = (char const *)(uintptr_t)aDialogTypeAddress;
    char const *aIconType = (char const *)(uintptr_t)aIconTypeAddress;
    
    BOOL hasOK = NO, hasCancel = NO, hasYes = NO, hasNo = NO;
    if(!strcmp(aDialogType, "ok")) {
        hasOK = YES;
    } else if(strcmp(aDialogType, "okcancel") != 0) {
        hasOK = YES;
        hasCancel = YES;
    } else if(strcmp(aDialogType, "yesno") != 0) {
        hasYes = YES;
        hasNo = YES;
    } else if(strcmp(aDialogType, "yesnocancel") != 0) {
        hasYes = YES;
        hasNo = YES;
        hasCancel = YES;
    }
    
    __block int selected = aDefaultButton;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* title = aTitle ? @(aTitle) : @"";
        NSString* message = aMessage ? @(aMessage) : @"";
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        if(hasCancel || hasNo) {
            NSString* button0Title = hasCancel ? @"Cancel" : @"No";
            [alert addAction:[UIAlertAction actionWithTitle:button0Title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                selected = 0;
                dispatch_group_leave(group);
            }]];
        }
        
        if(hasOK || hasYes) {
            NSString* button1Title = hasOK ? @"OK" : @"Yes";
            [alert addAction:[UIAlertAction actionWithTitle:button1Title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                selected = 1;
                dispatch_group_leave(group);
            }]];
        }
        
        if(hasYes && hasNo && hasCancel) {
            [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                selected = 2;
                dispatch_group_leave(group);
            }]];
        }
        
        [currentVC() presentViewController:alert animated:YES completion:nil];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return selected;
}

JNIEXPORT jlong JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1inputBox(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aMessageAddress, jlong aDefaultInputAddress) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aMessage = (char const *)(uintptr_t)aMessageAddress;
    char const *aDefaultInput = (char const *)(uintptr_t)aDefaultInputAddress;
    
    //return (jlong)(uintptr_t)tinyfd_inputBox(aTitle, aMessage, aDefaultInput);
    // TODO
    return 0;
}

JNIEXPORT jlong JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1saveFileDialog(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aDefaultPathAndFileAddress, jint aNumOfFilterPatterns, jlong aFilterPatternsAddress, jlong aSingleFilterDescriptionAddress) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aDefaultPathAndFile = (char const *)(uintptr_t)aDefaultPathAndFileAddress;
    char const * const *aFilterPatterns = (char const * const *)(uintptr_t)aFilterPatternsAddress;
    char const *aSingleFilterDescription = (char const *)(uintptr_t)aSingleFilterDescriptionAddress;
    
    //return (jlong)(uintptr_t)tinyfd_saveFileDialog(aTitle, aDefaultPathAndFile, aNumOfFilterPatterns, aFilterPatterns, aSingleFilterDescription);
    // TODO
    return 0;
}

JNIEXPORT jlong JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1openFileDialog(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aDefaultPathAndFileAddress, jint aNumOfFilterPatterns, jlong aFilterPatternsAddress, jlong aSingleFilterDescriptionAddress, jint aAllowMultipleSelects) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aDefaultPathAndFile = (char const *)(uintptr_t)aDefaultPathAndFileAddress;
    char const * const *aFilterPatterns = (char const * const *)(uintptr_t)aFilterPatternsAddress;
    char const *aSingleFilterDescription = (char const *)(uintptr_t)aSingleFilterDescriptionAddress;

    //return (jlong)(uintptr_t)tinyfd_openFileDialog(aTitle, aDefaultPathAndFile, aNumOfFilterPatterns, aFilterPatterns, aSingleFilterDescription, aAllowMultipleSelects);
    // TODO
    return 0;
}

JNIEXPORT jlong JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1selectFolderDialog(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aDefaultPathAddress) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aDefaultPath = (char const *)(uintptr_t)aDefaultPathAddress;
    
    //return (jlong)(uintptr_t)tinyfd_selectFolderDialog(aTitle, aDefaultPath);
    // TODO
    return 0;
}

JNIEXPORT jlong JNICALL Java_org_lwjgl_util_tinyfd_TinyFileDialogs_ntinyfd_1colorChooser(JNIEnv *__env, jclass clazz, jlong aTitleAddress, jlong aDefaultHexRGBAddress, jlong aDefaultRGBAddress, jlong aoResultRGBAddress) {
    char const *aTitle = (char const *)(uintptr_t)aTitleAddress;
    char const *aDefaultHexRGB = (char const *)(uintptr_t)aDefaultHexRGBAddress;
    unsigned char *aDefaultRGB = (unsigned char *)(uintptr_t)aDefaultRGBAddress;
    unsigned char *aoResultRGB = (unsigned char *)(uintptr_t)aoResultRGBAddress;
    
    //return (jlong)(uintptr_t)tinyfd_colorChooser(aTitle, aDefaultHexRGB, aDefaultRGB, aoResultRGB);
    // TODO
    return 0;
}

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include "jni.h"

@implementation AVSpeechSynthesizer(Global)
+ (instancetype)sharedInstance {
    static AVSpeechSynthesizer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [AVSpeechSynthesizer new];
    });
    return sharedInstance;
}
@end

AVSpeechSynthesizer *synthesizer;
JNIEXPORT void JNICALL Java_com_mojang_text2speech_nativeStartSpeaking(JNIEnv *env, jclass cls, jstring msg, jfloat volume) {
    const char* stringChars = (*env)->GetStringUTFChars(env, msg, NULL);
    NSString *objCString = @(stringChars);
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:objCString];
    utterance.volume = volume;
    [AVSpeechSynthesizer.sharedInstance speakUtterance:utterance];
    (*env)->ReleaseStringUTFChars(env, msg, stringChars);
}

JNIEXPORT void JNICALL Java_com_mojang_text2speech_nativeClearQueue(JNIEnv *env, jclass cls) {
    [AVSpeechSynthesizer.sharedInstance stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

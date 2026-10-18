// JNI entry point used by HackRfBridge.kt to hand USB IQ packets to the
// native pipeline without routing them through the Flutter event channel.
#include <jni.h>

#include <cstdint>

#include "mobile_bridge.h"

extern "C" JNIEXPORT void JNICALL
Java_dev_sarahsforge_iridiscope_HackRfBridge_nativeFeedIq(
        JNIEnv *env, jobject thiz, jbyteArray data) {
    (void)thiz;
    if (!data) return;

    ir_mobile_t *m = ir_mobile_default();
    if (!m) return;

    jsize len = env->GetArrayLength(data);
    if (len < 2) return;

    jbyte *buf = env->GetByteArrayElements(data, nullptr);
    if (!buf) return;
    ir_mobile_feed_i8(m, reinterpret_cast<const uint8_t *>(buf), (int)len);
    env->ReleaseByteArrayElements(data, buf, JNI_ABORT);
}

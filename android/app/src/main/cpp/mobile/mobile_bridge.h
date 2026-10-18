// C API consumed by the Flutter/Dart FFI layer.
#ifndef IRIDISCOPE_MOBILE_BRIDGE_H
#define IRIDISCOPE_MOBILE_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ir_mobile ir_mobile_t;

typedef struct {
    uint64_t samples;
    uint64_t total_samples;
    uint64_t bursts;
    uint64_t frames_ok;
    uint64_t frames_fail;
    uint64_t messages;
    uint64_t dropped_samples;
    double   elapsed_s;
    double   rate_sps;
    int      running;
    int      paused;
    int      done;
    int      fft_size;
    uint32_t sample_rate;
    double   center_hz;
    float    floor_db;
    float    peak_db;
} ir_mobile_stats_t;

ir_mobile_t *ir_mobile_create(void);
void ir_mobile_destroy(ir_mobile_t *m);
/* The most recently created instance, used by the JNI HackRF feed. */
ir_mobile_t *ir_mobile_default(void);

/* IQ file sources. open_file_fd duplicates the descriptor. */
int ir_mobile_open_file(ir_mobile_t *m, const char *path,
                        char *err, int errlen);
int ir_mobile_open_file_fd(ir_mobile_t *m, int fd, const char *display_name,
                           char *err, int errlen);

/* Push source used by HackRF (IQ is fed natively via JNI). */
int ir_mobile_open_push(ir_mobile_t *m, uint32_t center_hz,
                        uint32_t sample_rate, int fft_size, int workers);

int  ir_mobile_start(ir_mobile_t *m);
void ir_mobile_stop(ir_mobile_t *m);
void ir_mobile_pause(ir_mobile_t *m, int paused);
void ir_mobile_set_realtime(ir_mobile_t *m, int on);
void ir_mobile_seek_sample(ir_mobile_t *m, uint64_t sample);

void ir_mobile_set_frequency(ir_mobile_t *m, uint32_t hz);
void ir_mobile_set_fft_size(ir_mobile_t *m, int n);
void ir_mobile_set_avg_alpha(ir_mobile_t *m, float alpha);
void ir_mobile_set_dc_block(ir_mobile_t *m, int on);
/* Directory where finished voice calls are written as WAV files. */
void ir_mobile_set_voice_dir(ir_mobile_t *m, const char *dir);

/* Returns the current spectrum frame id, or 0 when no new frame is available. */
uint64_t ir_mobile_poll_spectrum(ir_mobile_t *m, float *inst, float *avg, int n);
int  ir_mobile_poll_events(ir_mobile_t *m, char *json, int maxlen);
void ir_mobile_get_stats(ir_mobile_t *m, ir_mobile_stats_t *out);
int  ir_mobile_file_info(ir_mobile_t *m, char *json, int maxlen);

/* Feed interleaved signed 8-bit IQ. n_bytes must be even. */
void ir_mobile_feed_i8(ir_mobile_t *m, const uint8_t *iq, int n_bytes);
/* Feed interleaved float IQ. n_floats is the number of floats (2 per sample). */
void ir_mobile_feed_cf32(ir_mobile_t *m, const float *iq, int n_floats);

#ifdef __cplusplus
}
#endif

#endif

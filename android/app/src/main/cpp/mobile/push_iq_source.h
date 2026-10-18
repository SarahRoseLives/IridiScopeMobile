// Push-based IQ source for live SDR data delivered from Android/JNI.
//
// The engine consumes samples through the pull-based IqSource interface; this
// class buffers IQ blocks in a ring until the engine worker asks for them.
#ifndef IRIDISCOPE_MOBILE_PUSH_IQ_SOURCE_H
#define IRIDISCOPE_MOBILE_PUSH_IQ_SOURCE_H

#include "core/iq_source.h"

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <vector>

namespace iridi {

class PushIqSource : public IqSource {
public:
    explicit PushIqSource(size_t cap_samples = 1u << 20);
    ~PushIqSource() override = default;

    void open(int sample_rate, double center_hz);
    void close() override;

    bool is_open() const override { return open_.load(); }
    int sample_rate() const override { return sample_rate_.load(); }
    double center_frequency() const override { return center_hz_.load(); }
    uint64_t total_samples() const override { return 0; }

    size_t read_cf32(float *out, size_t max_samples) override;
    bool done() const override { return !open_.load(); }
    void wake() override;

    // Feed interleaved signed 8-bit IQ (HackRF/RTL native format).
    void feed_i8(const uint8_t *iq, size_t n_complex);
    // Feed already-normalized interleaved float IQ.
    void feed_cf32(const float *iq, size_t n_complex);

    void set_center_frequency(double hz) { center_hz_.store(hz); }
    uint64_t dropped_samples() const { return dropped_.load(); }
    void clear();

private:
    void write_cf32_locked(const float *iq, size_t n);

    mutable std::mutex mtx_;
    std::condition_variable cv_;
    std::vector<float> ring_;
    size_t cap_ = 0;
    size_t head_ = 0;
    size_t count_ = 0;

    std::atomic<bool> open_{false};
    std::atomic<int> sample_rate_{0};
    std::atomic<double> center_hz_{0.0};
    std::atomic<uint64_t> dropped_{0};

    std::vector<float> conv_;
};

} // namespace iridi

#endif

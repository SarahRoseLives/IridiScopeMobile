#include "push_iq_source.h"

#include <algorithm>
#include <cstring>

namespace iridi {

PushIqSource::PushIqSource(size_t cap_samples)
    : cap_(cap_samples ? cap_samples : (1u << 20)) {
    ring_.resize(cap_ * 2);
}

void PushIqSource::open(int sample_rate, double center_hz) {
    {
        std::lock_guard<std::mutex> lk(mtx_);
        head_ = 0;
        count_ = 0;
    }
    sample_rate_.store(sample_rate);
    center_hz_.store(center_hz);
    dropped_.store(0);
    open_.store(true);
}

void PushIqSource::close() {
    open_.store(false);
    cv_.notify_all();
}

void PushIqSource::wake() {
    open_.store(false);
    cv_.notify_all();
}

void PushIqSource::clear() {
    std::lock_guard<std::mutex> lk(mtx_);
    head_ = 0;
    count_ = 0;
}

size_t PushIqSource::read_cf32(float *out, size_t max_samples) {
    if (!out || max_samples == 0) return 0;

    std::unique_lock<std::mutex> lk(mtx_);
    cv_.wait(lk, [this] { return count_ > 0 || !open_.load(); });
    if (count_ == 0) return 0;

    size_t n = std::min(max_samples, count_);
    size_t first = std::min(n, cap_ - head_);
    std::memcpy(out, ring_.data() + head_ * 2, first * 2 * sizeof(float));
    if (n > first) {
        std::memcpy(out + first * 2, ring_.data(),
                    (n - first) * 2 * sizeof(float));
    }
    head_ = (head_ + n) % cap_;
    count_ -= n;
    return n;
}

void PushIqSource::write_cf32_locked(const float *iq, size_t n) {
    if (n > cap_) {
        // Keep the newest cap_ samples.
        iq += (n - cap_) * 2;
        n = cap_;
        head_ = 0;
    }
    if (n > cap_ - count_) {
        size_t drop = n - (cap_ - count_);
        head_ = (head_ + drop) % cap_;
        count_ -= drop;
        dropped_.fetch_add(drop);
    }

    size_t tail = (head_ + count_) % cap_;
    size_t first = std::min(n, cap_ - tail);
    std::memcpy(ring_.data() + tail * 2, iq, first * 2 * sizeof(float));
    if (n > first) {
        std::memcpy(ring_.data(), iq + first * 2,
                    (n - first) * 2 * sizeof(float));
    }
    count_ += n;
    cv_.notify_one();
}

void PushIqSource::feed_cf32(const float *iq, size_t n_complex) {
    if (!iq || n_complex == 0) return;
    std::lock_guard<std::mutex> lk(mtx_);
    write_cf32_locked(iq, n_complex);
}

void PushIqSource::feed_i8(const uint8_t *iq, size_t n_complex) {
    if (!iq || n_complex == 0) return;

    if (conv_.size() < n_complex * 2) conv_.resize(n_complex * 2);
    const float scale = 1.0f / 128.0f;
    for (size_t i = 0; i < n_complex; i++) {
        conv_[i * 2]     = (float)((int8_t)iq[i * 2])     * scale;
        conv_[i * 2 + 1] = (float)((int8_t)iq[i * 2 + 1]) * scale;
    }

    std::lock_guard<std::mutex> lk(mtx_);
    write_cf32_locked(conv_.data(), n_complex);
}

} // namespace iridi

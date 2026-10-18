#include "mobile_bridge.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "core/engine.h"
#include "core/file_source.h"
#include "push_iq_source.h"

#include "cJSON.h"

struct ir_mobile {
    std::mutex ctrl_mtx;

    iridi::Engine engine;
    std::unique_ptr<iridi::IqFileSource> file;
    std::unique_ptr<iridi::PushIqSource> push;
    iridi::IqSource *source = nullptr;

    int source_kind = 0; // 0=none, 1=file, 2=push
    uint32_t center_hz = 1621250000u;
    uint32_t sample_rate = 2400000u;
    int fft_size = 4096;
    int workers = 2;
    bool realtime = true;

    std::atomic<uint64_t> last_spec_seq{0};
    std::atomic<uint64_t> last_msg_seq{0};
    std::atomic<uint64_t> last_frame_seq{0};

    std::atomic<uint64_t> last_dropped{0};
};

static void set_err(char *err, int errlen, const char *fmt, ...) {
    if (!err || errlen <= 0) return;
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(err, (size_t)errlen, fmt, ap);
    va_end(ap);
    err[errlen - 1] = '\0';
}

static std::string hex_bytes(const std::vector<uint8_t> &v) {
    static const char *digits = "0123456789abcdef";
    std::string out;
    out.reserve(v.size() * 2);
    for (uint8_t b : v) {
        out.push_back(digits[b >> 4]);
        out.push_back(digits[b & 0x0f]);
    }
    return out;
}

static cJSON *message_to_json(const irid::ParsedMessage &pm) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "seq", (double)pm.seq);
    cJSON_AddStringToObject(o, "type", pm.type.c_str());
    cJSON_AddStringToObject(o, "pretty", pm.pretty.c_str());
    cJSON_AddNumberToObject(o, "freq", pm.frequency);
    cJSON_AddNumberToObject(o, "ts_ns", (double)pm.timestamp_ns);
    cJSON_AddNumberToObject(o, "confidence", pm.confidence);
    cJSON_AddNumberToObject(o, "uplink", pm.uplink);
    cJSON_AddNumberToObject(o, "symbols", pm.symbols);
    cJSON_AddBoolToObject(o, "error", pm.error != 0);

    if (pm.has_ira) {
        cJSON *ira = cJSON_AddObjectToObject(o, "ira");
        cJSON_AddNumberToObject(ira, "sat", pm.ira_sat);
        cJSON_AddNumberToObject(ira, "beam", pm.ira_beam);
        cJSON_AddNumberToObject(ira, "alt_km", pm.ira_alt_km);
        cJSON_AddNumberToObject(ira, "pages", pm.ira_pages);
        cJSON_AddNumberToObject(ira, "rai", pm.ira_rai);
        cJSON_AddNumberToObject(ira, "bc_sb", pm.ira_bc_sb);
        cJSON_AddBoolToObject(ira, "is_ground", pm.ira_is_ground);
        cJSON_AddNumberToObject(ira, "lat", pm.ira_lat);
        cJSON_AddNumberToObject(ira, "lon", pm.ira_lon);
    }
    if (pm.has_ibc) {
        cJSON *ibc = cJSON_AddObjectToObject(o, "ibc");
        cJSON_AddNumberToObject(ibc, "sat", pm.ibc_sat);
        cJSON_AddNumberToObject(ibc, "beam", pm.ibc_beam);
        cJSON_AddNumberToObject(ibc, "type", pm.ibc_type);
        cJSON_AddNumberToObject(ibc, "iri_time", (double)pm.ibc_iri_time);
        cJSON_AddBoolToObject(ibc, "has_time", pm.ibc_has_time != 0);
    }
    if (pm.has_ida) {
        cJSON *ida = cJSON_AddObjectToObject(o, "ida");
        cJSON_AddNumberToObject(ida, "ctr", pm.ida_ctr);
        cJSON_AddNumberToObject(ida, "len", pm.ida_len);
        cJSON_AddBoolToObject(ida, "crc_ok", pm.ida_crc_ok != 0);
        cJSON_AddBoolToObject(ida, "cont", pm.ida_cont != 0);
        cJSON_AddStringToObject(ida, "text", pm.ida_text.c_str());
        std::string hex = hex_bytes(pm.ida_data);
        cJSON_AddStringToObject(ida, "data_hex", hex.c_str());
    }
    if (pm.has_ims) {
        cJSON *ims = cJSON_AddObjectToObject(o, "ims");
        cJSON_AddBoolToObject(ims, "msg", pm.has_msg);
        cJSON_AddNumberToObject(ims, "ric", pm.msg_ric);
        cJSON_AddNumberToObject(ims, "fmt", pm.msg_fmt);
        cJSON_AddNumberToObject(ims, "seq", pm.msg_seq);
        cJSON_AddNumberToObject(ims, "part", pm.msg_part);
        cJSON_AddNumberToObject(ims, "parts", pm.msg_parts);
        cJSON_AddNumberToObject(ims, "checksum", pm.msg_checksum);
        cJSON_AddBoolToObject(ims, "csum_ok", pm.msg_csum_ok);
        cJSON_AddStringToObject(ims, "text", pm.msg_text.c_str());
        std::string hex = hex_bytes(pm.msg_bytes);
        cJSON_AddStringToObject(ims, "data_hex", hex.c_str());
    }
    return o;
}

static cJSON *acars_to_json(const iridi::AcarsMessage &m) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "ts_ns", (double)m.timestamp_ns);
    cJSON_AddNumberToObject(o, "ul", m.ul);
    cJSON_AddStringToObject(o, "heading", m.heading.c_str());
    cJSON_AddStringToObject(o, "reg", m.reg.c_str());
    cJSON_AddStringToObject(o, "flight", m.flight.c_str());
    cJSON_AddStringToObject(o, "mode", m.mode.c_str());
    cJSON_AddStringToObject(o, "ack", m.ack.c_str());
    cJSON_AddStringToObject(o, "label", m.label.c_str());
    cJSON_AddStringToObject(o, "label_desc", m.label_desc.c_str());
    cJSON_AddStringToObject(o, "bid", m.bid.c_str());
    cJSON_AddStringToObject(o, "seqn", m.seqn.c_str());
    cJSON_AddStringToObject(o, "text", m.text.c_str());
    cJSON_AddStringToObject(o, "raw_hex", m.raw_hex.c_str());
    cJSON_AddStringToObject(o, "errors", m.errors.c_str());
    cJSON_AddBoolToObject(o, "crc_ok", m.crc_ok);
    cJSON_AddBoolToObject(o, "cont", m.cont);
    return o;
}

static cJSON *sbd_to_json(const iridi::SbdMessage &m) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "ts_ns", (double)m.timestamp_ns);
    cJSON_AddNumberToObject(o, "freq", m.frequency);
    cJSON_AddNumberToObject(o, "ul", m.ul);
    cJSON_AddStringToObject(o, "type", m.type.c_str());
    cJSON_AddNumberToObject(o, "length", m.length);
    cJSON_AddStringToObject(o, "preheader_hex", m.preheader_hex.c_str());
    cJSON_AddStringToObject(o, "payload_hex", m.payload_hex.c_str());
    cJSON_AddStringToObject(o, "text", m.text.c_str());
    cJSON_AddStringToObject(o, "info", m.info.c_str());
    cJSON_AddBoolToObject(o, "acars", m.acars);
    cJSON_AddBoolToObject(o, "has_crc", m.has_crc);
    cJSON_AddBoolToObject(o, "crc_ok", m.crc_ok);
    cJSON_AddBoolToObject(o, "has_nal", m.has_nal);
    cJSON_AddNumberToObject(o, "nal_lat", m.nal_lat);
    cJSON_AddNumberToObject(o, "nal_lon", m.nal_lon);
    cJSON_AddNumberToObject(o, "nal_pdop", m.nal_pdop);
    cJSON_AddNumberToObject(o, "nal_seconds", m.nal_seconds);
    cJSON_AddBoolToObject(o, "nal_fix", m.nal_fix);
    cJSON_AddBoolToObject(o, "nal_emergency", m.nal_emergency);
    cJSON_AddBoolToObject(o, "nal_emergency_ack", m.nal_emergency_ack);
    cJSON_AddBoolToObject(o, "nal_motion", m.nal_motion);
    cJSON_AddStringToObject(o, "nal_info", m.nal_info.c_str());
    return o;
}

static cJSON *sms_to_json(const iridi::SmsMessage &m) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "ts_ns", (double)m.timestamp_ns);
    cJSON_AddNumberToObject(o, "ul", m.ul);
    cJSON_AddStringToObject(o, "from", m.from.c_str());
    cJSON_AddStringToObject(o, "to", m.to.c_str());
    cJSON_AddStringToObject(o, "text", m.text.c_str());
    cJSON_AddStringToObject(o, "dcs", m.dcs.c_str());
    cJSON_AddBoolToObject(o, "ok", m.ok);
    return o;
}

static cJSON *pager_to_json(const iridi::PagerMessage &m) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "ts_ns", (double)m.timestamp_ns);
    cJSON_AddNumberToObject(o, "ric", m.ric);
    cJSON_AddNumberToObject(o, "fmt", m.fmt);
    cJSON_AddNumberToObject(o, "seq", m.seq);
    cJSON_AddNumberToObject(o, "parts", m.parts);
    cJSON_AddBoolToObject(o, "ok", m.ok);
    cJSON_AddStringToObject(o, "text", m.text.c_str());
    return o;
}

static cJSON *voice_to_json(const iridi::VoiceCall &v) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "id", v.id);
    cJSON_AddNumberToObject(o, "channel_hz", v.channel_hz);
    cJSON_AddNumberToObject(o, "start_ns", (double)v.start_ns);
    cJSON_AddNumberToObject(o, "end_ns", (double)v.end_ns);
    cJSON_AddNumberToObject(o, "frames", v.frames);
    cJSON_AddNumberToObject(o, "error_ratio", v.error_ratio);
    cJSON_AddBoolToObject(o, "active", v.active);
    cJSON_AddStringToObject(o, "wav_path", v.wav_path.c_str());
    cJSON_AddNumberToObject(o, "duration_s", v.duration_s);
    return o;
}

static cJSON *satellite_to_json(const iridi::Satellite &s) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "id", s.id);
    cJSON_AddNumberToObject(o, "lat", s.lat);
    cJSON_AddNumberToObject(o, "lon", s.lon);
    cJSON_AddNumberToObject(o, "alt_km", s.alt_km);
    cJSON_AddNumberToObject(o, "beam", s.beam);
    cJSON_AddNumberToObject(o, "last_seen_ns", (double)s.last_seen_ns);
    cJSON_AddNumberToObject(o, "count", s.count);
    cJSON_AddBoolToObject(o, "has_pos", s.has_pos);
    return o;
}

static cJSON *beam_to_json(const iridi::GroundBeam &b) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "sat", b.sat);
    cJSON_AddNumberToObject(o, "beam", b.beam);
    cJSON_AddNumberToObject(o, "lat", b.lat);
    cJSON_AddNumberToObject(o, "lon", b.lon);
    cJSON_AddNumberToObject(o, "alt_km", b.alt_km);
    cJSON_AddNumberToObject(o, "last_seen_ns", (double)b.last_seen_ns);
    cJSON_AddNumberToObject(o, "count", b.count);
    cJSON_AddNumberToObject(o, "pages", b.pages);
    cJSON_AddBoolToObject(o, "has_pos", b.has_pos);
    return o;
}

static cJSON *frame_to_json(const iridi::FrameEvent &f) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "seq", (double)f.seq);
    cJSON_AddNumberToObject(o, "freq", f.frequency);
    cJSON_AddNumberToObject(o, "ts_ns", (double)f.timestamp_ns);
    cJSON_AddNumberToObject(o, "confidence", f.confidence);
    cJSON_AddNumberToObject(o, "direction", f.direction);
    cJSON_AddNumberToObject(o, "bits", f.n_bits);
    return o;
}

static void stats_to_json(cJSON *root, const ir_mobile_stats_t &s) {
    cJSON_AddNumberToObject(root, "samples", (double)s.samples);
    cJSON_AddNumberToObject(root, "total_samples", (double)s.total_samples);
    cJSON_AddNumberToObject(root, "bursts", (double)s.bursts);
    cJSON_AddNumberToObject(root, "frames_ok", (double)s.frames_ok);
    cJSON_AddNumberToObject(root, "frames_fail", (double)s.frames_fail);
    cJSON_AddNumberToObject(root, "messages", (double)s.messages);
    cJSON_AddNumberToObject(root, "dropped_samples", (double)s.dropped_samples);
    cJSON_AddNumberToObject(root, "elapsed_s", s.elapsed_s);
    cJSON_AddNumberToObject(root, "rate_sps", s.rate_sps);
    cJSON_AddBoolToObject(root, "running", s.running != 0);
    cJSON_AddBoolToObject(root, "paused", s.paused != 0);
    cJSON_AddBoolToObject(root, "done", s.done != 0);
    cJSON_AddNumberToObject(root, "fft_size", s.fft_size);
    cJSON_AddNumberToObject(root, "sample_rate", s.sample_rate);
    cJSON_AddNumberToObject(root, "center_hz", s.center_hz);
    cJSON_AddNumberToObject(root, "floor_db", s.floor_db);
    cJSON_AddNumberToObject(root, "peak_db", s.peak_db);
}

static void fill_stats(ir_mobile *m, ir_mobile_stats_t *out) {
    if (!out) return;
    std::memset(out, 0, sizeof(*out));
    iridi::EngineStats es = m->engine.stats();
    out->samples = es.samples;
    out->total_samples = es.total_samples;
    out->bursts = es.bursts;
    out->frames_ok = es.frames_ok;
    out->frames_fail = es.frames_fail;
    out->elapsed_s = es.elapsed_s;
    out->rate_sps = es.rate_sps;
    out->running = es.running ? 1 : 0;
    out->paused = es.paused ? 1 : 0;
    out->done = es.done ? 1 : 0;
    out->messages = m->engine.parsed_count();
    out->fft_size = m->engine.fft_size();
    out->sample_rate = m->sample_rate;
    out->center_hz = (double)m->center_hz;
    out->floor_db = m->engine.spectrum_floor();
    out->peak_db = m->engine.spectrum_peak();
    out->dropped_samples = m->push ? m->push->dropped_samples() : 0;
}

static void reset_source(ir_mobile *m) {
    m->engine.stop();
    if (m->push) {
        m->push->close();
        m->push.reset();
    }
    m->file.reset();
    m->source = nullptr;
    m->source_kind = 0;
}

static std::atomic<ir_mobile_t *> g_default{nullptr};

extern "C" {

ir_mobile_t *ir_mobile_create(void) {
    ir_mobile_t *m = new (std::nothrow) ir_mobile();
    if (m) g_default.store(m);
    return m;
}

void ir_mobile_destroy(ir_mobile_t *m) {
    if (!m) return;
    {
        std::lock_guard<std::mutex> lk(m->ctrl_mtx);
        reset_source(m);
    }
    ir_mobile_t *expected = m;
    g_default.compare_exchange_strong(expected, nullptr);
    delete m;
}

ir_mobile_t *ir_mobile_default(void) {
    return g_default.load();
}

int ir_mobile_open_file(ir_mobile_t *m, const char *path,
                        char *err, int errlen) {
    if (!m || !path) return -1;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    reset_source(m);

    auto f = std::make_unique<iridi::IqFileSource>();
    std::string e;
    if (!f->open(path, e)) {
        set_err(err, errlen, "%s", e.c_str());
        return -2;
    }
    const auto &info = f->info();
    m->source = f.get();
    m->file = std::move(f);
    m->source_kind = 1;
    m->sample_rate = (uint32_t)std::max(0, info.sample_rate);
    m->center_hz = info.center_frequency > 0
                       ? (uint32_t)std::llround(info.center_frequency)
                       : 1621250000u;
    m->realtime = true;
    if (err && errlen) err[0] = '\0';
    return 0;
}

int ir_mobile_open_file_fd(ir_mobile_t *m, int fd, const char *display_name,
                           char *err, int errlen) {
    if (!m) return -1;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    reset_source(m);

    auto f = std::make_unique<iridi::IqFileSource>();
    std::string e;
    std::string name = display_name ? display_name : "iq-file";
    if (!f->open_fd(fd, name, e)) {
        set_err(err, errlen, "%s", e.c_str());
        return -2;
    }
    const auto &info = f->info();
    m->source = f.get();
    m->file = std::move(f);
    m->source_kind = 1;
    m->sample_rate = (uint32_t)std::max(0, info.sample_rate);
    m->center_hz = info.center_frequency > 0
                       ? (uint32_t)std::llround(info.center_frequency)
                       : 1621250000u;
    m->realtime = true;
    if (err && errlen) err[0] = '\0';
    return 0;
}

int ir_mobile_open_push(ir_mobile_t *m, uint32_t center_hz,
                        uint32_t sample_rate, int fft_size, int workers) {
    if (!m) return -1;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    reset_source(m);

    m->center_hz = center_hz ? center_hz : 1621250000u;
    m->sample_rate = sample_rate ? sample_rate : 2400000u;
    m->fft_size = fft_size >= 256 ? fft_size : 4096;
    m->workers = workers > 0 ? workers : 2;
    m->realtime = false;

    auto p = std::make_unique<iridi::PushIqSource>(1u << 20);
    p->open((int)m->sample_rate, (double)m->center_hz);
    m->source = p.get();
    m->push = std::move(p);
    m->source_kind = 2;
    return 0;
}

int ir_mobile_start(ir_mobile_t *m) {
    if (!m) return -1;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    if (!m->source) return -2;
    if (m->engine.running()) return 0;

    if (m->source_kind == 2 && m->push) {
        if (!m->push->is_open())
            m->push->open((int)m->sample_rate, (double)m->center_hz);
    }

    m->engine.set_realtime(m->realtime);
    if (!m->engine.start(m->source, 16.0f, m->workers)) return -3;
    m->engine.set_fft_size(m->fft_size);
    m->last_spec_seq.store(0);
    m->last_msg_seq.store(0);
    m->last_frame_seq.store(0);
    return 0;
}

void ir_mobile_stop(ir_mobile_t *m) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->engine.stop();
    if (m->push) m->push->close();
}

void ir_mobile_pause(ir_mobile_t *m, int paused) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->engine.set_paused(paused != 0);
}

void ir_mobile_set_realtime(ir_mobile_t *m, int on) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->realtime = on != 0;
    m->engine.set_realtime(m->realtime);
}

void ir_mobile_seek_sample(ir_mobile_t *m, uint64_t sample) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    if (!m->file) return;
    bool was_paused = m->engine.paused();
    m->engine.set_paused(true);
    m->file->seek_sample(sample);
    if (!was_paused) m->engine.set_paused(false);
}

void ir_mobile_set_frequency(ir_mobile_t *m, uint32_t hz) {
    if (!m || hz == 0) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->center_hz = hz;
    if (m->push) m->push->set_center_frequency((double)hz);
    m->engine.set_center_frequency((double)hz);
}

void ir_mobile_set_fft_size(ir_mobile_t *m, int n) {
    if (!m || n < 256) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->fft_size = n;
    m->engine.set_fft_size(n);
}

void ir_mobile_set_avg_alpha(ir_mobile_t *m, float alpha) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->engine.set_avg_alpha(alpha);
}

void ir_mobile_set_dc_block(ir_mobile_t *m, int on) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->engine.set_dc_block(on != 0);
}

void ir_mobile_set_voice_dir(ir_mobile_t *m, const char *dir) {
    if (!m) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    m->engine.set_voice_output_dir(dir ? dir : "");
}

uint64_t ir_mobile_poll_spectrum(ir_mobile_t *m, float *inst, float *avg, int n) {
    if (!m || !inst || !avg || n <= 0) return 0;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    uint64_t seq = m->engine.spectrum_seq();
    if (seq == 0 || seq == m->last_spec_seq.load()) return 0;
    int copied = m->engine.spectrum_copy(inst, avg, n);
    if (copied <= 0) return 0;
    m->last_spec_seq.store(seq);
    return seq;
}

int ir_mobile_poll_events(ir_mobile_t *m, char *json, int maxlen) {
    if (!m || !json || maxlen <= 4) return -1;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);

    uint64_t after_msg = m->last_msg_seq.load();
    uint64_t after_frame = m->last_frame_seq.load();
    auto messages = m->engine.messages_since(after_msg, 100);
    auto frames = m->engine.frames_since(after_frame, 100);

    ir_mobile_stats_t st;
    fill_stats(m, &st);

    cJSON *root = cJSON_CreateObject();
    cJSON *ma = cJSON_AddArrayToObject(root, "messages");
    cJSON *fa = cJSON_AddArrayToObject(root, "frames");
    cJSON *sa = cJSON_AddObjectToObject(root, "stats");

    uint64_t new_msg = after_msg;
    for (const auto &pm : messages) {
        cJSON_AddItemToArray(ma, message_to_json(pm));
        new_msg = std::max(new_msg, pm.seq);
    }
    uint64_t new_frame = after_frame;
    for (const auto &f : frames) {
        cJSON_AddItemToArray(fa, frame_to_json(f));
        new_frame = std::max(new_frame, f.seq);
    }

    cJSON *aca = cJSON_AddArrayToObject(root, "acars");
    auto acars = m->engine.acars().messages();
    size_t astart = acars.size() > 100 ? acars.size() - 100 : 0;
    for (size_t i = astart; i < acars.size(); i++)
        cJSON_AddItemToArray(aca, acars_to_json(acars[i]));

    cJSON *sba = cJSON_AddArrayToObject(root, "sbd");
    auto sbd = m->engine.acars().sbd_messages();
    size_t sstart = sbd.size() > 100 ? sbd.size() - 100 : 0;
    for (size_t i = sstart; i < sbd.size(); i++)
        cJSON_AddItemToArray(sba, sbd_to_json(sbd[i]));

    cJSON *sma = cJSON_AddArrayToObject(root, "sms");
    auto sms = m->engine.acars().sms_messages();
    size_t smstart = sms.size() > 100 ? sms.size() - 100 : 0;
    for (size_t i = smstart; i < sms.size(); i++)
        cJSON_AddItemToArray(sma, sms_to_json(sms[i]));

    cJSON *pga = cJSON_AddArrayToObject(root, "pager");
    auto pager = m->engine.pager().messages();
    size_t pstart = pager.size() > 100 ? pager.size() - 100 : 0;
    for (size_t i = pstart; i < pager.size(); i++)
        cJSON_AddItemToArray(pga, pager_to_json(pager[i]));

    cJSON *vca = cJSON_AddArrayToObject(root, "voice");
    auto calls = m->engine.voices().calls();
    size_t vstart = calls.size() > 50 ? calls.size() - 50 : 0;
    for (size_t i = vstart; i < calls.size(); i++)
        cJSON_AddItemToArray(vca, voice_to_json(calls[i]));

    cJSON *sta = cJSON_AddArrayToObject(root, "satellites");
    for (const auto &s : m->engine.satellites())
        cJSON_AddItemToArray(sta, satellite_to_json(s));

    cJSON *bea = cJSON_AddArrayToObject(root, "beams");
    for (const auto &b : m->engine.ground_beams())
        cJSON_AddItemToArray(bea, beam_to_json(b));

    stats_to_json(sa, st);

    char *printed = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!printed) return -2;
    int len = (int)std::strlen(printed);
    if (len >= maxlen) {
        cJSON_free(printed);
        return -2;
    }
    std::memcpy(json, printed, (size_t)len + 1);
    cJSON_free(printed);

    m->last_msg_seq.store(new_msg);
    m->last_frame_seq.store(new_frame);
    return len;
}

void ir_mobile_get_stats(ir_mobile_t *m, ir_mobile_stats_t *out) {
    if (!m || !out) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    fill_stats(m, out);
}

int ir_mobile_file_info(ir_mobile_t *m, char *json, int maxlen) {
    if (!m || !json || maxlen <= 4) return -1;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    if (!m->file) return -1;

    const auto &info = m->file->info();
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "path", info.path.c_str());
    cJSON_AddStringToObject(root, "format", iridi::iq_format_name(info.format));
    cJSON_AddBoolToObject(root, "is_wav", info.is_wav);
    cJSON_AddNumberToObject(root, "sample_rate", info.sample_rate);
    cJSON_AddNumberToObject(root, "channels", info.channels);
    cJSON_AddNumberToObject(root, "bits_per_sample", info.bits_per_sample);
    cJSON_AddNumberToObject(root, "num_samples", (double)info.num_samples);
    cJSON_AddNumberToObject(root, "duration_s", info.duration_s);
    cJSON_AddNumberToObject(root, "center_hz", info.center_frequency);
    cJSON_AddNumberToObject(root, "file_size", (double)info.file_size);

    char *printed = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!printed) return -2;
    int len = (int)std::strlen(printed);
    if (len >= maxlen) {
        cJSON_free(printed);
        return -2;
    }
    std::memcpy(json, printed, (size_t)len + 1);
    cJSON_free(printed);
    return len;
}

void ir_mobile_feed_i8(ir_mobile_t *m, const uint8_t *iq, int n_bytes) {
    if (!m || !iq || n_bytes < 2) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    if (!m->push) return;
    m->push->feed_i8(iq, (size_t)(n_bytes / 2));
}

void ir_mobile_feed_cf32(ir_mobile_t *m, const float *iq, int n_floats) {
    if (!m || !iq || n_floats < 2) return;
    std::lock_guard<std::mutex> lk(m->ctrl_mtx);
    if (!m->push) return;
    m->push->feed_cf32(iq, (size_t)(n_floats / 2));
}

} // extern "C"

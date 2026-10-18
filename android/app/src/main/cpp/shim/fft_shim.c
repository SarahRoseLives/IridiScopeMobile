/*
 * Minimal FFTW3f-compatible API backed by KissFFT (BSD-3-Clause).
 *
 * Only the calls used by the Iridium pipeline are implemented:
 *   fftwf_malloc/free/alloc_complex
 *   fftwf_plan_dft_1d / fftwf_execute / fftwf_destroy_plan
 *
 * Plans are tied to the in/out arrays passed at creation time, which is how the
 * pipeline uses them.  Input and output may alias.
 */
#include "fftw3.h"

#include <stdlib.h>
#include <string.h>

#include "kiss_fft.h"

struct fftwf_plan_s {
    int n;
    int inverse;
    fftwf_complex *in;
    fftwf_complex *out;
    kiss_fft_cfg cfg;
    kiss_fft_cpx *tmp_in;
    kiss_fft_cpx *tmp_out;
};

static void *aligned_alloc_32(size_t n)
{
    void *p = NULL;
    size_t rounded = (n + 31u) & ~(size_t)31u;
    if (posix_memalign(&p, 32, rounded) != 0)
        return NULL;
    return p;
}

void *fftwf_malloc(size_t n)
{
    return aligned_alloc_32(n ? n : 1);
}

void fftwf_free(void *p)
{
    free(p);
}

fftwf_complex *fftwf_alloc_complex(size_t n)
{
    if (n == 0) n = 1;
    void *p = aligned_alloc_32(n * sizeof(fftwf_complex));
    if (p) memset(p, 0, n * sizeof(fftwf_complex));
    return (fftwf_complex *)p;
}

fftwf_plan fftwf_plan_dft_1d(int n, fftwf_complex *in, fftwf_complex *out,
                             int sign, unsigned flags)
{
    (void)flags;
    if (n <= 0) return NULL;

    fftwf_plan p = (fftwf_plan)calloc(1, sizeof(*p));
    if (!p) return NULL;

    p->n = n;
    p->inverse = (sign == FFTW_BACKWARD) ? 1 : 0;
    p->in = in;
    p->out = out;
    p->cfg = kiss_fft_alloc(n, p->inverse, NULL, NULL);
    p->tmp_in = (kiss_fft_cpx *)malloc((size_t)n * sizeof(kiss_fft_cpx));
    p->tmp_out = (kiss_fft_cpx *)malloc((size_t)n * sizeof(kiss_fft_cpx));
    if (!p->cfg || !p->tmp_in || !p->tmp_out) {
        if (p->cfg) kiss_fft_free(p->cfg);
        free(p->tmp_in);
        free(p->tmp_out);
        free(p);
        return NULL;
    }
    return p;
}

void fftwf_execute(const fftwf_plan p)
{
    if (!p || !p->cfg || !p->in || !p->out) return;
    const int n = p->n;

    /* KissFFT works on its own complex struct.  The FFTW layout is identical
     * (two adjacent floats), so the copy is cheap and keeps strict aliasing
     * clean. */
    for (int i = 0; i < n; i++) {
        p->tmp_in[i].r = p->in[i][0];
        p->tmp_in[i].i = p->in[i][1];
    }
    kiss_fft(p->cfg, p->tmp_in, p->tmp_out);
    for (int i = 0; i < n; i++) {
        p->out[i][0] = p->tmp_out[i].r;
        p->out[i][1] = p->tmp_out[i].i;
    }
}

void fftwf_destroy_plan(fftwf_plan p)
{
    if (!p) return;
    if (p->cfg) kiss_fft_free(p->cfg);
    free(p->tmp_in);
    free(p->tmp_out);
    free(p);
}

int fftwf_import_wisdom_from_filename(const char *filename)
{
    (void)filename;
    return 0;
}

int fftwf_export_wisdom_to_filename(const char *filename)
{
    (void)filename;
    return 0;
}

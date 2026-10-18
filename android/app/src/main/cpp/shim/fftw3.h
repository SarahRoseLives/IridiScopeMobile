/*
 * Minimal FFTW3f-compatible API backed by KissFFT.
 *
 * IridiScope's Iridium DSP uses a small, well-defined subset of the FFTW
 * single-precision interface.  This shim implements exactly that subset so the
 * native pipeline can be built for Android without cross-compiling FFTW.
 */
#ifndef IRIDISCOPE_FFTW3_SHIM_H
#define IRIDISCOPE_FFTW3_SHIM_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef float fftwf_complex[2];
typedef struct fftwf_plan_s *fftwf_plan;

#define FFTW_FORWARD  (-1)
#define FFTW_BACKWARD (+1)

#define FFTW_MEASURE  (0U)
#define FFTW_ESTIMATE (1U << 6)

void *fftwf_malloc(size_t n);
void  fftwf_free(void *p);
fftwf_complex *fftwf_alloc_complex(size_t n);

fftwf_plan fftwf_plan_dft_1d(int n, fftwf_complex *in, fftwf_complex *out,
                             int sign, unsigned flags);
void fftwf_execute(const fftwf_plan p);
void fftwf_destroy_plan(fftwf_plan p);

int fftwf_import_wisdom_from_filename(const char *filename);
int fftwf_export_wisdom_to_filename(const char *filename);

#ifdef __cplusplus
}
#endif

#endif

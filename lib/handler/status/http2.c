/*
 * Copyright (c) 2018 Fastly
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include "h2o.h"
#include <inttypes.h>

struct st_http2_status_ctx_t {
    uint64_t h2_pushes;
    uint64_t h2_hpack_evictions;
    pthread_mutex_t mutex;
};

static void http2_status_per_thread(void *priv, h2o_context_t *ctx)
{
    struct st_http2_status_ctx_t *hsc = priv;

    pthread_mutex_lock(&hsc->mutex);

    hsc->h2_pushes += ctx->http2.stats.pushes;
    hsc->h2_hpack_evictions += ctx->http2.stats.hpack_evictions;

    pthread_mutex_unlock(&hsc->mutex);
}

static void *http2_status_init(void)
{
    struct st_http2_status_ctx_t *ret;

    ret = h2o_mem_alloc(sizeof(*ret));
    memset(ret, 0, sizeof(*ret));
    pthread_mutex_init(&ret->mutex, NULL);

    return ret;
}

static h2o_iovec_t http2_status_final(void *priv, h2o_globalconf_t *gconf, h2o_req_t *req)
{
    struct st_http2_status_ctx_t *hsc = priv;
    h2o_iovec_t ret;

#define BUFSIZE 128
    ret.base = h2o_mem_alloc_pool(&req->pool, char, BUFSIZE);
    ret.len = snprintf(ret.base, BUFSIZE, ",\n"
                                          " \"http2-stats.pushes\": %" PRIu64 ",\n"
                                          " \"http2-stats.hpack_evictions\": %" PRIu64 "\n",
                       hsc->h2_pushes, hsc->h2_hpack_evictions);
    pthread_mutex_destroy(&hsc->mutex);
    free(hsc);
    return ret;
#undef BUFSIZE
}

h2o_status_handler_t http2_status_handler = {
    {H2O_STRLIT("http2")}, http2_status_init, http2_status_per_thread, http2_status_final,
};

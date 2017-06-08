/*
 * Copyright (c) 2017 Fastly, Inc., Frederik Deweerdt
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

#include "h2o/file.h"
#include "h2o/file_observer.h"
#include "h2o.h"

#include <pthread.h>

struct st_h2o_file_observer_t {
    const char *filename;
    time_t last_mtime;
    h2o_file_observer_receiver_t *receiver;
};

struct st_h2o_file_observer_contents_t {
    h2o_iovec_t content;
};
struct st_h2o_file_observer_message_t {
    h2o_multithread_message_t super;
    struct st_h2o_file_observer_contents_t *contents;
    h2o_file_observer_t *fo;
};

static H2O_VECTOR(h2o_file_observer_t *) observers;
static H2O_VECTOR(h2o_multithread_receiver_t *) receivers;
static pthread_mutex_t observers_lock = PTHREAD_MUTEX_INITIALIZER;

static void dispose_fo_message(void *p)
{
    struct st_h2o_file_observer_contents_t *contents = p;
    free(contents->content.base);
}

static void h2o_file_observer_receiver(h2o_multithread_receiver_t *receiver, h2o_linklist_t *messages)
{
    while (!h2o_linklist_is_empty(messages)) {
        struct st_h2o_file_observer_message_t *msg = H2O_STRUCT_FROM_MEMBER(struct st_h2o_file_observer_message_t, super, messages->next);
        h2o_linklist_unlink(&msg->super.link);
        msg->fo->receiver->cb(msg->fo->receiver, msg->contents->content);
        h2o_mem_release_shared(msg->contents);
        free(msg);
    }
}

static void *file_observer_thread_main(void *_unused)
{
    while (1) {
        struct stat st;
        int i, j, ret;
        H2O_VECTOR(h2o_file_observer_t *) observers_copy = {};

        /* copy the array so that we don't hold the lock for a long time */
        pthread_mutex_lock(&observers_lock);
        h2o_vector_reserve(NULL, &observers_copy, observers.size);
        memcpy(observers_copy.entries, observers.entries, observers.size * sizeof(*observers.entries));
        observers_copy.size = observers.size;
        pthread_mutex_unlock(&observers_lock);

        for (i = 0; i < observers_copy.size; i++) {
            h2o_iovec_t new_contents;
            h2o_file_observer_t *fo = observers_copy.entries[i];

            sleep(1);
            ret = stat(fo->filename, &st);
            if (ret != 0)
                goto ReadError;

            if (fo->last_mtime == st.st_mtime)
                continue;

            new_contents = h2o_file_read(fo->filename);
            if (!new_contents.base)
                goto ReadError;

            fo->last_mtime = st.st_mtime;
            struct st_h2o_file_observer_contents_t *contents = h2o_mem_alloc_shared(NULL, sizeof(*contents), dispose_fo_message);
            contents->content = new_contents;

            for (j = 0; j < receivers.size; j++) {
                struct st_h2o_file_observer_message_t *message = h2o_mem_alloc(sizeof(*message));
                h2o_mem_addref_shared(contents);
                message->super = (h2o_multithread_message_t){{NULL}};
                message->contents = contents;
                message->fo = fo;
                h2o_multithread_send_message(receivers.entries[j], &message->super);
            }
            h2o_mem_release_shared(contents);
            continue;

        ReadError:
            /* on error, simply invalidate the current file */
            fo->last_mtime = 0;
        }
    }

    h2o_fatal("unreachable");
    return NULL;
}

static void create_file_observer_thread(void)
{
    pthread_t tid;
    pthread_attr_t attr;
    int ret;

    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, 1);
    pthread_attr_setstacksize(&attr, 100 * 1024);
    if ((ret = pthread_create(&tid, NULL, file_observer_thread_main, NULL)) != 0) {
        fprintf(stderr, "failed to start first thread for create_file_observer_thread:%s\n", strerror(ret));
        abort();
    }
}

void h2o_file_observer_context_init(h2o_context_t *ctx)
{
    h2o_multithread_register_receiver(ctx->queue, &ctx->receivers.file_observer, h2o_file_observer_receiver);
    h2o_vector_reserve(NULL, &receivers, receivers.size + 1);
    receivers.entries[receivers.size++] = &ctx->receivers.file_observer;
}

h2o_file_observer_t *h2o_file_observer_create(const char *filename, h2o_file_observer_receiver_t *receiver)
{
    h2o_file_observer_t *self = h2o_mem_calloc(sizeof(*self));
    int ret;
    struct stat st;

    self->filename = strdup(filename);

    ret = stat(filename, &st);
    if (ret == 0) {
        self->last_mtime = st.st_mtime;
    }

    pthread_mutex_lock(&observers_lock);
    h2o_vector_reserve(NULL, &observers, observers.size + 1);
    observers.entries[observers.size++] = self;
    pthread_mutex_unlock(&observers_lock);

    static pthread_mutex_t once = PTHREAD_MUTEX_INITIALIZER;
    if (pthread_mutex_trylock(&once) == 0) {
        create_file_observer_thread();
    }

    self->receiver = receiver;

    return self;
}

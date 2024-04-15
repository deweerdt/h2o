const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const path = std.fs.path;

fn execute_process(args: struct {
    allocator: mem.Allocator,
    argv: []const []const u8,
}) ?[]const u8 {
    const proc = std.process.Child.run(.{
        .allocator = args.allocator,
        .argv = args.argv,
    });
    const result = proc catch return null;

    defer {
        args.allocator.free(result.stdout);
        args.allocator.free(result.stderr);
    }

    switch (result.term) {
        .Exited => |code| if (code != 0) return null,
        else => return null,
    }

    return args.allocator.dupe(u8, mem.trimRight(u8, result.stdout, "\r\n")) catch null;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libz_dep = b.dependency("libz", .{
        .target = target,
        .optimize = optimize,
    });
    const openssl_dep = b.dependency("openssl", .{
        .target = target,
        .optimize = optimize,
    });

    const h2o_exe = b.addExecutable(.{
        .name = "h2o",
        .optimize = optimize,
        .target = target,
    });
    const include_dirs = [_][]const u8{
        "include",
        "deps/cloexec",
        "deps/brotli/c/include",
        "deps/golombset",
        "deps/hiredis",
        "deps/libgkc",
        "deps/libyrmcds",
        "deps/klib",
        "deps/neverbleed",
        "deps/picohttpparser",
        "deps/picotest",
        "deps/picotls/deps/cifra/src/ext",
        "deps/picotls/deps/cifra/src",
        "deps/picotls/deps/micro-ecc",
        "deps/picotls/include",
        "deps/quicly/include",
        "deps/yaml/include",
        "deps/yoml",
    };
    for (include_dirs) |i| {
        h2o_exe.addIncludePath(.{
            .path = i,
        });
    }

    const lib_source_files = [_][]const u8{
        "deps/cloexec/cloexec.c",
        "deps/hiredis/async.c",
        "deps/hiredis/hiredis.c",
        "deps/hiredis/net.c",
        "deps/hiredis/read.c",
        "deps/hiredis/sds.c",
        "deps/libgkc/gkc.c",
        "deps/libyrmcds/close.c",
        "deps/libyrmcds/connect.c",
        "deps/libyrmcds/recv.c",
        "deps/libyrmcds/send.c",
        "deps/libyrmcds/send_text.c",
        "deps/libyrmcds/socket.c",
        "deps/libyrmcds/strerror.c",
        "deps/libyrmcds/text_mode.c",
        "deps/picohttpparser/picohttpparser.c",
        "deps/picotls/deps/cifra/src/blockwise.c",
        "deps/picotls/deps/cifra/src/chash.c",
        "deps/picotls/deps/cifra/src/curve25519.c",
        "deps/picotls/deps/cifra/src/drbg.c",
        "deps/picotls/deps/cifra/src/hmac.c",
        "deps/picotls/deps/cifra/src/sha256.c",
        "deps/picotls/lib/certificate_compression.c",
        "deps/picotls/lib/hpke.c",
        "deps/picotls/lib/pembase64.c",
        "deps/picotls/lib/picotls.c",
        "deps/picotls/lib/openssl.c",
        "deps/picotls/lib/cifra/random.c",
        "deps/picotls/lib/cifra/x25519.c",
        "deps/quicly/lib/cc-cubic.c",
        "deps/quicly/lib/cc-pico.c",
        "deps/quicly/lib/cc-reno.c",
        "deps/quicly/lib/defaults.c",
        "deps/quicly/lib/frame.c",
        "deps/quicly/lib/local_cid.c",
        "deps/quicly/lib/loss.c",
        "deps/quicly/lib/quicly.c",
        "deps/quicly/lib/ranges.c",
        "deps/quicly/lib/rate.c",
        "deps/quicly/lib/recvstate.c",
        "deps/quicly/lib/remote_cid.c",
        "deps/quicly/lib/retire_cid.c",
        "deps/quicly/lib/sendstate.c",
        "deps/quicly/lib/sentmap.c",
        "deps/quicly/lib/streambuf.c",

        "lib/common/cache.c",
        "lib/common/file.c",
        "lib/common/filecache.c",
        "lib/common/hostinfo.c",
        "lib/common/http1client.c",
        "lib/common/http2client.c",
        "lib/common/http3client.c",
        "lib/common/httpclient.c",
        "lib/common/memcached.c",
        "lib/common/memory.c",
        "lib/common/multithread.c",
        "lib/common/redis.c",
        "lib/common/serverutil.c",
        "lib/common/socket.c",
        "lib/common/socketpool.c",
        "lib/common/string.c",
        "lib/common/rand.c",
        "lib/common/time.c",
        "lib/common/timerwheel.c",
        "lib/common/token.c",
        "lib/common/url.c",
        "lib/common/balancer/roundrobin.c",
        "lib/common/balancer/least_conn.c",
        "lib/common/absprio.c",

        "lib/core/config.c",
        "lib/core/configurator.c",
        "lib/core/context.c",
        "lib/core/headers.c",
        "lib/core/logconf.c",
        "lib/core/proxy.c",
        "lib/core/request.c",
        "lib/core/util.c",

        "lib/handler/access_log.c",
        "lib/handler/compress.c",
        "lib/handler/compress/gzip.c",
        "lib/handler/errordoc.c",
        "lib/handler/expires.c",
        "lib/handler/fastcgi.c",
        "lib/handler/file.c",
        "lib/handler/h2olog.c",
        "lib/handler/headers.c",
        "lib/handler/headers_util.c",
        "lib/handler/http2_debug_state.c",
        "lib/handler/mimemap.c",
        "lib/handler/proxy.c",
        "lib/handler/connect.c",
        "lib/handler/redirect.c",
        "lib/handler/reproxy.c",
        "lib/handler/throttle_resp.c",
        "lib/handler/self_trace.c",
        "lib/handler/server_timing.c",
        "lib/handler/status.c",
        "lib/handler/status/events.c",
        "lib/handler/status/memory.c",
        "lib/handler/status/requests.c",
        "lib/handler/status/ssl.c",
        "lib/handler/status/durations.c",
        "lib/handler/configurator/access_log.c",
        "lib/handler/configurator/compress.c",
        "lib/handler/configurator/errordoc.c",
        "lib/handler/configurator/expires.c",
        "lib/handler/configurator/fastcgi.c",
        "lib/handler/configurator/file.c",
        "lib/handler/configurator/h2olog.c",
        "lib/handler/configurator/headers.c",
        "lib/handler/configurator/headers_util.c",
        "lib/handler/configurator/http2_debug_state.c",
        "lib/handler/configurator/proxy.c",
        "lib/handler/configurator/redirect.c",
        "lib/handler/configurator/reproxy.c",
        "lib/handler/configurator/throttle_resp.c",
        "lib/handler/configurator/self_trace.c",
        "lib/handler/configurator/server_timing.c",
        "lib/handler/configurator/status.c",
        "lib/http1.c",

        "lib/http2/cache_digests.c",
        "lib/http2/casper.c",
        "lib/http2/connection.c",
        "lib/http2/frame.c",
        "lib/http2/hpack.c",
        "lib/http2/scheduler.c",
        "lib/http2/stream.c",
        "lib/http2/http2_debug_state.c",

        "lib/http3/frame.c",
        "lib/http3/qpack.c",
        "lib/http3/common.c",
        "lib/http3/server.c",
    };
    const cc_warning_flags = [_][]const u8{
        "-Wall", "-Wno-unused-value", "-Wno-unused-function", "-Wno-nullability-completeness", "-Wno-expansion-to-defined", "-Werror=implicit-function-declaration", "-Werror=incompatible-pointer-types",
    };
    const default_c_flags = cc_warning_flags ++ &[_][]const u8{
        "-g3",
        "-DH2O_ROOT=\"${CMAKE_INSTALL_PREFIX}\"",
        "-DH2O_CONFIG_PATH=\"${CMAKE_INSTALL_FULL_SYSCONFDIR}/h2o.conf\"",
    };
    const h2o_cflags = default_c_flags ++ &[_][]const u8{
        "-std=c99",
        "-DH2O_USE_LIBUV=0",
    };
    h2o_exe.addCSourceFiles(.{
        .files = &lib_source_files,
        .flags = h2o_cflags,
    });

    const yaml_source_files = [_][]const u8{
        "deps/yaml/src/api.c",
        "deps/yaml/src/dumper.c",
        "deps/yaml/src/emitter.c",
        "deps/yaml/src/loader.c",
        "deps/yaml/src/parser.c",
        "deps/yaml/src/reader.c",
        "deps/yaml/src/scanner.c",
        "deps/yaml/src/writer.c",
    };
    h2o_exe.addCSourceFiles(.{ .files = &yaml_source_files, .flags = &.{
        "-std=c99",
        "-DH2O_USE_LIBUV=0",
    } });
    const brotli_source_files = [_][]const u8{
        "deps/brotli/c/common/dictionary.c",
        "deps/brotli/c/dec/bit_reader.c",
        "deps/brotli/c/dec/decode.c",
        "deps/brotli/c/dec/huffman.c",
        "deps/brotli/c/dec/state.c",
        "deps/brotli/c/enc/backward_references.c",
        "deps/brotli/c/enc/backward_references_hq.c",
        "deps/brotli/c/enc/bit_cost.c",
        "deps/brotli/c/enc/block_splitter.c",
        "deps/brotli/c/enc/brotli_bit_stream.c",
        "deps/brotli/c/enc/cluster.c",
        "deps/brotli/c/enc/compress_fragment.c",
        "deps/brotli/c/enc/compress_fragment_two_pass.c",
        "deps/brotli/c/enc/dictionary_hash.c",
        "deps/brotli/c/enc/encode.c",
        "deps/brotli/c/enc/entropy_encode.c",
        "deps/brotli/c/enc/histogram.c",
        "deps/brotli/c/enc/literal_cost.c",
        "deps/brotli/c/enc/memory.c",
        "deps/brotli/c/enc/metablock.c",
        "deps/brotli/c/enc/static_dict.c",
        "deps/brotli/c/enc/utf8_util.c",
        "lib/handler/compress/brotli.c",
    };
    h2o_exe.addCSourceFiles(.{ .files = &brotli_source_files, .flags = &.{
        "-std=c99",
        "-DH2O_USE_LIBUV=0",
    } });

    h2o_exe.addCSourceFiles(.{ .files = &.{
        "deps/neverbleed/neverbleed.c",
        "src/main.c",
        "src/ssl.c",
    }, .flags = &.{
        "-std=c99",
        "-DH2O_USE_LIBUV=0",
    } });
    h2o_exe.linkLibC();
    h2o_exe.linkLibrary(libz_dep.artifact("z"));
    h2o_exe.linkLibrary(openssl_dep.artifact("ssl"));
    h2o_exe.linkLibrary(openssl_dep.artifact("crypto"));

    b.installArtifact(h2o_exe);
}

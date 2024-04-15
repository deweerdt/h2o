const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("openssl", .{});
    upstream.qwe();

    const crypto = libcrypto(b, upstream, target, optimize);
    const ssl = libssl(b, upstream, target, optimize);

    crypto.installHeadersDirectory("include/crypto", "crypto");
    crypto.installHeadersDirectory("include/internal", "internal");
    ssl.installHeadersDirectory("include/openssl", "openssl");
    ssl.installHeadersDirectory("include_gen", "");
    b.installArtifact(crypto);
    b.installArtifact(ssl);
}

fn libcrypto(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "crypto",
        .target = target,
        .optimize = optimize,
    });
    lib.pie = true;
    switch (optimize) {
        .Debug, .ReleaseSafe => lib.bundle_compiler_rt = true,
        else => lib.root_module.strip = true,
    }
    lib.addCSourceFiles(.{
        .root = upstream.path("crypto/"),
        .files = &.{
            "cpuid.c","ctype.c",
    },
    .flags = &.{}});
}

fn libssl(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "ssl",
        .target = target,
        .optimize = optimize,
    });
    lib.pie = true;
    switch (optimize) {
        .Debug, .ReleaseSafe => lib.bundle_compiler_rt = true,
        else => lib.root_module.strip = true,
    }
    lib.addCSourceFiles(.{
        .root = upstream.path("ssl/"),
        .files = &.{
             "pqueue.c",
             "statem/statem_srvr.c",
             "statem/statem_clnt.c",
             "s3_lib.c",
             "s3_enc.c",
             "record/rec_layer_s3.c",
             "statem/statem_lib.c",
             "statem/extensions.c",
             "statem/extensions_srvr.c",
             "statem/extensions_clnt.c",
             "statem/extensions_cust.c",
             "s3_msg.c",
             "methods.c",
             "t1_lib.c",
             "t1_enc.c",
             "tls13_enc.c",
             "d1_lib.c",
             "record/rec_layer_d1.c",
             "d1_msg.c",
             "statem/statem_dtls.c",
             "d1_srtp.c",
             "ssl_lib.c",
             "ssl_cert.c",
             "ssl_sess.c",
             "ssl_ciph.c",
             "ssl_stat.c",
             "ssl_rsa.c",
             "ssl_asn1.c",
             "ssl_txt.c",
             "ssl_init.c",
             "ssl_conf.c",
             "ssl_mcnf.c",
             "bio_ssl.c",
             "ssl_err.c",
             "ssl_err_legacy.c",
             "tls_srp.c",
             "t1_trce.c",
             "ssl_utst.c",
             "record/ssl3_buffer.c",
             "record/ssl3_record.c",
             "record/dtls1_bitmap.c",
             "statem/statem.c",
             "record/ssl3_record_tls13.c",
             "tls_depr.c",
    },
    .flags = &.{}});
}


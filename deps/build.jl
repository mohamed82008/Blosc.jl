using BinaryProvider # requires BinaryProvider 0.3.0 or later
include("compile.jl")

# env var to force compilation from source, for testing purposes
const forcecompile = get(ENV, "FORCE_COMPILE_BLOSC", "no") == "yes"

# Parse some basic command-line arguments
const verbose = ("--verbose" in ARGS) || forcecompile
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, String["libblosc"], :libblosc),
]
verbose && forcecompile && Compat.@info("Forcing compilation from source.")

# Download binaries from hosted location
bin_prefix = "https://github.com/stevengj/BloscBuilder/releases/download/v1.14.3+3"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, :glibc) => ("$bin_prefix/Blosc.aarch64-linux-gnu.tar.gz", "bbb1afa92c73f2b4d914cf2905bb2a382eb7f6c57ee717ca0b5f00cd62556e55"),
    Linux(:aarch64, :musl) => ("$bin_prefix/Blosc.aarch64-linux-musl.tar.gz", "e60af968af91e06070aa400b6cdb21542e76de8796917177b720dd6f8e88d6ce"),
    Linux(:armv7l, :glibc, :eabihf) => ("$bin_prefix/Blosc.arm-linux-gnueabihf.tar.gz", "b03c23a33489865a5dceba9b2c25ef9eae0fc15c2dcd85b89d46c356fce1817e"),
    Linux(:armv7l, :musl, :eabihf) => ("$bin_prefix/Blosc.arm-linux-musleabihf.tar.gz", "0746daec6e786a436f7b9506d61b22132ad3b2641ce134b4b737908b11ba8f4f"),
    Linux(:i686, :glibc) => ("$bin_prefix/Blosc.i686-linux-gnu.tar.gz", "a1e6bbcc978548951f8d225c19e9f2983242f6000ec3b118054ba9bbbd73592e"),
    Linux(:i686, :musl) => ("$bin_prefix/Blosc.i686-linux-musl.tar.gz", "46a5f50fad695aacb25bd219ffc56a56e1dfe25809e59a2646e373c6eddffd38"),
    Windows(:i686) => ("$bin_prefix/Blosc.i686-w64-mingw32.tar.gz", "87f19f8ce7bfe5a6d23554aaa1050dd473b1bb07811e01683882e95f19bd0ff8"),
    Linux(:powerpc64le, :glibc) => ("$bin_prefix/Blosc.powerpc64le-linux-gnu.tar.gz", "9dd7e8cea351e40d74e16bb1bc32408ef9339d0b609905be225cd71a84465a6f"),
    MacOS(:x86_64) => ("$bin_prefix/Blosc.x86_64-apple-darwin14.tar.gz", "dbd73b76a854d109e58fa6845dd1911ebc666b6cf854efb229f0d1e590cf0d1b"),
    Linux(:x86_64, :glibc) => ("$bin_prefix/Blosc.x86_64-linux-gnu.tar.gz", "266a4b83ed7de773b3337b73ca6aef0586f2d133e561cea664823dd6a0dab929"),
    Linux(:x86_64, :musl) => ("$bin_prefix/Blosc.x86_64-linux-musl.tar.gz", "941611c174fae8578fa3ffbb968940523f22603cb3bbed8cb32f4f1d46b0177c"),
    Windows(:x86_64) => ("$bin_prefix/Blosc.x86_64-w64-mingw32.tar.gz", "d43bda44f1a250d195f4a3d3814864571a9dfba9a41e792faca068c6618c4160"),
)

# source code tarball and hash for fallback compilation
source_url = "https://github.com/Blosc/c-blosc/archive/v1.14.3.tar.gz"
source_hash = "7217659d8ef383999d90207a98c9a2555f7b46e10fa7d21ab5a1f92c861d18f7"

# Install unsatisfied or updated dependencies:
unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
if haskey(download_info, platform_key()) && !forcecompile
    url, tarball_hash = download_info[platform_key()]
    if !isinstalled(url, tarball_hash; prefix=prefix)
        # Download and install binaries
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)

        # check again whether the dependency is satisfied, which
        # may not be true if dlopen fails due to a libc++ incompatibility (#50)
        unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
    end
end

if unsatisfied || forcecompile
    # Fall back to building from source, giving the library a different name
    # so that it is not overwritten by BinaryBuilder downloads or vice-versa.
    libname = "libblosc_from_source"
    products = [ LibraryProduct(prefix, [libname], :libblosc) ]
    source_path = joinpath(prefix, "downloads", basename(source_url))
    if !isfile(source_path) || !verify(source_path, source_hash; verbose=verbose) || !satisfied(products[1]; verbose=verbose)
        compile(libname, source_url, source_hash, prefix=prefix, verbose=verbose)
    end
end

# Write out a deps.jl file that will contain mappings for our products
write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)

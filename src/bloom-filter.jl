using Compat
using Mmap: mmap
using Printf

include("probabilities.jl")

mutable struct BloomFilter
    array::BitArray
    k::Int
    capacity::Int
    error_rate::Float64
    n_bits::Int
    mmap_location::AbstractString
end

### Hash functions (uses 2 hash method)
# Uses MurmurHash on 64-bit systems so sufficient randomness/speed
# Get the nth hash of a string using the formula hash_a + n * hash_b
# which uses 2 hash functions vs. k and has comparable properties
# See Kirsch and Mitzenmacher, 2008: http://www.eecs.harvard.edu/~kirsch/pubs/bbbf/rsa.pdf
function hash_n(key::T, k::Int, max::Int) where {T}
    a_hash = hash(key, UInt(0))
    b_hash = hash(key, UInt(170))
    hashes = Array{UInt, 1}(undef, k)
    for i in 1:k
        hashes[i] = mod(a_hash + i * b_hash, max) + 1
    end
    return hashes
end

### Bloom filter constructors
# Constructor group #1: (optional IOStream / string to mmap-array), capacity, bits per element, k
# Note that this inserts NaN for the error rate, as this module does not include functionality
# for calculating error rates for any arbitrary bits per element and k (only a subset, see #2 below)
# USE CASES: Advanced use only. Not recommended as default constructor choice.
function BloomFilter(capacity::Int, bits_per_elem::Int, k_hashes::Int)
    n_bits = capacity * bits_per_elem
    BloomFilter(falses((1, n_bits)), k_hashes, capacity, NaN, n_bits, "")
end

function BloomFilter(mmap_handle::IOStream, capacity::Int, bits_per_elem::Int, k_hashes::Int)
    n_bits = capacity * bits_per_elem
    mb = mmap(mmap_handle, BitArray, n_bits)
    BloomFilter(mb, k_hashes, capacity, NaN, n_bits, mmap_handle.name)
end

function BloomFilter(mmap_string::AbstractString, capacity::Int, bits_per_elem::Int, k_hashes::Int)
    if isfile(mmap_string)
        mmap_handle = open(mmap_string, "r+")
    else
        mmap_handle = open(mmap_string, "w+")
    end
    BloomFilter(mmap_handle, capacity, bits_per_elem, k_hashes)
end

# Constructor group #2: (optional IOStream / string to mmap-array), capacity, error rate, k hashes
# Looks up the optimal number of bits per element given an error rate and specified k in a pre-calculated
# probability table. Note that k must be <= 12 or an error will be thrown. Similarly, this method
# does not support Bloom filter construction where more than 4 bytes are required per element
# (though that can manually be accomplished with one of the above constrcutors).
# USE CASES: Recommended for most applications, but carries modest space-tradeoff for slightly faster operation with fewer hashes
function BloomFilter(capacity::Int, error_rate::Float64, k_hashes::Int)
    bits_per_elem, error_rate = get_k_error(error_rate, k_hashes)
    n_bits = capacity * bits_per_elem
    BloomFilter(falses((n_bits, 1)), k_hashes, capacity, error_rate, n_bits, "")
end

function BloomFilter(mmap_handle::IOStream, capacity::Int, error_rate::Float64, k_hashes::Int)
    bits_per_elem, error_rate = get_k_error(error_rate, k_hashes)
    n_bits = capacity * bits_per_elem
    mb = mmap(mmap_handle, BitArray, n_bits)
    BloomFilter(mb, k_hashes, capacity, error_rate, n_bits, mmap_handle.name)
end

function BloomFilter(mmap_string::AbstractString, capacity::Int, error_rate::Float64, k_hashes::Int)
    if isfile(mmap_string)
        mmap_handle = open(mmap_string, "r+")
    else
        mmap_handle = open(mmap_string, "w+")
    end
    BloomFilter(mmap_handle, capacity, error_rate, k_hashes)
end

# Constructor group #3: (optional IOStream / string to mmap-array), capacity, error rate
# Computes an optimal k for a given error rate, where k is selected to minimize the overall
# space required for the Bloom filter. In practice, k may be larger than desired and require
# additional memory accesses.
# USE CASES: Recommended when extreme space efficiency is required, and modestly slower insertions
# and lookups are tolerable.
function BloomFilter(capacity::Int, error_rate::Float64)
    bits_per_elem = round(Int, ceil(-1.0 * (log(error_rate) / (log(2) ^ 2))))
    k_hashes = round(Int, log(2) * bits_per_elem)  # Note: ceil() would be strictly more conservative
    n_bits = capacity * bits_per_elem
    BloomFilter(falses((1, n_bits)), k_hashes, capacity, error_rate, n_bits, "")
end

function BloomFilter(mmap_handle::IOStream, capacity::Int, error_rate::Float64)
    bits_per_elem = round(Int, ceil(-1.0 * (log(error_rate) / (log(2) ^ 2))))
    k_hashes = round(Int, log(2) * bits_per_elem)  # Note: ceil() would be strictly more conservative
    n_bits = capacity * bits_per_elem
    mb = mmap(mmap_handle, BitArray, n_bits)
    BloomFilter(mb, k_hashes, capacity, error_rate, n_bits, mmap_handle.name)
end

function BloomFilter(mmap_string::AbstractString, capacity::Int, error_rate::Float64)
    if isfile(mmap_string)
        mmap_handle = open(mmap_string, "r+")
    else
        mmap_handle = open(mmap_string, "w+")
    end
    BloomFilter(mmap_handle, capacity, error_rate)
end

### Bloom filter functions: insert!, add! (alias to insert), contains, and show
function add!(bf::BloomFilter, key::T) where {T}
    hashes = hash_n(key, bf.k, bf.n_bits)
    for h in hashes
        bf.array[h] = 1
    end
end

function Base.in(key::T, bf::BloomFilter) where {T}
    hashes = hash_n(key, bf.k, bf.n_bits)
    for h in hashes
        if bf.array[h] != 1
            return false
        end
    end
    return true
end

@deprecate contains(bf::BloomFilter, key::T) where {T} Base.in(key, bf)

# Vector variants
function add!(bf::BloomFilter, keys::Vector{T}) where {T}
    for key in keys
        add!(bf, key)
    end
end

function Base.in(keys::Vector{T}, bf::BloomFilter) where {T}
    m = length(keys)
    res = falses(m)
    for i in 1:m
        res[i] = in(keys[i], bf)
    end
    return res
end

# Print
function Base.show(io::IO, bf::BloomFilter)
    @printf "Bloom filter with capacity %d, " bf.capacity
    @printf "error rate of %.2f%%, and k of %d.\n" (bf.error_rate * 100) (bf.k)
    @printf "Total bits required: %d (%.1f / element).\n" bf.n_bits (bf.n_bits / bf.capacity)
    if bf.mmap_location != ""
        @printf "Bloom filter is backed by mmap at %s." bf.mmap_location
    else
        @printf "Bloom filter is in-memory."
    end
end

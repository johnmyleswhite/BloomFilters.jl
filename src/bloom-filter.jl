using Compat

include("probabilities.jl")

type BloomFilter
    array::BitArray
    k::Int
    capacity::Int
    error_rate::Float64
    n_bits::Int
    mmap_location::String
end

### Hash functions (uses 2 hash method)
# Uses MurmurHash on 64-bit systems so sufficient randomness/speed
# Get the nth hash of a string using the formula hash_a + n * hash_b
# which uses 2 hash functions vs. k and has comparable properties
# See Kirsch and Mitzenmacher, 2008: http://www.eecs.harvard.edu/~kirsch/pubs/bbbf/rsa.pdf
function hash_n(key::Any, k::Int, max::Int)
    a_hash = hash(key, @compat UInt(0))
    b_hash = hash(key, @compat UInt(170))
    hashes = Array(Uint, k)
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
    mb = mmap_bitarray((n_bits, 1), mmap_handle)
    BloomFilter(mb, k_hashes, capacity, NaN, n_bits, mmap_handle.name)
end

function BloomFilter(mmap_string::String, capacity::Int, bits_per_elem::Int, k_hashes::Int)
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
    mb = mmap_bitarray((n_bits, 1), mmap_handle)
    BloomFilter(mb, k_hashes, capacity, error_rate, n_bits, mmap_handle.name)
end

function BloomFilter(mmap_string::String, capacity::Int, error_rate::Float64, k_hashes::Int)
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
    mb = mmap_bitarray((n_bits, 1), mmap_handle)
    BloomFilter(mb, k_hashes, capacity, error_rate, n_bits, mmap_handle.name)
end

function BloomFilter(mmap_string::String, capacity::Int, error_rate::Float64)
    if isfile(mmap_string)
        mmap_handle = open(mmap_string, "r+")
    else
        mmap_handle = open(mmap_string, "w+")
    end
    BloomFilter(mmap_handle, capacity, error_rate)
end

### Bloom filter functions: insert!, add! (alias to insert), contains, and show
function add!(bf::BloomFilter, key::Any)
    hashes = hash_n(key, bf.k, bf.n_bits)
    for h in hashes
        bf.array[h] = 1
    end
end

function Base.contains(bf::BloomFilter, key::Any)
    hashes = hash_n(key, bf.k, bf.n_bits)
    for h in hashes
        if bf.array[h] != 1
            return false
        end
    end
    return true
end

Base.in(key::Any, bf::BloomFilter) = contains(bf, key)

# Vector variants
function add!(bf::BloomFilter, keys::Vector{Any})
    for key in keys
        add!(bf, key)
    end
end

function Base.contains(bf::BloomFilter, keys::Vector{Any})
    m = length(keys)
    res = falses(m)
    for i in 1:m
        res[i] = contains(bf, keys[i])
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

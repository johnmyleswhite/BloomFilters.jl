BloomFilters.jl
===============

[![Build Status](https://travis-ci.org/johnmyleswhite/BloomFilters.jl.png)](https://travis-ci.org/johnmyleswhite/BloomFilters.jl)

*Please note: The API for version 0.1.0 of this package has changed substantially from version 0.0.1. Please review the below README and accompanying library documentation.*

Bloom filter implementation in Julia. Supports insertion (`add!`) and probabilistic membership queries (`contains`) for sets using an in-memory or mmap'd bit array. When an element `x` is inserted into a Bloom filter, set membership queries will always correctly return `true` for `x` (i.e., there are no false negatives). Bloom filter membership queries do, however, occassionally return `true` for a `y` not inserted into the data structure (i.e., false positives are possible). With this cost comes remarkable space efficiency: Bloom filters can store set membership using only 10 bits per element at a 1.00% error rate or 20 bits per element at a 0.01% error rate. This space requirement is irrespective of the size or length of the inserted elements (e.g., one can store a set of URLs using only a handful of bits per URL).


Forthcoming features include:
* Better persistence (only the bit array is automatically saved when using the mmap-backed version; parameters must be separately stored or hard-coded)
* Support for arbitrary numbers of hash functions (*k* > 12)


Quickstart
==========
Quick functionality demo:
```
using BloomFilters


bf = BloomFilter(1000, 0.001)  # Create an in-memory Bloom filter
							   # with a capacity of 1K elements and
							   # expected error rate of 0.1%

add!(bf, "My first element.")
contains(bf, "My first element.")   # Returns true
contains(bf, "My second element.")  # Returns false
show(bf)

# Prints:
# Bloom filter with capacity 1000, error rate of 0.10, and k of 10.
# Total bits required: 15000 (15.0 / element).
# Bloom filter is in-memory.

```

By default, the Bloom filter will be constructed using an optimal number of k hash functions, which minimizes the expected false positive rate per required bit of storage. In many cases, however, it may be advantegous to specify a smaller value of k in order to save time hashing and performing subsequent memory accesses. Alternatively, one may want to explicitly set the number of bits to use per element _and_ k, rather than constructing the filter by passing a target error rate.


The `BloomFilters` module supports all 3 of these patterns:

```
# Constructor pattern #1: Pass capacity and error rate
bf1 = BloomFilter(1000, 0.001)

# Constructor pattern #2: Pass capacity, error rate, and k
bf2 = BloomFilter(1000, 0.001, 6)  # vs. the optimal number of 10 if not specified as in bf1

# Constructor pattern #3: Pass capacity, bits per element, and k, but not the error rate
bf3 = BloomFilter(1000, 16, 6)  # Same as bf2, but will *not* compute the error rate and display NaN when show() is called
```


In addition to this, basic persistence support is provided via optionally using an mmap-backed bit array. This works with each of the above methods by either passing a string of the mmap filepath or an `IOStream`:

```
### With an IOStream
# Note that "w+" needs to be passed as the second argument to open() if creating
# a new mmap-backed Bloom filter, or "r+" if opening an already created one
bf4 = BloomFilter(open("/tmp/small_bloom_filter.array", "w+"), 1000, 0.001)

### With a string filepath
# Note this creates the bit array if it doesn't exist or opens it if previously created
bf5 = BloomFilter("/tmp/small_bloom_filter_two.array", 1000, 0.001)

show(bf5)

# Prints:
# Bloom filter with capacity 1000, error rate of 0.10, and k of 10.
# Total bits required: 15000 (15.0 / element).
# Bloom filter is backed by mmap at <file /tmp/small_bloom_filter_two.array>.
```

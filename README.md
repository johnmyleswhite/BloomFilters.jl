BloomFilters.jl
===============

Bloom filters are a probabilistic data structure that can be used
to test the inclusion and exclusion of items in a list. This is
achieved by using an array of n bits and k distinct hash functions
to map every item in the initial list into an n-bit pattern. The
Bloom filter stores the Boolean OR of these bit patterns and hence
recognizes every item it has every seen. It also falsely recognizes
some elements that it has never seen. It never generates false negatives.

# Usage

    using BloomFilters

    n, k = 10, 5
    filter = BloomFilter(n, k)

    add!(filter, "A")

    contains(filter, "A")
    contains(filter, "B")
    contains(filter, "C")

    add!(filter, ["B", "C"])

    contains(filter, "A")
    contains(filter, "B")
    contains(filter, "C")

    for item in ["A", "B", "C", "D", "E", "F", "G"]
    	@printf "Filter contains %s: " item
    	@printf "%s\n" contains(filter, item)
    end

One of the complexities of using Bloom filters stems from the false positives seen above. If either n or k are not large enough, some items not in the list will be identified as being in the list. This can be resolved by increasing both n and k as shown below:

    n, k = 100, 25
    filter = BloomFilter(n, k)

    add!(filter, ["A", "B", "C"])

    for item in ["A", "B", "C", "D", "E", "F", "G"]
    	@printf "Filter contains %s: " item
    	@printf "%s\n" contains(filter, item)
    end

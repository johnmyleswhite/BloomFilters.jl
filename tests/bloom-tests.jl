# Testing note: only run this file once per Julia session
# otherwise the in-memory or mmap'd files can get multiple
# sets of keys added to them and become too full
using BloomFilters

# First set up 9 sample Bloom filters using different constructors
# (Ordered as in bloom-filter.jl)

# Raw construction
bf0 = BloomFilter(BitVector(10), 4, 10, 0.01, 20, "")

# First group of constructors: capacity, bits per element, k
bf1 = BloomFilter(1000, 20, 4)
bf2 = BloomFilter(open("/tmp/test_array1.array", "w+"), 1000, 20, 4)
bf3 = BloomFilter("/tmp/test_array2.array", 1000, 20, 4)

# Second group of constructors: capacity, error rate, k
bf4 = BloomFilter(1000, 0.01, 5)
bf5 = BloomFilter(open("/tmp/test_array3.array", "w+"), 1000, 0.01, 5)
bf6 = BloomFilter("/tmp/test_array4.array", 1000, 0.01, 5)

# Third group of constructors: capacity and error rate only,
# computes optimal k from a space efficiency perspective
bf7 = BloomFilter(1000, 0.01)
bf8 = BloomFilter(open("/tmp/test_array5.array", "w+"), 1000, 0.01)
bf9 = BloomFilter("/tmp/test_array6.array", 1000, 0.01)

# Now create a larger in-memory Bloom filter and an mmap-backed one for testing
n = 100000
bfa = BloomFilter(n, 0.001, 5)
bfb = BloomFilter("/tmp/test_array_lg.array", n, 0.001, 5)

# Test with random strings
random_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
test_keys = Array(String, n)
for i in 1:n
    temp_str = ""
    for j in 1:8
        temp_str = string(temp_str, random_chars[rand(1:62)])
    end
    test_keys[i] = temp_str
end


println("For insertions:")
@time(
for test_key in test_keys
    add!(bfa, test_key)
end
)

println("For lookups:")
@time(
for test_key in test_keys
    assert(contains(bfa, test_key))
end
)

println("For insertions (mmap-backed):")
@time(
for test_key in test_keys
    add!(bfb, test_key)
end
)

println("For lookups (mmap-backed):")
@time(
for test_key in test_keys
    assert(contains(bfb, test_key))
end
)


# Test vectorized add!/contains
bf_vector = BloomFilter(n, 0.001, 5)
add!(bf_vector, test_keys)
assert(all(contains(bf_vector, test_keys)))


# Test hashing non-string objects and non-string vectors
numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
add!(bf_vector, numbers)
assert(all(contains(bf_vector, numbers)))



# Probabilistic tests – note these may fail every once in a while...
# (but very very rarely)
test_keys_p = Array(String, n)
for i in 1:n
    temp_str = ""
    for j in 1:9  # Longer so not in by definition
        temp_str = string(temp_str, random_chars[rand(1:62)])
    end
    test_keys_p[i] = temp_str
end

false_positives_a = 0
false_positives_b = 0
for test_key_p in test_keys_p
    if contains(bfa, test_key_p)
        false_positives_a += 1
    end
    if contains(bfb, test_key_p)
        false_positives_b += 1
    end
end

# Less than 2x requested false positives... (to avoid failing too often out of pure chance)
@printf "System is %s-bit\n" string(typeof(1))[4:5]
@printf "In-memory Bloom is %.2f%% full\n" (100 * sum(bfa.array) / bfa.n_bits)
@printf "%d false positives in %d tests\n" false_positives_a n
@printf "Error rate for in-memory Bloom filter %.2f%%\n" (bfa.error_rate * 100)
# assert((false_positives_a / n) <= (2.0 * bfa.error_rate))

@printf "Mmap'd Bloom is %.2f%% full\n" (100 * sum(bfb.array) / bfb.n_bits)
@printf "%d false positives in %d tests\n" false_positives_b n
@printf "Error rate for in-memory Bloom filter %.2f%%\n" (bfb.error_rate * 100)
# assert((false_positives_b / n) <= (2.0 * bfb.error_rate))
assert(false_positives_a == false_positives_b)  # Must be true since bfa and bfb should be identical at bit-level


# Test re-opening bfb
bfb = 0
gc()

bfb = BloomFilter(open("/tmp/test_array_lg.array", "r+"), n, 0.001, 5)
println("For lookups after re-opening (mmap-backed):")
@time(
for test_key in test_keys
    assert(contains(bfb, test_key))
end
)

bfb = 0
gc()

bfb = BloomFilter("/tmp/test_array_lg.array", n, 0.001, 5)
println("For lookups after re-opening second time (mmap-backed):")
@time(
for test_key in test_keys
    assert(contains(bfb, test_key))
end
)


## Note: This doesn't work as hash(x::String, seed::Int)
## is only defined for strings in dict.jl
# # Test insertions of non-string types
# test_other_a = 17    # Int
# test_other_b = 15.6  # Float
# test_other_c = "String" #("Tuples", "of", "strings")

# # Test alias'd command
# add!(bfb, test_other_a)
# add!(bfb, test_other_b)
# add!(bfb, test_other_c)

# assert(contains(bfb, test_other_a))
# assert(contains(bfb, test_other_b))
# assert(contains(bfb, test_other_b))

# Clean up mmap-backed temp files (otherwise can end up re-opening them and writing multiple key sets to one file!)
rm("/tmp/test_array1.array")
rm("/tmp/test_array2.array")
rm("/tmp/test_array3.array")
rm("/tmp/test_array4.array")
rm("/tmp/test_array5.array")
rm("/tmp/test_array6.array")
rm("/tmp/test_array_lg.array")

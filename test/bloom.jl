using BloomFilters

n = 10
k = 5
keys = ["A", "B", "C"]

mask = falses(n)
hashes = Array(Function, k)
hashes[1] = s -> mod(1 * hash(s), n) + 1
hashes[2] = s -> mod(2 * hash(s), n) + 1
hashes[3] = s -> mod(3 * hash(s), n) + 1
hashes[4] = s -> mod(4 * hash(s), n) + 1
hashes[5] = s -> mod(5 * hash(s), n) + 1

filter = BloomFilter(mask, hashes)
filter = BloomFilter(n, hashes)
filter = BloomFilter(mask, k)
filter = BloomFilter(n, k)

add!(filter, keys)

for i in 1:length(keys)
	@assert contains(filter, keys[i])
end

@assert !contains(filter, "D")

n = 10
k = 5
keys = ["A", "B", "C"]

filter = BloomFilter(n, k)

add!(filter, keys)

for i in 1:length(keys)
	@assert contains(filter, keys[i])
end

@assert !contains(filter, "D")

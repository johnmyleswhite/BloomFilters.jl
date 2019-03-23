module BloomFilters
	export BloomFilter, add!
	
	if VERSION < v"1.0.0"
		import Base: contains
	else
		export contains	
	end

	include("bloom-filter.jl")
end

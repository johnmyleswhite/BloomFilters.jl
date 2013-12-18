test_path = joinpath(Pkg.dir("BloomFilters"), "test")
for test_file in readdir(test_path)
	if test_file != "runtests.jl"
    	include(joinpath(test_path, test_file))
    end
end

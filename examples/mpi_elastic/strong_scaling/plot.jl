using PyPlot
using DelimitedFiles
using PyCall 

mpl = pyimport("tikzplotlib")
d = readdlm("timing.txt")
idx = sortperm(d[:,1])
d = d[idx,:]

close("all")
plot(d[:,1], 3.693 * ones(length(d[:,1])), "--", label="Fortran")
loglog(d[:,1], d[:,2], "o-", label="ADSeismic MPI")
legend()
xlabel("Number of Processors")
ylabel("Time (sec)")
xticks(d[:,1], Int.(d[:,1]))
grid("on", which="both", linestyle=":")
savefig("elastic_time_forward.png")

close("all")
loglog(d[:,1], d[:,3], "o-", color ="orange", label="ADSeismic MPI")
legend()
xlabel("Number of Processors")
ylabel("Time (sec)")
xticks(d[:,1], Int.(d[:,1]))
grid("on", which="both", linestyle=":")
savefig("elastic_time_backward.png")


close("all")
loglog(d[:,1], d[:,2], "o-", label="Forward")
loglog(d[:,1], d[:,3], "o-", color ="orange", label="Backward")
legend()
xlabel("Number of Processors")
ylabel("Time (sec)")
xticks(d[:,1], Int.(d[:,1]))
grid("on", which="both", linestyle=":")
savefig("elastic_time_forward_and_backward.png")
mpl.save("../figures/elastic_time_forward_and_backward.tex")

close("all")
figure(figsize=(10,4))
subplot(121)
title("Forward")
loglog(d[:,1], d[1,2]./d[:,2], "o-", label="Speedup")
loglog(d[:,1], d[1,2]./(d[:,2].*d[:,1]), "o-", label="Efficiency")
legend()
xlabel("Number of Processors")
ylabel("Time (sec)")
xticks(d[:,1], Int.(d[:,1]))
grid("on", which="both", linestyle=":")

subplot(122)
title("Backward")
loglog(d[:,1], d[1,3]./d[:,3], "o-", label="Speedup")
loglog(d[:,1], d[1,3]./(d[:,3].*d[:,1]), "o-", label="Efficiency")
legend()
xlabel("Number of Processors")
ylabel("Time (sec)")
xticks(d[:,1], Int.(d[:,1]))
grid("on", which="both", linestyle=":")

savefig("elastic_speedup_and_efficiency.png")
mpl.save("../figures/elastic_speedup_and_efficiency.tex")


# --------------------------------------------------------------------------
# ACE.jl and SHIPs.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------



@testset "RepulsiveCore" begin

##

using SHIPs
using Printf, Test, LinearAlgebra, JuLIP, JuLIP.Testing
using JuLIP: evaluate, evaluate_d
using JuLIP.Potentials: i2z, numz
using JuLIP.MLIPs: combine

randr() = 1.0 + rand()
randcoeffs(B) = (rand(length(B)) .* (1:length(B)) .- 0.2).^(-2)


##
@info("--------------- Testing RepulsiveCore Implementation ---------------")

at = bulk(:W, cubic=true) * 3
rattle!(at, 0.03)
r0 = rnn(:W)
z = atomic_number(:W)

maxdeg = 8
r0 = 1.0
rcut = 3.0

Pr = transformed_jacobi(maxdeg, PolyTransform(1, r0), rcut; pcut = 2)
pB = SHIPs.PairPotentials.PolyPairBasis(Pr, :W)
coeffs = randcoeffs(pB)
V = combine(pB, coeffs)

## try out the repulsive potential
Vfit = V

ri = 2.1
@show (@D Vfit(ri))
e0 = Vfit(ri) - 1.0
Vrep = SHIPs.PairPotentials.RepulsiveCore(Vfit, ri)

rout = range(ri+1e-15, 4.0, length=100)
println(@test all(Vfit(r) == Vrep(r,z,z) for r in rout))
rin = range(0.5, ri, length=100)
println(@test all(Vrep.Vin[1](r) == Vrep(r,z,z) for r in rin))

@info("JuLIP FD test")
println(@test JuLIP.Testing.fdtest(Vrep, at))

@info("check scaling")
println(@test energy(Vfit, at) ≈ energy(Vrep, at))

##


@info("--------------- Multi-Species RepulsiveCore ---------------")

at = bulk(:W, cubic=true) * 3
at.Z[2:3:end] .= atomic_number(:Fe)
rattle!(at, 0.03)
r0 = rnn(:W)

Pr = transformed_jacobi(maxdeg, PolyTransform(1, r0), rcut; pcut = 2)
pB = SHIPs.PairPotentials.PolyPairBasis(Pr, [:W, :Fe])
coeffs = randcoeffs(pB)
V = combine(pB, coeffs)


## try out the repulsive potential
Vfit = V

ri = 2.1
z1 = AtomicNumber(26)
z2 = AtomicNumber(74)
@show @D Vfit(ri, z1, z2)
e0 = min(Vfit(ri, z1, z2), Vfit(ri, z1, z1), Vfit(ri, z2, z2)) - 1.0
Vrep = SHIPs.PairPotentials.RepulsiveCore(Vfit, ri, e0)


for (z, z0) in zip([z1, z1, z2], [z1, z2, z2])
   i, i0 = JuLIP.Potentials.z2i(Vfit, z), JuLIP.Potentials.z2i(Vfit, z0)
   rout = range(ri+1e-15, 4.0, length=100)
   println(@test all(Vfit(r, z, z0) == Vrep(r, z, z0) for r in rout))
   rin = range(0.5, ri, length=100)
   println(@test all(Vrep.Vin[i,i0](r) == Vrep(r, z, z0) for r in rin))
end

##

@info("JuLIP FD test")
println(@test JuLIP.Testing.fdtest(Vrep, at))

@info("check scaling")
println(@test energy(Vfit, at) ≈ energy(Vrep, at))

@info("check FIO")
println(@test all(JuLIP.Testing.test_fio(Vrep)))

##

end

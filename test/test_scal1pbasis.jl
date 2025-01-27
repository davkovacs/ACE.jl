
@testset "Scalar1PBasis" begin 

##
using ACE
using Printf, Test, LinearAlgebra, StaticArrays
using ACE: evaluate, evaluate_d, Rn1pBasis, Ylm1pBasis,
      EuclideanVectorState, Product1pBasis
using Random: shuffle
using ACEbase.Testing: dirfdtest, fdtest, print_tf

##

maxdeg = 10 
r0 = 1.0 
rcut = 3.0 
trans = trans = PolyTransform(1, r0)
bscal = ACE.scal1pbasis(:x, :k, maxdeg, trans, rcut)

ACE.evaluate_d(bscal, 1.0)

##

end
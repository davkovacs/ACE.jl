
# --------------------------------------------------------------------------
# ACE.jl and SHIPs.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------


import JuLIP: evaluate!, evaluate_d!, SVec
import SHIPs: alloc_B, alloc_dB

# ------------------------------------------------------------
#   Fourier Basis evaluation

struct FourierBasis{T}
   deg::Int
   _fltt::Type{T}
end

FourierBasis(deg::Integer) = FourierBasis(deg, Float64)


Base.eltype(::FourierBasis{T}) where {T} = T
Base.length(fB::FourierBasis) = 2 * fB.deg + 1

# Dict(fB::FourierBasis) = Dict(
#       "__id__" => "SHIPs_FourierBasis",
#       "deg" => deg,
#       "fltt" => "$(fG._fltt)"
#    )
#
# FourierBasis(D::Dict) = FourierBasis(D["deg"], D["fltt"])
# FourierBasis(deg::Integer, fltt::AbstractString) =
#       FourierBasis(deg, eval(Meta.parse(fltt)))
#
# convert(::Val{:SHIPs_FourierBasis}, D::Dict) = FourierBasis(D)


alloc_B(fB::FourierBasis{T}) where {T}  = zeros(Complex{T}, length(fB))
alloc_dB(fB::FourierBasis{T}, args...) where {T} = zeros(SVec{2,Complex{T}}, length(fB))

# specify ordering
cyl_l2i(l, maxL) = maxL + 1 + l  # = i
cyl_i2l(i, maxL) = i - maxL - 1

function evaluate!(P, _::Nothing, fB::FourierBasis,
                   c::CylindricalCoordinates{T}) where {T}
   @assert length(P) >= length(fB)
   maxL = fB.deg
   z = c.cosθ + im * c.sinθ
   zl = one(T) + im * zero(T)
   P[cyl_l2i(0, maxL)] = zl
   for l = 1:maxL
      zl *= z
      P[cyl_l2i( l, maxL)] = zl
      P[cyl_l2i(-l, maxL)] = conj(zl)
   end
   return P
end

# we only return ∂Pl/∂x̂ since
#     ∂Pl/∂ŷ = ∂Pl/∂z * ∂z / ∂ŷ
#            = im * ∂Pl/∂z
#            = im * ∂Pl/∂x̂
function evaluate_d!(P, dP, _::Nothing, fB::FourierBasis,
                     c::CylindricalCoordinates{T}) where {T}
   @assert length(P) >= length(fB)
   maxL = fB.deg
   z = c.cosθ + im * c.sinθ    # z = x̂ + i ŷ
   zl = one(T) + im * zero(T)  # zl = z^l -> initialise to z^0 = 1
   P[cyl_l2i(0, maxL)] = zl
   dP[cyl_l2i(0, maxL)] =  SVec(zero(T), zero(T))

   for l = 1:maxL
      # ∂P_{ l}/∂x̂ = l z^(l-1)
      # ∂P_{-l}/∂x̂ = l z̄^(l-1)
      dP[cyl_l2i( l, maxL)] = SVec(l * zl,  im * l * zl)
      dP[cyl_l2i(-l, maxL)] = SVec(l * conj(zl), -im * l * conj(zl))

      zl *= z  # zl = z^l
      P[cyl_l2i( l, maxL)] = zl
      P[cyl_l2i(-l, maxL)] = conj(zl)

      # dP[cyl_l2i( l, maxL)] =  im * l * zl
      # dP[cyl_l2i(-l, maxL)] = -im * l * conj(zl)
   end
   return P
end
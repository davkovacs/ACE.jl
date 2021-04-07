using StaticArrays
using LinearAlgebra: norm, rank, svd, Diagonal
using ACE, StaticArrays, ACE.SphericalHarmonics;
using ACE.SphericalHarmonics: index_y;
using ACE.Rotations3D
using ACE: evaluate
using Combinatorics: permutations

SH = SphericalHarmonics.SHBasis(5);

nn = SVector(1,2,2);
ll = SVector(1,2,2);
mm = SVector(-1,2);
kk = SVector(1,-2);
R = randn(SVector{15, Float64});

## Stucture Orbitaltype is nothing but the SphericalVector
#  I'd like to add some subset of SphericalVector so that
#  we could classify the blocks that we focus on...

abstract type Orbitaltype end

struct Orbt <: Orbitaltype
    val::Int64
end
φ  = Orbt(1);

# Todo: In fact, l index can be neglected!!
"""
`D_Index` forms the indices of each entry in rotation D matrix
We are not interested in the exact value but the indices only
"""
struct D_Index
	l::Int64
	μ::Int64
	m::Int64
end

## 1-D coupling coueffcient used in ACE
"""
`CoeCoe` function could be replaced by that in Rotation3D,
one difference is that I did not specify the type of indices,
but this can also be done in Rotation3D
"""

function CouCoe(ll, mm, kk)
   N = maximum(size(ll))
   if N == 1
   	if ll[1] == mm[1] == kk[1] == 0
      	return 1
   	else
      	return 0
   end
   elseif N == 2
   	if ll[1] != ll[2] || sum(mm) != 0 || sum(kk) != 0
      	return 0
   	else
      	return 8 * pi^2 / (2*ll[1]+1) * (-1)^(mm[1]-kk[1])
   	end
	else
		val = 0
		llp = ll[1:N-2]'
		mmp = mm[1:N-2]'
		kkp = kk[1:N-2]'
		for j = abs(ll[N-1]-ll[N]):(ll[N-1]+ll[N])
			if abs(kk[N-1]+kk[N]) > j || abs(mm[N-1]+mm[N]) > j
		   	continue
			end
	  		cgk = clebschgordan(ll[N-1], kk[N-1], ll[N], kk[N], j, kk[N-1]+kk[N])
	  		cgm = clebschgordan(ll[N-1], mm[N-1], ll[N], mm[N], j, mm[N-1]+mm[N])
	  		if cgk * cgm  != 0
		  		val += cgk * cgm * CouCoe([llp j], [mmp mm[N-1]+mm[N]], [kkp kk[N-1]+kk[N]])
	  		end
		end
		return val
	end
end

## The end of CC...

## Begin of my code

# Equation (1.1) - forms the covariant matrix D(Q)(indices only)
function Rotation_D_matrix(φ::Orbitaltype)
	if φ.val<0
		error("Orbital type shall be represented as a positive integer!")
	end
    D = Array{D_Index}(undef, 2 * φ.val + 1, 2 * φ.val + 1)
    for i = 1 : 2 * φ.val + 1
        for j = 1 : 2 * φ.val + 1
            D[j,i] = D_Index(φ.val, i - 1 - φ.val, j - 1 - φ.val);
        end
    end
	return D
end

function Rotation_D_matrix_ast(φ::Orbitaltype)
	if φ.val<0
		error("Orbital type shall be represented as a positive integer!")
	end
    D = Array{D_Index}(undef, 2 * φ.val + 1, 2 * φ.val + 1)
    for i = 1 : 2 * φ.val + 1
        for j = 1 : 2 * φ.val + 1
            D[i,j] = D_Index(φ.val, -(i - 1 - φ.val), -(j - 1 - φ.val));
        end
    end
	return D
end

# Equation (1.2) - vector value coupling coefficients
function local_cou_coe(ll::StaticVector{N}, mm::StaticVector{N},
					   kk::StaticVector{N}, φ::Orbitaltype, t::Int64) where {N}
	if t > 2φ.val + 1
		error("Rotation D matrix has no such column!")
	end
	Z = zeros(Complex{Float64},2φ.val + 1);
	D = Rotation_D_matrix(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
	mt = [Dt[i].m for i in 1:2φ.val+1];
	LL = [ll;φ.val];
	for i = 1 : 2φ.val + 1
		Z[i] = CouCoe(LL, [mm;mt[i]], [kk;μt[i]]);
	end
	return Z
end

function local_cou_coe_ast(ll::StaticVector{N}, mm::StaticVector{N},
					   kk::StaticVector{N}, φ::Orbitaltype, t::Int64) where {N}
	if t > 2φ.val + 1
		error("Rotation D matrix has no such column!")
	end
	Z = zeros(Complex{Float64},2φ.val + 1);
	D = Rotation_D_matrix_ast(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
	mt = [Dt[i].m for i in 1:2φ.val+1];
	LL = [ll;φ.val];
	for i = 1 : 2φ.val + 1
		Z[i] = (-1)^(mt[i] - μt[i])*CouCoe(LL, [mm;mt[i]], [kk;μt[i]]);
	end
	return Z
end

local_cou_coe_ast(ll,mm,kk,φ,3)

# Equation (1.5) - possible set of mm w.r.t. vector k
function collect_m(ll::StaticVector{N}, k::T) where {N,T}
	d = length(k);
	A = CartesianIndices(ntuple(i -> -ll[i]:ll[i], length(ll)));
	B = Array{typeof(A[1].I)}(undef, 1, prod(size(A)))
	t = 0;
	for i in A
		if prod(sum(i.I) .+ k) == 0
			t = t + 1;
			B[t] = i.I;
		end
	end
	B = [SVector(i) for i in B[1:t]]
	return B
end

# Equation(1.7) & (1.6) respectively - gramian
function gramian(ll::StaticVector{N}, φ::Orbitaltype, t::Int64) where{N}
	D = Rotation_D_matrix(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
	mt = [Dt[i].m for i in 1:2φ.val+1];
	m_list = collect_m(ll,mt);
	μ_list = collect_m(ll,μt);
	Z = [zeros(2φ.val + 1) for i = 1:length(μ_list), j = 1:length(m_list)];
	for (im, mm) in enumerate(m_list), (iμ, μμ) in enumerate(μ_list)
		Z[iμ,im] = local_cou_coe(ll, mm, μμ, φ, t);
	end
	return Z' * Z, Z, μ_list;
end

#--- How about construct something called gramian_ast_all and so that the first ro-
#    und of SVD(s) require(s) only 1 SVD?

function gramian_ast_all(ll::StaticVector{N}, φ::Orbitaltype) where{N}
	L = φ.val
	LenM = 0;
	D = Rotation_D_matrix_ast(φ);
	Dt = D[:,1];
	μt = [Dt[i].μ for i in 1:2L+1];
	mt = [Dt[i].m for i in 1:2L+1];
	m_list = collect_m(ll,mt);
	μ_list = collect_m(ll,μt);
	Z = [zeros(Float64, 2L + 1).+zeros(Float64, 2L + 1).*im for i = 1:length(μ_list), j = 1:length(μ_list)];
	for (im, mm) in enumerate(m_list), (iμ, μμ) in enumerate(μ_list)
		Z[iμ,im] = local_cou_coe_ast(ll, mm, μμ, φ, 1);
	end
	if L≠0
		for t = 2 : 2L+1
			Dt = D[:,t];
			mt = [Dt[i].m for i in 1:2L+1];
			LenM += length(m_list);
			m_list = collect_m(ll,mt);
			for (im, mm) in enumerate(m_list), (iμ, μμ) in enumerate(μ_list)
				Z[iμ, im + LenM] = local_cou_coe_ast(ll, mm, μμ, φ, t);
			end
		end
	end
	return Z' * Z, Z, μ_list
end

gramian_ast_all(ll,φ)[1]

#--- The end of the testing!!

function gramian_ast(ll::StaticVector{N}, φ::Orbitaltype, t::Int64) where{N}
	D = Rotation_D_matrix_ast(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
	mt = [Dt[i].m for i in 1:2φ.val+1];
	m_list = collect_m(ll,mt);
	μ_list = collect_m(ll,μt);
	Z = [zeros(2φ.val + 1) for i = 1:length(μ_list), j = 1:length(m_list)];
	for (im, mm) in enumerate(m_list), (iμ, μμ) in enumerate(μ_list)
		Z[iμ,im] = local_cou_coe_ast(ll, mm, μμ, φ, t);
	end
	return Z' * Z, Z, μ_list;
end

# Equation (1.8) - LI set w.r.t. t & ll (not for nn for now)
function rc_basis(ll::StaticVector{N}, φ::Orbitaltype, t::Int64) where {N}
	G, C = gramian(ll, φ, t);
	D = Rotation_D_matrix(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
	mt = [Dt[i].m for i in 1:2φ.val+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
	μ_list = collect_m(ll,μt)
	Urcpi = [zeros(2φ.val + 1) for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end



function rc_basis_ast_tempall(ll::StaticVector{N}, φ::Orbitaltype) where {N}
	L = φ.val
	G, C, μ_list = gramian_ast_all(ll, φ);
#	D = Rotation_D_matrix(φ);
#	Dt = D[:,t];
#	μt = [Dt[i].μ for i in 1:2φ.val+1];
#	mt = [Dt[i].m for i in 1:2φ.val+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
#	μ_list = collect_m(ll,mt)
	Urcpi = [zeros(2L + 1) .+ zeros(2L + 1).*im for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end





function rc_basis_ast(ll::StaticVector{N}, φ::Orbitaltype, t::Int64) where {N}
	G, C = gramian_ast(ll, φ, t);
	D = Rotation_D_matrix_ast(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
	mt = [Dt[i].m for i in 1:2φ.val+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
	μ_list = collect_m(ll,μt)
	Urcpi = [zeros(2φ.val + 1) for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end

# Equation (1.10) - Collecting all t and sorting them in order
function rc_basis_all(ll::StaticVector{N}, φ::Orbitaltype) where {N}
	l1 = 0; l2 = 0;
	Urcpi_all, μ_list = rc_basis(ll, φ, 1);
	l1 = size(Urcpi_all)[1];
	l2 += size(Urcpi_all)[2];
	if φ.val ≠ 0
		for t = 2 : 2φ.val+1
			U_temp, μ_temp = rc_basis(ll, φ, t);
			l2 += size(U_temp)[2];
			Urcpi_all = [Urcpi_all..., U_temp...];
			#Urcpi_all = reshape(Urcpi_all, l1, l2);
			μ_list = [μ_list; μ_temp];
		end
		Urcpi_all = reshape(Urcpi_all, l1, l2);
	end
	return Urcpi_all, μ_list
end

function rc_basis_ast_all(ll::StaticVector{N}, φ::Orbitaltype) where {N}
	Urcpi_all, μ_list = rc_basis_ast(ll, φ, 1);
	if φ.val ≠ 0
		for t = 2 : 2φ.val+1
			Urcpi_all = [Urcpi_all; rc_basis_ast(ll, φ, t)[1]];
		end
	end
	return Urcpi_all, μ_list
end

## From now on I will try to do the second round of SVD to obtain LI w.r.t. nn

# Equation (1.12) - Gramian over nn
function Gramian(nn::StaticVector{N}, ll::StaticVector{N}, φ::Orbitaltype) where {N}
	Uri, Mri = rc_basis_tempall(ll, φ);
#	m_list = collect_m(ll,mt)
	G = zeros(Complex{Float64}, size(Uri)[1], size(Uri)[1]);
	for σ in permutations(1:N)
       if (nn[σ] != nn) || (ll[σ] != ll); continue; end
       for (iU1, mm1) in enumerate(Mri), (iU2, mm2) in enumerate(Mri)
          if mm1[σ] == mm2
             for i1 = 1:size(Uri)[1]
				 for i2 = 1:size(Uri)[1]
                 	G[i1, i2] += Uri[i1, iU1] * Uri[i2, iU2]'
				end
             end
          end
       end
    end
    return G, Uri, Mri
end

function Gramian_ast(nn::StaticVector{N}, ll::StaticVector{N}, φ::Orbitaltype) where {N}
	Uri, Mri = rc_basis_ast_tempall(ll, φ);
#	m_list = collect_m(ll,mt)
	G = zeros(Complex{Float64}, size(Uri)[1], size(Uri)[1]);
	for σ in permutations(1:N)
       if (nn[σ] != nn) || (ll[σ] != ll); continue; end
       for (iU1, mm1) in enumerate(Mri), (iU2, mm2) in enumerate(Mri)
          if mm1[σ] == mm2
             for i1 = 1:size(Uri)[1]
				 for i2 = 1:size(Uri)[1]
                 	G[i1, i2] += Uri[i1, iU1] * Uri[i2, iU2]'
				end
             end
          end
       end
    end
    return G, Uri
end

"""
'Rcpi_basis_final' function is aiming to take the place of 'yvec_symm_basis'
in rotation3D.jl but still have some interface problem to be discussed
"""
# Equation (1.13) - LI coefficients(& corresponding μ) over nn, ll
function Rcpi_basis_final(nn::StaticVector{N}, ll::StaticVector{N}, φ::Orbitaltype) where {N}
	if mod(sum(ll) + φ.val, 2) ≠ 0
		if mod(sum(ll), 2) ≠ 0
			@warn ("To gain reflection covariant, sum of `ll` shall be even")
		else
			@warn ("To gain reflection covariant, sum of `ll` shall be odd")
		end
	end
	G, C, μ_list= Gramian(nn, ll, φ);
	D = Rotation_D_matrix(φ);
#	Dt = D[:,1];
#	μt = [Dt[i].μ for i in 1:2φ.val+1];
#	mt = [Dt[i].m for i in 1:2φ.val+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
#	μ_list = collect_m(ll,μt)
	Urcpi = [zeros(2φ.val + 1) for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C' * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end

function Rcpi_basis_ast_final(nn::StaticVector{N}, ll::StaticVector{N}, φ::Orbitaltype) where {N}
	if mod(sum(ll) + φ.val, 2) ≠ 0
		if mod(sum(ll), 2) ≠ 0
			@warn ("To gain reflection covariant, sum of `ll` shall be even")
		else
			@warn ("To gain reflection covariant, sum of `ll` shall be odd")
		end
	end
	G, C = Gramian_ast(nn, ll, φ);
	D = Rotation_D_matrix_ast(φ);
	Dt = D[:,1];
	μt = [Dt[i].μ for i in 1:2φ.val+1];
#	mt = [Dt[i].m for i in 1:2φ.val+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
	μ_list = collect_m(ll,μt)
	Urcpi = [zeros(2φ.val + 1) for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C' * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end

Rcpi_basis_ast_final(nn,ll,Orbt(1))[1]
## End of LI of nn


## A test for ss, sp, sd blocks - with spherical harmonic only and all model parameters equal to 0

# Preliminary - PI basis without radial function
function PIbasis(ll::T, mm::T, R::SVector{N, Float64}) where{T,N}
    k = maximum(size(ll))
    A_part = 0;
    A = 1;
    for i = 1:k
        for j = 1:N/3
            Y = evaluate(SH, SVector(R.data[3*j-2:3*j]));
            A_part = A_part + Y[index_y(ll[i], mm[i])];
        end
        A = A * A_part;
        A_part = 0;
    end
    return A
end

function PIbasis(nn::T, ll::T, mm::T, R::SVector{N, Float64}) where{T,N}
    k = maximum(size(ll))
    A_part = 0;
    A = 1;
    for i = 1:k
        for j = 1:N/3
            Y = evaluate(SH, SVector(R.data[3*j-2:3*j]));
			Rn = Rnbasis(nn[i], SVector(R.data[3*j-2:3*j]));
            A_part = A_part + Rn * Y[index_y(ll[i], mm[i])];
        end
        A = A * A_part;
        A_part = 0;
    end
    return A
end

function Rnbasis(n::Int64, R::SVector{3, Float64})
	return n*1/norm(R)
	#return (2*norm(R)+1)^n
	#return norm(R)^n + 2norm(R)^(n-1)
end

# Preliminary - from 3D-rotation matrix $$Q$$ to euler angle $$α, β, γ$$
# characterized by zyz convention (c.f. https://en.wikipedia.org/wiki/Wigner_D-matrix)
function Mat2Ang(Q)
	return mod(atan(Q[2,3],Q[1,3]),2pi), acos(Q[3,3]), mod(atan(Q[3,2],-Q[3,1]),2pi);
end

## Preliminary - Generate the rotation3D matrix D(Q)

# Wigner_D ,c.f., https://en.wikipedia.org/wiki/Wigner_D-matrix
# It literally returns D^l_{μm}(Ang2Mat_zyz(α,β,γ))...
function Wigner_D(μ,m,l,α,β,γ)
	return (exp(-im*α*m) * wigner_d(m,μ,l,β)  * exp(-im*γ*μ))'
end

# Wigner small d, modified from
# https://github.com/cortner/SlaterKoster.jl/blob/
# 8dceecb073709e6448a7a219ed9d3a010fa06724/src/code_generation.jl#L73
function wigner_d(μ, m, l, β)
    fc1 = factorial(l+m)
    fc2 = factorial(l-m)
    fc3 = factorial(l+μ)
    fc4 = factorial(l-μ)
    fcm1 = sqrt(fc1 * fc2 * fc3 * fc4)

    cosb = cos(β / 2.0)
    sinb = sin(β / 2.0)

    p = m - μ
    low  = max(0,p)
    high = min(l+m,l-μ)

    temp = 0.0
    for s = low:high
       fc5 = factorial(s)
       fc6 = factorial(l+m-s)
       fc7 = factorial(l-μ-s)
       fc8 = factorial(s-p)
       fcm2 = fc5 * fc6 * fc7 * fc8
       pow1 = 2 * l - 2 * s + p
       pow2 = 2 * s - p
       temp += (-1)^(s+p) * cosb^pow1 * sinb^pow2 / fcm2
    end
    temp *= fcm1

    return temp
end

# Rotation D matrix
function rot_D(φ,Q)
	Mat_D = zeros(Complex{Float64}, 2φ.val + 1, 2φ.val + 1);
	D = Rotation_D_matrix(φ);
	α, β, γ = Mat2Ang(Q);
	for i = 1 : 2φ.val + 1
		for j = 1 : 2φ.val + 1
			Mat_D[i,j] = Wigner_D(D[i,j].μ, D[i,j].m, D[i,j].l, α, β, γ);
		end
	end
	return Mat_D
end

#It returns D(Q)^{∗}...
function rot_D_ast(φ,Q)
	Mat_D = zeros(Complex{Float64}, 2φ.val + 1, 2φ.val + 1);
	D = Rotation_D_matrix_ast(φ);
	α, β, γ = Mat2Ang(Q);
	for i = 1 : 2φ.val + 1
		for j = 1 : 2φ.val + 1
			Mat_D[i,j] = (-1)^(D[i,j].m+D[i,j].μ)*Wigner_D(D[i,j].μ, D[i,j].m, D[i,j].l, α, β, γ);
		end
	end
	return Mat_D
end

# I've check that:
# (1) rot_D(Q) = D(Q) s.t. Y^1(QR) = D(OOrbt(1), Q) * Y^1(R)
# (2)rot_D(Q)' ≈ rot_D_ast(Q);

## End of this generation

# Preliminary - Rotate R w.r.t. specific Q && Permutation of R
function Rot(R::SVector{N, Float64},Q) where {N}
    RotR = []; RotTemp = []; ii = 1;
    RotR = Q*R[3*ii-2:3*ii];
    if N/3 > 1
        for ii = 2:N/3
            RotTemp = SVector(R.data[3*ii-2:3*ii]);
            RotR = [RotR; Q*RotTemp];
        end
    end
    RotR = SVector(RotR)
    return RotR
end

function Per(R::SVector{N, Float64}) where {N}
	PerR = []; PerTemp = [];
	no_atom = Int(N/3);
	no_per = length(collect(permutations(1:no_atom)))
	for i in collect(permutations(1:no_atom))
		PerR = []
		PerR = R[3*i[1]-2:3*i[1]]
		if N/3 > 1
			for j = Int(2):no_atom
				PerTemp = SVector(R.data[(3*i[j]-2):3*i[j]]);
				PerR = [PerR; PerTemp];
			end
		end
		if rand(1)[1]≤1/no_per
			return SVector(PerR...)
		end
	end
	return SVector(PerR...)
end
## Check the correctness of Mat2Ang

# A basic test
function rot_D(φ,α::Float64,β::Float64,γ::Float64)
	Mat_D = zeros(Complex{Float64}, 2φ.val + 1, 2φ.val + 1);
	D = Rotation_D_matrix(φ);
	for i = 1 : 2φ.val + 1
		for j = 1 : 2φ.val + 1
			#Mat_D[i,j] = (-1)^(i+j) * Wigner_D(D[i,j].μ, D[i,j].m, D[i,j].l, α, β, γ);
			Mat_D[i,j] = Wigner_D(D[i,j].m, D[i,j].μ, D[i,j].l, α, β, γ);
		end
	end
	return Mat_D
end

function rotz(α)
	return [cos(α) -sin(α) 0; sin(α) cos(α) 0; 0 0 1];
end

function roty(α)
	return [cos(α) 0 sin(α); 0 1 0;-sin(α) 0 cos(α)];
end

function Ang2Mat_zyz(α,β,γ)
	return rotz(α)*roty(β)*rotz(γ);
end

function test_M2A(Q)
	α, β, γ = Mat2Ang(Q);
	return SMatrix{3,3}(Ang2Mat_zyz(α,β,γ)) == Q
end
## End of this check

# Begin of main test
function Evaluate(nn::StaticVector{T}, ll::StaticVector{T}, φ::Orbitaltype, R::SVector{N, Float64}) where{T,N}
	Z = zeros(Complex{Float64}, 2φ.val+1, 1);
	#U, μ_list = rc_basis_tempall(ll, φ);
	#U, μ_list = Rcpi_basis_final(nn, ll, φ);
	G, U, μ_list = gramian(ll,φ,1);
	U = U';
	UU = sum(U, dims = 1)
	Num_μ = length(UU);
	for i = 1: Num_μ
		Z = UU[i]' * PIbasis(ll, μ_list[i], R) + Z;
	end
	reshape(Z,2φ.val+1,1)
	return Z, svd(Z).S
end

function Evaluate_ast(nn::StaticVector{T}, ll::StaticVector{T}, φ::Orbitaltype, R::SVector{N, Float64}) where{T,N}
	Z = zeros(Complex{Float64}, 2φ.val+1, 1);
	#U, μ_list = rcpi_basis_all(ll, φ);
	U, μ_list = Rcpi_basis_ast_final(nn, ll, φ);
	UU = sum(U, dims = 1)
	Num_μ = length(UU);
	for i = 1: Num_μ
		Z = reshape(UU[i],2φ.val+1,1) * PIbasis(nn, ll, μ_list[i], R) + Z;
	end
	reshape(Z,2φ.val+1,1)
	return Z, svd(Z).S
end

function main_test(nn::StaticVector{T}, ll::StaticVector{T}, φ::Orbitaltype, R::SVector{N, Float64}) where{T,N}
	result_R = Evaluate(nn,ll,φ,R)[1];
	K = randn(3, 3);
	K = K - K';
	Q = SMatrix{3,3}(rand([-1,1]) * exp(K)...);
	RR = Rot(R, Q);
	result_RR = Evaluate(nn,ll,φ,RR)[1];
	println("Is F(R) ≈ D(Q)F(QR)?")
	return result_RR ≈ rot_D(φ, Q) * result_R, Q
end

function Main_test(nn::StaticVector{T}, ll::StaticVector{T}, φ::Orbitaltype, R::SVector{N, Float64}) where{T,N}
	result_R = Evaluate(nn,ll,φ,R)[1];
	α = 2pi*rand(Float64);
	β = pi*rand(Float64);
	γ = 2pi*rand(Float64);
	Q = Ang2Mat_zyz(α,β,γ);
	Q = SMatrix{3,3}(Q);
	RR = Rot(R, Q);
	result_RR = Evaluate(nn,ll,φ,RR)[1];
	println("Is F(R) ≈ D(Q)F(QR)?")
	return result_RR ≈ rot_D(φ, Q)' * result_R
end

function rand_QD(φ)
	α = 2pi*rand();
    β = pi*rand();
    γ = 2pi*rand();

 	# construct the Q matrix
    Q = Ang2Mat_zyz(α,β,γ)
    Q = SMatrix{3,3}(Q)

 	return Q, rot_D(φ, Q)
end

function Main_test_ast(nn::StaticVector{T}, ll::StaticVector{T}, φ::Orbitaltype, N::Integer) where{T}
	R = randn(SVector{3 * N, Float64});
	Q,D = rand_QD(φ)
	RR = Per(Rot(R, Q));

	result_R = Evaluate_ast(nn,ll,φ,R)[1];
	result_RR = Evaluate_ast(nn,ll,φ,RR)[1];

	println("Is F(Q∘σ(R)) ≈ D(Q)F(R)?")
	println(result_RR ≈ D * result_R)

	result_mR = Evaluate_ast(nn,ll,φ,-R)[1];

	println("Is F(-R) ≈ (-1)^L F(R)?")
	println(result_mR ≈ (-1)^(φ.val)*result_R)
end


nn = SVector(3,2);
ll = SVector(2,2);

Main_test_ast(nn,ll,Orbt(1),3)
## End of the test

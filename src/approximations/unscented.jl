export Unscented, UT, UnscentedTransform

const default_alpha = 1e-3 # Default value for the spread parameter
const default_beta = 2.0
const default_kappa = 0.0

struct UnscentedExtra{T, R, M, C}
    L  :: R
    λ  :: R
    Wm :: M
    Wc :: C
end

struct Unscented{A, B, K, E} <: AbstractApproximationMethod
    α  :: A
    β  :: B
    κ  :: K
    e  :: E
end

function Unscented(; alpha::A = default_alpha, beta::B = default_beta, kappa::K = default_kappa) where { A <: Real, B <: Real, K <: Real }
    return Unscented{A, B, K, Nothing}(alpha, beta, kappa, nothing)
end

function Unscented(dim::Int64; alpha::Real = default_alpha, beta::Real = default_beta, kappa::Real = default_kappa)
    α = alpha
    β = beta
    κ = kappa
    λ = α^2 * (dim + κ) - dim
    Wm = ones(2 * dim + 1)
    Wc = ones(2 * dim + 1)
    Wm ./= (2 * (dim + λ))
    Wc ./= (2 * (dim + λ))
    Wm[1] = λ / (dim + λ)
    Wc[1] = λ / (dim + λ) + (1 - α^2 + β)
    return Unscented(α, β, κ, UnscentedExtra(dim, λ, Wm, Wc))
end

"""An alias for the [`Unscented`](@ref) approximation method."""
const UT = Unscented

"""An alias for the [`Unscented`](@ref) approximation method."""
const UnscentedTransform = Unscented

# get-functions for the Unscented structure

getα(approximation::Unscented)  = approximation.α
getβ(approximation::Unscented)  = approximation.β
getκ(approximation::Unscented)  = approximation.κ

getextra(approximation::Unscented) = approximation.e

getL(approximation::Unscented)  = getL(getextra(approximation))
getλ(approximation::Unscented)  = getλ(getextra(approximation))
getWm(approximation::Unscented) = getWm(getextra(approximation))
getWc(approximation::Unscented) = getWc(getextra(approximation))

getL(extra::UnscentedExtra)  = extra.L
getλ(extra::UnscentedExtra)  = extra.λ
getWm(extra::UnscentedExtra) = extra.Wm
getWc(extra::UnscentedExtra) = extra.Wc

# Copied and refactored from ForneyLab.jl

"""
Return the statistics for the unscented approximation to the forward joint
"""
function unscented_statistics(method::Unscented, m::Real, V::Real, g) # Single univariate inbound
    (sigma_points, weights_m, weights_c) = sigma_points_weights(method, m, V)

    g_sigma = g.(sigma_points)
    m_tilde = sum(weights_m .* g_sigma)
    V_tilde = sum(weights_c .* (g_sigma .- m_tilde) .^ 2)
    C_tilde = sum(weights_c .* (sigma_points .- m) .* (g_sigma .- m_tilde))

    return (m_tilde, V_tilde, C_tilde)
end

# Single multivariate inbound
function unscented_statistics(method::Unscented, m::AbstractVector, V::AbstractMatrix, g)
    (sigma_points, weights_m, weights_c) = sigma_points_weights(method, m, V)

    d = length(m)

    g_sigma = g.(sigma_points)
    m_tilde = sum([weights_m[k+1] * g_sigma[k+1] for k in 0:2*d])
    V_tilde = sum([weights_c[k+1] * (g_sigma[k+1] - m_tilde) * (g_sigma[k+1] - m_tilde)' for k in 0:2*d])
    C_tilde = sum([weights_c[k+1] * (sigma_points[k+1] - m) * (g_sigma[k+1] - m_tilde)' for k in 0:2*d])

    return (m_tilde, V_tilde, C_tilde)
end

# Multiple inbounds of possibly mixed variate type
function unscented_statistics(method::Unscented, ms::AbstractVector, Vs::AbstractVector, g)
    joint = convert(JointNormal, ms, Vs)

    (m, V) = mean_cov(joint)
    ds     = dimensionalities(joint)

    (sigma_points, weights_m, weights_c) = sigma_points_weights(method, m, V)

    g_sigma = [ g(splitjoint(sp, ds)...) for sp in sigma_points ] # Unpack each sigma point in g

    d = sum(prod.(ds)) # Dimensionality of joint
    m_tilde = sum([weights_m[k+1] * g_sigma[k+1] for k in 0:2*d]) # Vector
    V_tilde = sum([weights_c[k+1] * (g_sigma[k+1] - m_tilde) * (g_sigma[k+1] - m_tilde)' for k in 0:2*d]) # Matrix
    C_tilde = sum([weights_c[k+1] * (sigma_points[k+1] - m) * (g_sigma[k+1] - m_tilde)' for k in 0:2*d]) # Matrix

    return (m_tilde, V_tilde, C_tilde)
end

"""
Return the sigma points and weights for a Gaussian distribution
"""
function sigma_points_weights(method::Unscented, m::Real, V::Real)
    alpha  = getα(method)
    beta   = getβ(method)
    kappa  = getκ(method)
    lambda = (1 + kappa) * alpha^2 - 1

    if (1 + lambda) < 0
        @warn "`(1 + lambda)` in the sigma points computation routine is negative. This may lead to the incorrect results. Adjust the `alpha`, `kappa` and `beta` parameters."
    end

    sigma_points = Vector{Float64}(undef, 3)
    weights_m = Vector{Float64}(undef, 3)
    weights_c = Vector{Float64}(undef, 3)

    l = sqrt((1 + lambda) * V)

    sigma_points[1] = m
    sigma_points[2] = m + l
    sigma_points[3] = m - l
    weights_m[1] = lambda / (1 + lambda)
    weights_m[2] = weights_m[3] = 1 / (2 * (1 + lambda))
    weights_c[1] = weights_m[1] + (1 - alpha^2 + beta)
    weights_c[2] = weights_c[3] = 1 / (2 * (1 + lambda))

    return (sigma_points, weights_m, weights_c)
end

function sigma_points_weights(method::Unscented, m::AbstractVector, V::AbstractMatrix)
    d      = length(m)
    alpha  = getα(method)
    beta   = getβ(method)
    kappa  = getκ(method)
    lambda = (d + kappa) * alpha^2 - d

    if (d + lambda) < 0
        @warn "`(d + lambda)` in the sigma points computation routine is negative. This may lead to the incorrect results. Adjust the `alpha`, `kappa` and `beta` parameters."
    end

    sigma_points = Vector{Vector{Float64}}(undef, 2 * d + 1)
    weights_m = Vector{Float64}(undef, 2 * d + 1)
    weights_c = Vector{Float64}(undef, 2 * d + 1)

    L = cholsqrt((d + lambda) * V)

    sigma_points[1] = m
    weights_m[1] = lambda / (d + lambda)
    weights_c[1] = weights_m[1] + (1 - alpha^2 + beta)
    for i in 1:d
        sigma_points[2*i] = m + L[:, i]
        sigma_points[2*i+1] = m - L[:, i]
    end
    weights_m[2:end] .= 1 / (2 * (d + lambda))
    weights_c[2:end] .= 1 / (2 * (d + lambda))

    return (sigma_points, weights_m, weights_c)
end
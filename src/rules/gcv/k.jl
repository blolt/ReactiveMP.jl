export rule

# TODO: double check
# @rule GCV(:κ, Marginalisation) (q_y_x::Any, q_z::Any, q_ω::Any) = begin
#     Λ = cov(q_y_x)
#     m = mean(q_y_x)

#     γ_3 = exp(-mean(q_ω) + 0.5 * var(q_ω))
#     γ_4 = (m[1] - m[2]) ^ 2 + Λ[1, 1] + Λ[2, 2] - Λ[1, 2] - Λ[2, 1]

#     a = mean(q_z)
#     b = γ_4 * γ_3
#     c = -a
#     d = var(q_z)

#     return ExponentialLinearQuadratic(a, b, c, d)
# end
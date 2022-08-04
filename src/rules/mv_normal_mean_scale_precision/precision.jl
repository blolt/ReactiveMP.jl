
# Variational                       # 
# --------------------------------- #
@rule MvNormalMeanScalePrecision(:γ, Marginalisation) (q_out::Any, q_μ::Any) = begin
    m_out, v_out   = mean_cov(q_out)
    m_mean, v_mean = mean_cov(q_μ)

    α = 0.5ndims(q_μ) + 1
    β = 0.5 * (tr(v_mean) + tr(v_out) + (m_mean - m_out)' * (m_mean - m_out))

    return GammaShapeRate(α, β)
end

@rule MvNormalMeanScalePrecision(:γ, Marginalisation) (q_out_μ::Any,) = begin
    m_out_μ, v_out_μ = mean_cov(q_out_μ)

    d = div(ndims(q_out_μ), 2)

    α = 0.5d + 1

    mdiff = @views m_out_μ[1:d] - m_out_μ[d+1:end]
    vdiff = @views v_out_μ[1:d, 1:d] - v_out_μ[1:d, d+1:end] - v_out_μ[d+1:end, 1:d] + v_out_μ[d+1:end, d+1:end]
    β     = 0.5(tr(vdiff) + mdiff' * mdiff)

    return GammaShapeRate(α, β)
end

export rule

@rule NOT(:out, Marginalisation) (m_in1::Bernoulli,) = Bernoulli(1 - mean(m_in1))

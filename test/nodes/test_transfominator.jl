score(
    AverageEnergy(),
    ContinuousTransition,
    Val{(:y_x, :h, :Λ)}(),
    (
        Marginal(MvNormalMeanPrecision(zeros(4), diageye(4)), false, false, nothing),
        Marginal(MvNormalMeanPrecision(zeros(4), diageye(4)), false, false, nothing),
        Marginal(Wishart(2, diageye(2)), false, false, nothing)
    ),
    CTMeta((2, 2))
)
score(
    AverageEnergy(),
    ContinuousTransition,
    Val{(:y_x, :h, :Λ)}(),
    (
        Marginal(MvNormalMeanPrecision(zeros(5), diageye(5)), false, false, nothing),
        Marginal(MvNormalMeanPrecision(zeros(6), diageye(6)), false, false, nothing),
        Marginal(Wishart(2, diageye(2)), false, false, nothing)
    ),
    CTMeta((2, 3))
)

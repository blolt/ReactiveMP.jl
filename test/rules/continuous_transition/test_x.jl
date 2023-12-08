module RulesContinuousTransitionTest

using Test, ReactiveMP, BayesBase, Random, ExponentialFamily, Distributions, LinearAlgebra

import ReactiveMP: @test_rules, ctcompanion_matrix, getjacobians, getunits

@testset "rules:ContinuousTransition:x" begin

    rng = MersenneTwister(42)

    @testset "Linear transformation" begin
        # the following rule is used for testing purposes only
        # It is derived separately by Thijs van de Laar
        function benchmark_rule(q_y, q_W, mA, ΣA, UA)
            my, Vy = mean_cov(q_y)

            mW = mean(q_W)

            Λ = tr(mW*ΣA)*UA + mA'*inv(Vy + inv(mW))*mA
            ξ = mA'*inv(Vy + inv(mW))*my
            return MvNormalWeightedMeanPrecision(ξ, Λ)
        end

        @testset "Structured: (m_y::MultivariateNormalDistributionsFamily, q_a::MultivariateNormalDistributionsFamily, q_W::Any, meta::CTMeta)" begin
            for (dy, dx) in [(1, 3), (2, 3), (3, 2), (2, 2)]
                dydx = dy * dx
                transformation = (a) -> reshape(a, dy, dx)

                mA, ΣA, UA = rand(rng, dy, dx), diageye(dy), diageye(dx)

                a0 = Float32.(vec(mA))
                metal = CTMeta(transformation, a0)
                Lx, Ly = rand(rng, dx, dx), rand(rng, dy, dy)
                μy, Σy = rand(rng, dy), Ly * Ly'
                
                qy = MvNormalMeanCovariance(μy, Σy)
                qa = MvNormalMeanCovariance(a0, diageye(dydx))
                qW = Wishart(dy+1, diageye(dy))
    
                @test_rules [check_type_promotion = false] ContinuousTransition(:x, Marginalisation) [(
                    input = (m_y = qy, q_a = qa, q_W = qW, meta = metal),
                    output = benchmark_rule(qy, qW, mA, ΣA, UA)
                )
                # Additional test cases with different distributions and metadata settings
                # Each case should represent a realistic scenario for your application
                ]
            end
        end
    end

    @testset "Nonlinear transformation" begin
        @testset "Structured: (q_y_x::MultivariateNormalDistributionsFamily, q_a::Any, q_W::Any, meta::CTMeta)" begin

            dy, dx = 2, 2
            dydx = dy * dy
            transformation = (a) -> [cos(a[1]) -sin(a[1]); sin(a[1]) cos(a[1])]
            a0 = zeros(Float32, 1)
            metanl = CTMeta(transformation, a0)
            μy, Σy = zeros(dy), diageye(dy)

            qy = MvNormalMeanCovariance(μy, Σy)
            qa = MvNormalMeanCovariance(a0, tiny*diageye(1))
            qW = Wishart(dy+1, diageye(dy))

            @test_rules [check_type_promotion = false] ContinuousTransition(:x, Marginalisation) [(
                    input = (m_y = qy, q_a = qa, q_W = qW, meta = metanl),
                    output = MvGaussianWeightedMeanPrecision(zeros(dx), 3/4*diageye(dx))
                )
            ]
        end
    end

end

end

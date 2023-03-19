module RulesCategoricalPTest

using Test
using ReactiveMP
using Random
import ReactiveMP: @test_rules

@testset "rules:Categorical:p" begin
    @testset "Variational Message Passing: (q_out::PointMass)" begin
        @test_rules [with_float_conversions = true] Categorical(:p, Marginalisation) [
            (input = (q_out = PointMass([0.0, 1.0]),), output = Dirichlet([1.0, 2.0])), (input = (q_out = PointMass([0.8, 0.2]),), output = Dirichlet([9 / 5, 12 / 10]))
        ]
    end

    @testset "Variational Message Passing: (q_out::Categorical)" begin
        @test_rules [with_float_conversions = false] Categorical(:p, Marginalisation) [
            (input = (q_out = Categorical([0.0, 1.0]),), output = Dirichlet([1.0, 2.0])), (input = (q_out = Categorical([0.7, 0.3]),), output = Dirichlet([17 / 10, 13 / 10]))
        ]
    end
end
end

export Flow, FlowModel, FlowLayer, NeuralNetwork, Parameter, PlanarMap, MirroredNiceFlowLayer, NiceFlowLayer, NiceFlowModel, FlowMeta
export forward, forward!, backward, backward!, jacobian, inv_jacobian, det_jacobian, absdet_jacobian, logabsdet_jacobian
## TODO: create a forward-jacobian joint function that calculates both at the same time
## TODO: custom broadcasting for new methods
## TODO: fix exports

import Base: +, -, *, /, length, iterate, eltype
import LinearAlgebra: dot

struct Flow end

@node Flow Deterministic [ out, in ]

abstract type AbstractFlowModel end
abstract type AbstractFlowLayer end
abstract type AbstractNeuralNetwork end

mutable struct Parameter{T}
    value   :: T
end

struct PlanarMap{T1, T2 <: Real} <: AbstractNeuralNetwork
    u       :: Parameter{T1}
    w       :: Parameter{T1}
    b       :: Parameter{T2}
end

struct NiceFlowLayer{T <: AbstractNeuralNetwork} <: AbstractFlowLayer
    f       :: T
end

struct MirroredNiceFlowLayer{T <: AbstractNeuralNetwork} <: AbstractFlowLayer
    f       :: T
end

struct NiceFlowModel <: AbstractFlowModel
    layers  :: Tuple{Vararg{T, N} where {T <: AbstractFlowLayer } } where { N }
end

struct FlowMeta{T <: AbstractFlowModel}
    model   :: T
end

default_meta(::Type{ Flow }) = error("Flow node requires meta flag to be explicitly specified")

## Parameter methods
+(x::Parameter, y::Parameter)   = x.value + y.value
+(x::Any, y::Parameter)         = x + y.value
+(x::Parameter, y::Any)         = x.value + y

-(x::Parameter, y::Parameter)   = x.value - y.value
-(x::Any, y::Parameter)         = x - y.value
-(x::Parameter, y::Any)         = x.value - y

*(x::Parameter, y::Parameter)   = x.value * y.value
*(x::Any, y::Parameter)         = x * y.value
*(x::Parameter, y::Any)         = x.value * y

/(x::Parameter, y::Parameter)   = x.value / y.value
/(x::Any, y::Parameter)         = x / y.value
/(x::Parameter, y::Any)         = x.value / y

dot(x::Parameter, y::Parameter) = dot(x.value, y.value)
dot(x::Any, y::Parameter)       = dot(x, y.value)
dot(x::Parameter, y::Any)       = dot(x.value, y)

length(x::Parameter)            = length(x.value)

iterate(x::Parameter)           = iterate(x.value)
iterate(x::Parameter, i::Int64) = iterate(x.value, i)

getvalue(x::Parameter)          = x.value

function setvalue!(x::Parameter{T}, value::T) where { T }
    x.value = value
end;


## PlanarMap methods

eltype(model::NiceFlowModel)                                = promote_type(map(eltype, model.layers)...)
eltype(layer::NiceFlowLayer{T1}) where { T1 }               = eltype(T1)
eltype(layer::MirroredNiceFlowLayer{T1}) where { T1 }       = eltype(T1)
eltype(f::PlanarMap{T1,T2}) where { T1, T2 }                = promote_type(T1, T2)
eltype(::Type{NiceFlowLayer{T1}}) where { T1 }              = eltype(T1)
eltype(::Type{MirroredNiceFlowLayer{T1}}) where { T1 }      = eltype(T1)
eltype(::Type{PlanarMap{T1,T2}}) where { T1, T2 }           = promote_type(T1, T2)

function PlanarMap(dim::Int64)
    return PlanarMap(randn(dim), randn(dim), randn())
end
function PlanarMap()
    return PlanarMap(randn(), randn(), randn())
end
function PlanarMap(u::T1, w::T1, b::T2) where { T1, T2 <: Real}
    return PlanarMap{T1,T2}(Parameter(u), Parameter(w), Parameter(float(b)))
end

getu(f::PlanarMap)              = f.u
getw(f::PlanarMap)              = f.w
getb(f::PlanarMap)              = f.b
getall(f::PlanarMap)            = f.u, f.w, f.b
getvalues(f::PlanarMap)         = getvalue(f.u), getvalue(f.w), getvalue(f.b)

function setu!(f::PlanarMap{T}, u::T) where { T }
    f.u = u
end

function setw!(f::PlanarMap{T}, w::T) where { T }
    f.w = w
end

function setb!(f::PlanarMap, b::T) where { T <: Real }
    f.b = b
end

function forward(f::PlanarMap{T}, input::T) where { T }

    # fetch values
    u, w, b = getvalues(f)
    
    # calculate result (optimized)
    result = copy(u)
    result .*= tanh(dot(w, input) + b)
    result .+= input

    # return result
    return result

end

function forward(f::PlanarMap{T1}, input::T2) where { T1 <: Real, T2 <: Real }

    # fetch values
    u, w, b = getvalues(f)
    
    # calculate result (optimized)
    result = copy(u)
    result *= tanh(dot(w, input) + b)
    result += input

    # return result
    return result

end

function jacobian(f::PlanarMap{T1}, input::T2) where { T1, T2 }

    # fetch values 
    u, w, b = getvalues(f)

    # calculate result (optimized)
    result = u*w'
    result .*= dtanh(dot(w, input) + b)
    @inbounds for k = 1:length(input)
        result[k,k] += 1.0
    end

    # return result
    return result

end

function jacobian(f::PlanarMap{T1}, input::T2) where { T1, T2 <: Real}

    # fetch values 
    u, w, b = getvalues(f)

    # calculate result (optimized)
    result = u * w * dtanh(w * input + b) + 1

    # return result
    return result

end

function det_jacobian(f::PlanarMap{T}, input::T) where { T }

    # fetch values
    u, w, b = getvalues(f)

    # return result
    return 1 + dot(u, w)*dtanh(dot(w, input) + b)

end

absdet_jacobian(f::PlanarMap{T}, input::T) where { T } = abs(det_jacobian(f, input))
logabsdet_jacobian(f::PlanarMap{T}, input::T) where { T } = log(absdet_jacobian(f, input))


## NiceFlowLayer methods
getf(layer::NiceFlowLayer)              = layer.f
getmap(layer::NiceFlowLayer)            = layer.f

function forward(layer::NiceFlowLayer, input::Array{T,1}) where { T } 

    # check dimensionality
    @assert length(input) == 2 "The NiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    result = [input[1], input[2] + forward(f, input[1])]

    # return result
    return result
    
end

function forward!(output::Array{T1,1}, layer::NiceFlowLayer, input::Array{T2,1}) where { T1, T2 }

    # check dimensionality
    @assert length(input) == 2 "The NiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    output[1] = input[1] 
    output[2] = input[2] 
    output[2] += forward(f, input[1])
    
end

function backward(layer::NiceFlowLayer, output::Array{T,1}) where { T }

    # check dimensionality
    @assert length(output) == 2 "The NiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    result = [output[1], output[2] - forward(f, output[1])]

    # return result
    return result
    
end

function backward!(input::Array{T1,1}, layer::NiceFlowLayer, output::Array{T2,1}) where { T1, T2 }#TODO

    # check dimensionality
    @assert length(output) == 2 "The NiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    input[1] = output[1]
    input[2] = output[2] - forward(f, output[1])
    
end

function jacobian(layer::NiceFlowLayer, input::Array{T1,1}) where { T1 }

    # check dimensionality
    @assert length(input) == 2 "The NiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    T = promote_type(eltype(layer), T1)

    # determine result  
    result = zeros(T, 2, 2)
    result[1,1] = 1.0
    result[2,1] = jacobian(f, input[1])
    result[2,2] = 1.0
    
    # return result
    return LowerTriangular(result)
    
end

function inv_jacobian(layer::NiceFlowLayer, output::Array{T1,1}) where { T1 }

    # check dimensionality
    @assert length(output) == 2 "The NiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    T = promote_type(eltype(layer), T1)

    # determine result
    result = zeros(T, 2, 2)
    result[1,1] = 1.0
    result[2,1] = -jacobian(f,output[1])
    result[2,2] = 1.0
    
    # return result
    return LowerTriangular(result)

end

det_jacobian(layer::NiceFlowLayer, input::Array{Float64,1}) = 1
absdet_jacobian(layer::NiceFlowLayer, input::Array{Float64,1}) = 1
logdet_jacobian(layer::NiceFlowLayer, input::Array{Float64,1}) = 0
logabsdet_jacobian(layer::NiceFlowLayer, input::Array{Float64,1}) = 0

detinv_jacobian(layer::NiceFlowLayer, output::Array{Float64,1}) = 1
absdetinv_jacobian(layer::NiceFlowLayer, output::Array{Float64,1}) = 1
logdetinv_jacobian(layer::NiceFlowLayer, output::Array{Float64,1}) = 0
logabsdetinv_jacobian(layer::NiceFlowLayer, output::Array{Float64,1}) = 0;


## MirroredNiceFlowLayer methods
getf(layer::MirroredNiceFlowLayer)              = layer.f
getmap(layer::MirroredNiceFlowLayer)            = layer.f

function forward(layer::MirroredNiceFlowLayer, input::Array{T,1}) where { T } 

    # check dimensionality
    @assert length(input) == 2 "The MirroredNiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    result = [input[1] + forward(f, input[2]), input[2]]

    # return result
    return result
    
end

function forward!(output::Array{T1,1}, layer::MirroredNiceFlowLayer, input::Array{T2,1}) where { T1, T2 }

    # check dimensionality
    @assert length(input) == 2 "The MirroredNiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    output[1] = input[1] 
    output[2] = input[2] 
    output[1] += forward(f, input[2])
    
end

function backward(layer::MirroredNiceFlowLayer, output::Array{T,1}) where { T }

    # check dimensionality
    @assert length(output) == 2 "The MirroredNiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    result = [output[1] - forward(f, output[2]), output[2]]

    # return result
    return result
    
end

function backward!(input::Array{T1,1}, layer::MirroredNiceFlowLayer, output::Array{T2,1}) where { T1, T2 }#TODO

    # check dimensionality
    @assert length(output) == 2 "The MirroredNiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    # determine result
    input[1] = output[1] - forward(f, output[2])
    input[2] = output[2]
    
end

function jacobian(layer::MirroredNiceFlowLayer, input::Array{T1,1}) where { T1 }

    # check dimensionality
    @assert length(input) == 2 "The MirroredNiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    T = promote_type(eltype(layer), T1)

    # determine result  
    result = zeros(T, 2, 2)
    result[1,1] = 1.0
    result[1,2] = jacobian(f, input[1])
    result[2,2] = 1.0
    
    # return result
    return UpperTriangular(result)
    
end

function inv_jacobian(layer::MirroredNiceFlowLayer, output::Array{T1,1}) where { T1 }

    # check dimensionality
    @assert length(output) == 2 "The MirroredNiceFlowLayer currently only supports 2 dimensional inputs and outputs."

    # fetch variables
    f = getf(layer)

    T = promote_type(eltype(layer), T1)

    # determine result
    result = zeros(T, 2, 2)
    result[1,1] = 1.0
    result[1,2] = -jacobian(f,output[1])
    result[2,2] = 1.0
    
    # return result
    return UpperTriangular(result)

end

det_jacobian(layer::MirroredNiceFlowLayer, input::Array{Float64,1}) = 1
absdet_jacobian(layer::MirroredNiceFlowLayer, input::Array{Float64,1}) = 1
logdet_jacobian(layer::MirroredNiceFlowLayer, input::Array{Float64,1}) = 0
logabsdet_jacobian(layer::MirroredNiceFlowLayer, input::Array{Float64,1}) = 0

detinv_jacobian(layer::MirroredNiceFlowLayer, output::Array{Float64,1}) = 1
absdetinv_jacobian(layer::MirroredNiceFlowLayer, output::Array{Float64,1}) = 1
logdetinv_jacobian(layer::MirroredNiceFlowLayer, output::Array{Float64,1}) = 0
logabsdetinv_jacobian(layer::MirroredNiceFlowLayer, output::Array{Float64,1}) = 0;


## NiceFlowModel methods
getlayers(model::NiceFlowModel)         = model.layers
getforward(model::NiceFlowModel)        = (x) -> forward(model, x)
getbackward(model::NiceFlowModel)       = (x) -> backward(model, x)
getjacobian(model::NiceFlowModel)       = (x) -> jacobian(model, x)
getinv_jacobian(model::NiceFlowModel)   = (x) -> inv_jacobian(model, x)

function forward(model::NiceFlowModel, input::Array{T1,1}) where { T1 }

    # fetch layers
    layers = getlayers(model)

    T = promote_type(eltype(model), T1)

    # allocate space for result
    input_new = zeros(T, size(input))
    input_new .= input
    output = zeros(T, size(input))
    
    # pass result along the graph
    for k = 1:length(layers)
        forward!(output, layers[k], input_new)
        if k < length(layers)
            input_new .= output
        end
    end

    # return result
    return output
    
end

function backward(model::NiceFlowModel, output::Array{T1,1}) where { T1 }

    # fetch layers
    layers = getlayers(model)

    T = promote_type(eltype(model), T1)

    # allocate space for result
    output_new = zeros(T, size(output))
    output_new .= output
    input = zeros(T, size(output))
    
    # pass result along the graph
    for k = length(layers):-1:1
        backward!(input, layers[k], output_new)
        if k > 1
            output_new .= input
        end
    end

    # return result
    return input
    
end

function jacobian(model::NiceFlowModel, input::Array{T1,1}) where { T1 }

    # fetch layers
    layers = getlayers(model)

    
    T = promote_type(eltype(model), T1)

    # allocate space for output
    input_new = zeros(T, size(input))
    input_new .= input
    output = zeros(T, size(input))
    J = zeros(T, 2, 2)
    J[1,1] = 1.0
    J[2,2] = 1.0
    J_new = copy(J)

    # pass result along the graph
    for k = 1:length(layers)
        
        # calculate jacobian
        mul!(J_new, jacobian(layers[k], input_new), J)

        # perform forward pass and update inputs
        if k < length(layers)
            forward!(output, layers[k], input_new)
            input_new .= output
            J .= J_new
        end

    end

    # return result
    return J_new

end

function inv_jacobian(model::NiceFlowModel, output::Array{T1,1}) where { T1 }

    # fetch layers
    layers = getlayers(model)

    T = promote_type(eltype(model), T1)

    # allocate space for output
    output_new = zeros(T, size(output))
    output_new .= output
    input = zeros(T, size(output))
    J = zeros(T, 2, 2)
    J[1,1] = 1.0
    J[2,2] = 1.0
    J_new = copy(J)
    
    # pass result along the graph
    for k = length(layers):-1:1

        # calculate jacobian
        mul!(J_new, inv_jacobian(layers[k], output_new), J)

        # perform backward pass and update outputs
        if k > 1
            backward!(input, layers[k], output_new)
            output_new .= input
            J .= J_new
        end

    end

    # return result
    return J_new
    
end

det_jacobian(model::NiceFlowModel, input::Array{Float64,1}) = 1
absdet_jacobian(model::NiceFlowModel, input::Array{Float64,1}) = 1
logdet_jacobian(model::NiceFlowModel, input::Array{Float64,1}) = 0
logabsdet_jacobian(model::NiceFlowModel, input::Array{Float64,1}) = 0

detinv_jacobian(model::NiceFlowModel, output::Array{Float64,1}) = 1
absdetinv_jacobian(model::NiceFlowModel, output::Array{Float64,1}) = 1
logdetinv_jacobian(model::NiceFlowModel, output::Array{Float64,1}) = 0
logabsdetinv_jacobian(model::NiceFlowModel, output::Array{Float64,1}) = 0;

## FlowMeta methods
getmodel(meta::FlowMeta) = meta.model
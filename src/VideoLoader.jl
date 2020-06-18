module VideoLoader

using VideoIO
using Images
using Random
using Logging
using Distributed

const FrameContainer = Vector{AbstractMatrix{VideoLoader.RGB}}
const FrameList = Vector{<:AbstractMatrix{<:RGB}}
const VideoTensor = Array{<:AbstractFloat, 4} # WHDC

include("loading.jl")
include("transforms.jl")
include("workers.jl")

greet() = print("Hello World!")

end # module

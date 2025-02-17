using ChainRulesCore

"""
    PositionEmbedding(size::Int, max_len::Int = 1024; trainable::Bool = false)

The position embedding layer. `size` is the number of neuron. `max_len` is the maximum acceptable length of input.
If is not `trainable`, `max_len` will dynamically adjust to the longest input length. If `trainable`, use a random init
embedding value, otherwise use a sin/cos position encoding.
"""
mutable struct PositionEmbedding{F, W <: AbstractArray{F}} <: AbstractBroadcastEmbed{F}
    trainable::Bool
    embedding::W
end

@functor PositionEmbedding

Flux.trainable(pe::PositionEmbedding) = pe.trainable ? (embedding = pe.embedding,) : (;)

get_value(e::PositionEmbedding, name::Symbol, xs::NamedTuple) = e(first(xs))

function PE(size, pos, i::Int)
    if rem(i, 2) == 1
        sin((pos-1)/1e4^((i-1)/size))
    else
        cos((pos-1)/1e4^((i-2)/size))
    end
end

function PositionEmbedding(size::Int, max_len::Int = 1024; trainable::Bool = false)
    if trainable
        embedding = randn(Float32, size, max_len)
    else
        embedding = Matrix{Float32}(undef, size, max_len)
        for l = 1:max_len
            map!(i->PE(size, l, i), selectdim(embedding, 2, l), 1:size)
        end
    end
    PositionEmbedding(trainable, embedding)
end

function resize_pe!(pe::PositionEmbedding, len::Int)
    emb_dim, max_len = size(pe.embedding)

    if len > max_len
        if pe.trainable
            error("position embedding length exceeded")
        else
            over = similar(pe.embedding, emb_dim, len)
            copyto!(over, pe.embedding)

            for l = size(pe.embedding, 2)+1:len
                map!(i->PE(emb_dim, l, i), selectdim(over, 2, l), 1:emb_dim)
            end

            pe.embedding = over
        end
    end
    return nothing
end
ChainRulesCore.@non_differentiable resize_pe!(pe::PositionEmbedding, len::Int)

(pe::PositionEmbedding)(x::AbstractArray{Int}) = pe(size(x, 1))
(pe::PositionEmbedding)(x::OneHotArray) = pe(size(x, 2))
(pe::PositionEmbedding{F})(x::AbstractArray{F}) where F = pe(size(x, 2))
function (pe::PositionEmbedding)(len::Int)
    resize_pe!(pe, len)
    pe.embedding[:, Base.OneTo(len)]
end

function Base.show(io::IO, pe::PositionEmbedding)
    s, max_len = size(pe.embedding)
    if pe.trainable
        print(io, "PositionEmbedding($(s), max_len=$(max_len))")
    else
        print(io, "PositionEmbedding($(s))")
    end
end

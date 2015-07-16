immutable FADTensor{N,T,D} <: FADNumber{N,T,D}
    hess::FADHessian{N,T,D}
    tens::Vector{T}
    function FADTensor(hess::FADHessian{N,T,D}, tens::Vector{T})
        @assert length(tens) == halftenslen(N)
        return new(hess, tens)
    end
end

function FADTensor{N,T,D}(hess::FADHessian{N,T,D},
                          tens::Vector=zeros(T, halftenslen(N)))
    return FADTensor{N,T,D}(hess, tens)
end

##############################
# Utility/Accessor Functions #
##############################
zero{N,T,D}(::Type{FADTensor{N,T,D}}) = FADTensor(zero(FADHessian{N,T,D}), zeros(T, halftenslen(n)))
one{N,T,D}(::Type{FADTensor{N,T,D}}) = FADTensor(one(FADHessian{N,T,D}), zeros(T, halftenslen(n)))

hess(t::FADTensor) = t.hess
tens(t::FADTensor) = t.tens
grad(t::FADTensor) = grad(hess(t))

neps{N,T,D}(::Type{FADTensor{N,T,D}}) = N
eltype{N,T,D}(::Type{FADTensor{N,T,D}}) = T

function isconstant(t::FADTensor)
    zeroT = zero(eltype(t))
    return isconstant(hess(t)) && all(x -> x == zeroT, tens(h))
end

function isfinite(t::FADTensor)
    oneT = one(eltype(t))
    return isfinite(hess(t)) && all(x -> x == oneT, tens(h))
end

=={N}(a::FADTensor{N}, b::FADTensor{N}) = (hess(a) == hess(b)) && (tens(a) == tens(b))

########################
# Conversion/Promotion #
########################
convert{N,T,D}(::Type{FADTensor{N,T,D}}, t::FADTensor{N,T,D}) = t
convert{N,T,D}(::Type{FADTensor{N,T,D}}, x::Real) = FADTensor(D(x), zeros(T, halftenslen(N)))

function convert{N,T,D}(::Type{FADTensor{N,T,D}}, t::FADTensor{N})
    return FADTensor(convert(FADHessian{N,T,D}, grad(t)), tens(t))
end

function convert{T<:Real}(::Type{T}, t::FADTensor)
    if isconstant(t)
        return convert(T, value(t))
    else
        throw(InexactError)
    end
end

promote_rule{N,T,D}(::Type{FADTensor{N,T,D}}, ::Type{T}) = FADTensor{N,T,D}
promote_rule{N,T,D,S}(::Type{FADTensor{N,T,D}}, ::Type{S}) = FADTensor{N,promote_type(T, S),promote_type(D, S)}
function promote_rule{N,T1,D1,T2,D2}(::Type{FADTensor{N,T1,D1}}, ::Type{FADTensor{N,T2,D2}})
    return FADTensor{N,promote_type(T1, T2),promote_type(D1, D2)}
end

######################
# Math on FADTensors #
######################
function t2h(i, j)
    if i < j
        return div(j*(j-1), 2+i)
    else
        return div(i*(i-1), 2+j)
    end
end

## Bivariate functions on FADTensors ##
##-----------------------------------##

const noexpr = Expr(:quote, nothing)

const t_bivar_funcs = Tuple{Symbol, Expr, Expr}[
    (:*, noexpr, :(grad(t2,a)*hess(t1,r)+grad(t1,j)*hess(t2,r)+grad(t2,i)*hess(t1,m)+grad(t1,i)*hess(t2,m)+grad(t2,j)*hess(t1,l)
                   +grad(t1,j)*hess(t2,l)+value(t2)*tens(t1,q)+value(t1)*tens(t2,q))),
    (:/, noexpr, :((tens(t1,q)+((-(grad(t1,j)*hess(t2,r)+grad(t1,i)*hess(t2,m)+grad(t1,j)*hess(t2,l)+grad(t2,a)*hess(t1,r)+grad(t2,i)
                   *hess(t1,m)+grad(t2,j)*hess(t1,l)+value(t1)*tens(t2,q))+(2*(grad(t1,j)*grad(t2,i)*grad(t2,j)+grad(t2,a)*grad(t1,i)
                   *grad(t2,j)+grad(t2,a)*grad(t2,i)*grad(t1,j)+(value(t1)*(grad(t2,a)*hess(t2,r)+grad(t2,i)*hess(t2,m)+grad(t2,j)
                   *hess(t2,l)))-(3*value(t1)*grad(t2,a)*grad(t2,i)*grad(t2,j)/value(t2)))/value(t2)))/value(t2)))/value(t2))),
    (:^, :(logt1 = log(value(t1)); logt1sq = logt1^2; t1logt1 = value(t1)*logt1; t1logt1sq = value(t1)*logt1sq),
         :(value(t1)^(value(t2)-3)*(value(t2)^3*grad(t1,j)*grad(t1,i)*grad(t1,j)+value(t2)^2*(value(t1)*((logt1*grad(t2,j)
           *grad(t1,i)+hess(t1,r))*grad(t1,j)+grad(t1,i)*hess(t1,m))+grad(t1,j)*(grad(t1,i)*(-3*grad(t1,j)+t1logt1*grad(t2,a))
           +value(t1)*(logt1*grad(t2,i)*grad(t1,j)+hess(t1,l))))+value(t2)*(grad(t1,j)*(grad(t1,i)*(2*grad(t1,j)-value(t1)
           *(-2+logt1)*grad(t2,a))+value(t1)*(grad(t2,i)*(-(-2+logt1)*grad(t1,j)+t1logt1sq*grad(t2,a))-hess(t1,l)+t1logt1*hess(t2,l)))
           +value(t1)*(hess(t1,r)*(-grad(t1,j)+t1logt1*grad(t2,a))-grad(t1,i)*hess(t1,m)+grad(t2,j)*(grad(t1,i)*(-(-2+logt1)*grad(t1,j)
           +t1logt1sq*grad(t2,a))+t1logt1*(logt1*grad(t1,j)*grad(t2,i)+hess(t1,l)))+value(t1)*(logt1*(grad(t1,j)*hess(t2,r)+grad(t2,i)
           *hess(t1,m)+grad(t1,i)*hess(t2,m))+tens(t1,q))))+value(t1)*(grad(t1,j)*(-grad(t1,i)*grad(t2,a)-grad(t2,i)*(grad(t1,j)
           -2*t1logt1*grad(t2,a))+value(t1)*hess(t2,l))+grad(t2,j)*(-grad(t1,i)*(grad(t1,j)-2*t1logt1*grad(t2,a))+value(t1)
           *(hess(t1,l)+logt1*(grad(t2,i)*(2*grad(t1,j)+t1logt1sq*grad(t2,a))+t1logt1*hess(t2,l))))+value(t1)*(grad(t2,a)*hess(t1,r)
           +hess(t2,r)*(grad(t1,j)+t1logt1sq*grad(t2,a))+grad(t1,i)*hess(t2,m)+grad(t2,i)*(hess(t1,m)+t1logt1sq*hess(t2,m))
           +t1logt1*tens(t2,q))))))
]

for (fsym, vars, term) in t_bivar_funcs
    loadfsym = symbol(string("loadtens_", fsym, "!"))
    @eval begin
        function $(loadfsym){N}(t1::FADTensor{N}, t2::FADTensor{N}, output)
            q = 1
            $(vars)
            for a in 1:N
                for i in a:N
                    for j in a:i
                        l, m, r = t2h(a, i), t2h(a, j), t2h(i, j)
                        new_tens[q] = $(term)
                        q += 1
                    end
                end
            end
            return output
        end

        function $(fsym){N,A,B}(t1::FADTensor{N,A}, t2::FADTensor{N,B})
            new_tens = Array(promote_type(A, B), halftenslen(N))
            return FADTensor($(fsym)(hess(t1), hess(t2)), $(loadfsym)(t1, t2, new_tens))
        end
    end
end

+{N}(a::FADTensor{N}, b::FADTensor{N}) = FADTensor(hess(a) + hess(b), tens(a) + tens(b))
-{N}(a::FADTensor{N}, b::FADTensor{N}) = FADTensor(hess(a) - hess(b), tens(a) - tens(b))

for T in (:Bool, :Real)
    @eval begin
        *(t::FADTensor, x::$(T)) = FADTensor(hess(t) * x, tens(t) * x)
        *(x::$(T), t::FADTensor) = FADTensor(x * hess(t), x * tens(t))
    end
end

/(t::FADTensor, x::Real) = FADTensor(hess(t) / x, tens(t) / x)
#/(x::Real, t::FADTensor) = ?

for T in (:Rational, :Integer, :Real)
    @eval begin
        function ^{N}(t::FADTensor{N}, p::$(T))
            new_tens = Array(promote_type(eltype(t), typeof(p)), halftenslen(N))
            q = 1
            for a in 1:N
                for i in a:N
                    for j in a:i
                        l, m, r = t2h(a, i), t2h(a, j), t2h(i, j)
                        new_tens[q] = (p*((p-1)*value(t)^(p-3)*((p-2)*grad(t,a)*grad(t,i)*grad(t,j)+value(t)
                                      *(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))+value(t)^2*tens(t,q)))
                        q += 1
                    end
                end
            end
            return FADTensor(hess(t)^p, new_tens)
        end
    end
end
## Univariate functions on FADHessians ##
##-------------------------------------##

-(t::FADTensor) = FADTensor(-hess(t), -tens(t))

const t_univar_funcs = Tuple{Symbol, Expr, Expr, Expr}[
    (:sqrt, noexpr, noexpr, :(((0.375*grad(t,a)*grad(t,i)*grad(t,j)/value(t)-0.25*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))/value(t)+0.5*tens(t,q))/sqrt(value(t)))),
    (:cbrt, noexpr, noexpr, :(((10*grad(t,a)*grad(t,i)*grad(t,j)/(3*value(t))-2*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))/(3*value(t))+tens(t,q))/(3*value(t)^(2/3)))),
    (:exp, noexpr, noexpr, :(exp(value(t))*(grad(t,a)*grad(t,i)*grad(t,j)+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)+tens(t,q)))),
    (:log, noexpr, noexpr, :(((2*grad(t,a)*grad(t,i)*grad(t,j)/value(t)-(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))/value(t)+tens(t,q))/value(t))),
    (:log2, noexpr, noexpr, :(((2*grad(t,a)*grad(t,i)*grad(t,j)/value(t)-(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))/value(t)+tens(t,q))/(value(t)*convert(T, 0.6931471805599453)))),
    (:log10, noexpr, noexpr, :(((2*grad(t,a)*grad(t,i)*grad(t,j)/value(t)-(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))/value(t)+tens(t,q))/(value(t)*convert(T, 2.302585092994046)))),
    (:sin, noexpr, noexpr, :(cos(value(t))*(tens(t,q)-grad(t,a)*grad(t,i)*grad(t,j))-sin(value(t))*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))),
    (:cos, noexpr, noexpr, :(sin(value(t))*(grad(t,a)*grad(t,i)*grad(t,j)-tens(t,q))-cos(value(t))*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))),
    (:tan, :(tanx = tan(value(t)); secxsq = sec(value(t))^2), noexpr, :(secxsq*(2*tanx*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m))+2*grad(t,j)*((3*secxsq-2)*grad(t,a)*grad(t,i)+tanx*hess(t,l))+tens(t,q)))),
    (:asin, :(xsq = value(t)^2; oneminusxsq = 1-xsq), :(gprod = grad(t,a)*grad(t,i)*grad(t,j)), :(((3*xsq*gprod/oneminusxsq+gprod+(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l))*value(t))/oneminusxsq+tens(t,q))/oneminusxsq^0.5)),
    (:acos,  :(xsq = value(t)^2; oneminusxsq = 1-xsq), :(gprod = grad(t,a)*grad(t,i)*grad(t,j)), :(-((3*xsq*gprod/oneminusxsq+gprod+(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l))*value(t))/oneminusxsq+tens(t,q))/oneminusxsq^0.5)),
    (:atan, :(xsq = value(t)^2; oneplusxsq = 1+xsq), :(gprod = grad(t,a)*grad(t,i)*grad(t,j)), :(((4*xsq*gprod/oneplusxsq-gprod-(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l))*value(t))*2/oneplusxsq+tens(t,q))/oneplusxsq)),
    (:sinh, noexpr, noexpr, :(cosh(value(t))*(grad(t,a)*grad(t,i)*grad(t,j)+tens(t,q))+sinh(value(t))*(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))),
    (:cosh, noexpr, noexpr, :(sinh(value(t))*(grad(t,a)*grad(t,i)*grad(t,j)+tens(t,q))+cosh(value(t))*(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l)))),
    (:tanh, :(sechxsq = sech(value(t))^2; tanhx = tanh(value(t))), noexpr, :(sechxsq*(-2*(tanhx*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m))+grad(t,j)*((3*sechxsq-2)*grad(t,a)*grad(t,i)+tanhx*hess(t,l)))+tens(t,q)))),
    (:asinh, :(xsq = value(t)^2; oneplusxsq = 1+xsq), :(gprod = grad(t,a)*grad(t,i)*grad(t,j)), :(((3*xsq*gprod/oneplusxsq-gprod-(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l))*value(t))/oneplusxsq+tens(t,q))/oneplusxsq^0.5)),
    (:acosh, :(xsq = value(t)^2), noexpr, :((grad(t,j)*((2*xsq+1)*grad(t,a)*grad(t,i)-value(t)*(xsq-1)*hess(t,l))+(xsq-1)*(-value(t)*(grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m))+tens(t,q)*(xsq-1)))/(xsq-1)^2.5)),
    (:atanh, :(xsq = value(t)^2; oneminusxsq = 1-xsq), :(gprod = grad(t,a)*grad(t,i)*grad(t,j)), :(((4*xsq*gprod/oneminusxsq+gprod+(+grad(t,a)*hess(t,r)+grad(t,i)*hess(t,m)+grad(t,j)*hess(t,l))*value(t))*2/oneminusxsq+tens(t,q))/oneminusxsq))
]

for (fsym, funcvars, loopvars, term) in t_univar_funcs
    loadfsym = symbol(string("loadtens_", fsym, "!"))
    @eval begin
        function $(loadfsym){N}(t::FADTensor{N}, output)
            q = 1
            $(funcvars)
            for a in 1:N
                for i in a:N
                    for j in a:i
                        l, m, r = t2h(a, i), t2h(a, j), t2h(i, j)
                        $(loopvars)
                        new_tens[q] = $(term)
                        q += 1
                    end
                end
            end
            return output
        end

        function $(fsym){N,T}(t::FADTensor{N,T})
            ResultType = typeof($(fsym)(one(T)))
            new_tens = Array(ResultType, halftenslen(N))
            return FADTensor($(fsym)(hess(t)), $(loadfsym)(t, new_tens))
        end
    end
end

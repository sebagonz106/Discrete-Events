"""
    Person

Mutable data structure representing an individual in the population.
"""

module PersonModule

export Person, Sex, MaritalStatus

@enum Sex male=1 female=2
@enum MaritalStatus single=1 married=2 widowed=3 divorced=4

"""
    Person

Represents an individual with demographic attributes.

# Fields
- `id::Int64`: Unique identifier (auto-incremented globally)
- `age_days::Int64`: Age in days
- `sex::Sex`: biological sex (male/female)
- `partner_id::Union{Int64, Nothing}`: ID of partner, or nothing if single
- `desired_children::Int64`: Target number of children
- `num_children::Int64`: Current number of biological children
- `marital_status::MaritalStatus`: Current marital status
- `waiting_days::Int64`: Days remaining in post-separation waiting period
"""
mutable struct Person
    id::Int64
    age_days::Int64
    sex::Sex
    partner_id::Union{Int64, Nothing}
    desired_children::Int64
    num_children::Int64
    marital_status::MaritalStatus
    waiting_days::Int64
    pregnant::Bool

    function Person(
        id::Int64,
        age_days::Int64,
        sex::Sex,
        desired_children::Int64;
        partner_id::Union{Int64, Nothing}=nothing,
        num_children::Int64=0,
        marital_status::MaritalStatus=single,
        waiting_days::Int64=0,
        pregnant=False
    )
        new(id, age_days, sex, partner_id, desired_children, 
            num_children, marital_status, waiting_days, pregnant)
    end
end

end # module
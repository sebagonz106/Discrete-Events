"""
    ProbabilityTables

Probability distributions and lookup tables extracted from source documents.
"""

module ProbabilityTables

using ..RandomGenerators, ..SimulatorConfig, ..PersonModule

export get_death_probability, get_pregnancy_probability, get_desired_children,
       get_want_partner_probability, get_couple_formation_probability,
       get_breakup_probability, get_rupture_waiting_period, sample_num_babies,
       sample_initial_age, sample_desired_children, sample_sex

# ============================================================================
# Death Probability by Age and Sex
# ============================================================================

"""
Age ranges for death probability: (age_min, age_max) => probability
"""
const DEATH_PROB_MALE = Dict(
    (0, 12)     => 0.25,
    (12, 45)    => 0.10,
    (45, 76)    => 0.30,
    (76, 125)   => 0.70
)

const DEATH_PROB_FEMALE = Dict(
    (0, 12)     => 0.25,
    (12, 45)    => 0.15,
    (45, 76)    => 0.35,
    (76, 125)   => 0.65
)

"""
    get_death_probability(age_years::Int64, sex::PersonModule.Sex)::Float64
    
Return annual death probability for person of given age and sex.
"""
function get_death_probability(age_years::Int64, sex::PersonModule.Sex)::Float64
    table = sex == PersonModule.male ? DEATH_PROB_MALE : DEATH_PROB_FEMALE

    for ((age_min, age_max), prob) in table
        if age_min <= age_years < age_max
            return prob
        end
    end
    
    return 1.0 # fallback
end

# ============================================================================
# Pregnancy Probability by Age
# ============================================================================

const PREGNANCY_PROB = Dict(
    (12, 15)    => 0.20,
    (15, 21)    => 0.45,
    (21, 35)    => 0.80,
    (35, 45)    => 0.40,
    (45, 60)    => 0.20,
    (60, 125)   => 0.05
)

"""
    get_pregnancy_probability(age_years::Int64)::Float64
    
Return annual pregnancy probability for woman of given age.
"""
function get_pregnancy_probability(age_years::Int64)::Float64
    for ((age_min, age_max), prob) in PREGNANCY_PROB
        if age_min <= age_years < age_max
            return prob
        end
    end
    
    error("Age $age_years out of range for pregnancy")
end

# ============================================================================
# Desired Children Distribution
# ============================================================================

const DESIRED_CHILDREN_DIST = Dict(
    1 => 0.60,
    2 => 0.75,
    3 => 0.35,
    4 => 0.20,
    5 => 0.10,
    50 => 0.05     # technically unlimited
)

"""
    get_desired_children()::Int64
    
Sample desired number of children from distribution.
"""
function get_desired_children()::Int64
    r = RandomGenerators.uniform_dict(DESIRED_CHILDREN_DIST) # Normalization needed
    cumsum = 0.0
    
    for (num_children, prob) in sort(collect(DESIRED_CHILDREN_DIST))
        cumsum += prob
        if r < cumsum
            return num_children
        end
    end
    
    return 50  # fallback
end

# ============================================================================
# Partnership Formation Probabilities
# ============================================================================

const WANT_PARTNER_PROB = Dict(
    (12, 15)    => 0.60,
    (15, 21)    => 0.65,
    (21, 35)    => 0.80,
    (35, 45)    => 0.60,
    (45, 60)    => 0.50,
    (60, 125)   => 0.20
)

"""
    get_want_partner_probability(age_years::Int64)::Float64
    
Return probability that person wants to form a partnership at given age.
"""
function get_want_partner_probability(age_years::Int64)::Float64
    for ((age_min, age_max), prob) in WANT_PARTNER_PROB
        if age_min <= age_years < age_max
            return prob
        end
    end
    
    error("Age $age_years out of range for partnership interest")
end

# ============================================================================
# Couple Formation Probability by Age Difference
# ============================================================================

const COUPLE_FORMATION_BY_AGE_DIFF = Dict(
    (0, 5)      => 0.45,
    (5, 10)     => 0.40,
    (10, 15)    => 0.35,
    (15, 20)    => 0.25,
    (20, 125)   => 0.15
)

"""
    get_couple_formation_probability(age_difference::Int64)::Float64
    
Return probability of forming couple given age difference.
"""
function get_couple_formation_probability(age_difference::Int64)::Float64
    for ((diff_min, diff_max), prob) in COUPLE_FORMATION_BY_AGE_DIFF
        if diff_min <= age_difference < diff_max
            return prob
        end
    end
    
    error("Age difference $age_difference out of range")
end

# ============================================================================
# Separation and Waiting Period
# ============================================================================

const BREAKUP_PROBABILITY = 0.2

"""
    get_breakup_probability()::Float64

Return breakup probability.
"""
function get_breakup_probability()::Float64
    return BREAKUP_PROBABILITY    
end

# Average waiting times (days) before re-partnering, by age
const RUPTURE_WAITING_PERIOD = Dict(
    (12, 16)    => 90.0,       # 3 months
    (16, 22)    => 180.0,      # 6 months
    (22, 36)    => 180.0,      # 6 months
    (36, 45)    => 360.0,      # 1 year
    (45, 60)    => 720.0,      # 2 years
    (60, 125)   => 1440.0      # 4 years
)

"""
    get_rupture_waiting_period_lambda(age_years::Int64)::Float64
    
Return mean waiting period (in days) before re-partnering after separation.
"""
function get_rupture_waiting_period(age_years::Int64)::Float64
    for ((age_min, age_max), time) in RUPTURE_WAITING_PERIOD
        if age_min <= age_years < age_max
            return time
        end
    end
    
    error("Age $age_years out of range for waiting period")
end

# ============================================================================
# Number of Babies per Birth
# ============================================================================

const BABIES_DISTRIBUTION = Dict(
    1 => 0.70,
    2 => 0.18,
    3 => 0.08,
    4 => 0.04,
    5 => 0.02
)

"""
    sample_num_babies()::Int64
    
Sample number of babies born in a single birth event.
"""
function sample_num_babies()::Int64
    r = RandomGenerators.uniform_dict(BABIES_DISTRIBUTION) # Normalization needed
    cumsum = 0.0
    
    for (num_babies, prob) in sort(collect(BABIES_DISTRIBUTION))
        cumsum += prob
        if r < cumsum
            return num_babies
        end
    end
    
    return 1  # fallback
end

# ============================================================================
# Initial Population Generation
# ============================================================================

"""
    sample_initial_age()::Int64
    
Draw initial age uniformly from [0, INITIAL_MAX_AGE] years.
"""
function sample_initial_age()::Int64
    return RandomGenerators.uniform_int(0, SimulatorConfig.INITIAL_MAX_AGE)
end

"""
    sample_desired_children()::Int64
    
Draw initial desired children from the population distribution.
"""
function sample_desired_children()::Int64
    return get_desired_children()
end

# ============================================================================
# Sex Asignation
# ============================================================================

const MALE_PROBABILITY = 0.5

"""
    sample_sex()::PersonModule.Sex
    
Sample sex: PersonModule.male or PersonModule.female.
"""
function sample_sex()::PersonModule.Sex
    rand() < MALE_PROBABILITY ? PersonModule.male : PersonModule.female
end

end # module
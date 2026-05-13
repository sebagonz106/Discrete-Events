"""
    EventEngine

Discrete event simulation engine with typed events and priority queue.
"""

module EventEngine

using DataStructures

export AbstractEvent, DeathEvent, BirthEvent, PregnancyAttemptEvent, 
       YearEndEvent, MarriageEvent, SeparationEvent, EndWaitingPeriodEvent,
       PartnerSearchEvent, EventQueue, process_events!

"""
    AbstractEvent

Base type for all simulation events. All concrete events inherit from this.
"""
abstract type AbstractEvent end

# Define ordering for events by time_days (earliest first)
Base.isless(e1::AbstractEvent, e2::AbstractEvent) = e1.time_days < e2.time_days

"""
    DeathEvent <: AbstractEvent
    
Event representing death of a person.

# Fields
- `time_days::Int64`: When the event occurs (in days)
- `person_id::Int64`: ID of the person who dies
"""
struct DeathEvent <: AbstractEvent
    time_days::Int64
    person_id::Int64
end

"""
    BirthEvent <: AbstractEvent
    
Event representing birth(s) of child(ren).

# Fields
- `time_days::Int64`: When the event occurs
- `mother_id::Int64`: ID of the mother
- `num_babies::Int64`: Number of babies born
"""
struct BirthEvent <: AbstractEvent
    time_days::Int64
    mother_id::Int64
    num_babies::Int64
end

"""
    PregnancyAttemptEvent <: AbstractEvent
    
Event representing a pregnancy attempt.

# Fields
- `time_days::Int64`: When the event occurs
- `mother_id::Int64`: ID of the woman attempting pregnancy
"""
struct PregnancyAttemptEvent <: AbstractEvent
    time_days::Int64
    mother_id::Int64
end

"""
    YearEndEvent <: AbstractEvent
    
Event representing end-of-year aging and aggregation.

# Fields
- `time_days::Int64`: When the event occurs
"""
struct YearEndEvent <: AbstractEvent
    time_days::Int64
end

"""
    MarriageEvent <: AbstractEvent
    
Event representing marriage formation.

# Fields
- `time_days::Int64`: When the event occurs
- `woman_id::Int64`: ID of woman forming partnership
- `man_id::Int64`: ID of man forming partnership
"""
struct MarriageEvent <: AbstractEvent
    time_days::Int64
    woman_id::Int64
    man_id::Int64
end

"""
    SeparationEvent <: AbstractEvent
    
Event representing couple separation.

# Fields
- `time_days::Int64`: When the event occurs
- `person_id::Int64`: ID of person whose partnership ends
"""
struct SeparationEvent <: AbstractEvent
    time_days::Int64
    person_id::Int64
end

"""
    EndWaitingPeriodEvent <: AbstractEvent
    
Event representing end of post-separation waiting period.

# Fields
- `time_days::Int64`: When the event occurs
- `person_id::Int64`: ID of person whose waiting period ends
"""
struct EndWaitingPeriodEvent <: AbstractEvent
    time_days::Int64
    person_id::Int64
end

"""
    PartnerSearchEvent <: AbstractEvent
    
Event representing active search for partnership.

# Fields
- `time_days::Int64`: When the event occurs
- `person_id::Int64`: ID of person searching for partner
"""
struct PartnerSearchEvent <: AbstractEvent
    time_days::Int64
    person_id::Int64
end

# Priority queue based on event time
struct EventQueue
    """Min-heap priority queue ordering events by time_days."""
    heap::BinaryMinHeap{AbstractEvent}
    
    function EventQueue()
        new(BinaryMinHeap{AbstractEvent}())
    end
end

"""
    push!(queue::EventQueue, event::AbstractEvent)
    
Add an event to the queue.
"""
function Base.push!(queue::EventQueue, event::AbstractEvent)::Nothing
    push!(queue.heap, event)
    nothing
end

"""
    pop!(queue::EventQueue)::AbstractEvent
    
Extract the next event (earliest time) from the queue.
"""
function Base.pop!(queue::EventQueue)::AbstractEvent
    pop!(queue.heap)
end

"""
    isempty(queue::EventQueue)::Bool
    
Check if the queue is empty.
"""
function Base.isempty(queue::EventQueue)::Bool
    isempty(queue.heap)
end

"""
    length(queue::EventQueue)::Int64
    
Number of events in queue.
"""
function Base.length(queue::EventQueue)::Int64
    length(queue.heap)
end

end # module

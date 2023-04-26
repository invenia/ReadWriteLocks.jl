module ReadWriteLocks

using Base: AbstractLock, lock, unlock

export ReadWriteLock, get_read_lock, get_write_lock
export readlock, readunlock

struct ReadLock{T<:AbstractLock}
    rwlock::T
end

struct WriteLock{T<:AbstractLock}
    rwlock::T
end

mutable struct ReadWriteLock <: AbstractLock
    readers::Int
    writer::Bool
    condition::Threads.Condition
    read_lock::ReadLock
    write_lock::WriteLock

    function ReadWriteLock(
        readers::Int=0,
        writer::Bool=false,
        condition::Threads.Condition=Threads.Condition(),
    )
        rwlock = new(readers, writer, condition)
        rwlock.read_lock = ReadLock(rwlock)
        rwlock.write_lock = WriteLock(rwlock)
        return rwlock
    end
end

get_read_lock(rwlock::ReadWriteLock) = rwlock.read_lock
get_write_lock(rwlock::ReadWriteLock) = rwlock.write_lock

function Base.lock(read_lock::ReadLock)
    rwlock = read_lock.rwlock
    lock(rwlock.condition)
    try
        while rwlock.writer
            wait(rwlock.condition)
        end
        rwlock.readers += 1
    finally
        # @debug "readlock done" rwlock.readers rwlock.writer
        unlock(rwlock.condition)
    end
    return nothing
end

function Base.unlock(read_lock::ReadLock)
    rwlock = read_lock.rwlock
    lock(rwlock.condition)
    try
        rwlock.readers -= 1
        if rwlock.readers == 0
            notify(rwlock.condition; all=true)
        end
    finally
        # @debug "readunlock done" rwlock.readers rwlock.writer
        unlock(rwlock.condition)
    end
    return nothing
end

function Base.lock(write_lock::WriteLock)
    rwlock = write_lock.rwlock
    lock(rwlock.condition)
    try
        while rwlock.writer
            wait(rwlock.condition)
        end
        rwlock.writer = true
        while rwlock.readers > 0
            wait(rwlock.condition)
        end
    finally
        unlock(rwlock.condition)
        # @debug "lock done" rwlock.readers rwlock.writer
    end
    return nothing
end

function Base.unlock(write_lock::WriteLock)
    rwlock = write_lock.rwlock
    lock(rwlock.condition)
    try
        rwlock.writer = false
        notify(rwlock.condition; all=true)
    finally
        # @debug "unlock done" rwlock.readers rwlock.writer
        unlock(rwlock.condition)
    end
    return nothing
end

Base.lock(rwlock::ReadWriteLock) = lock(get_write_lock(rwlock))
Base.unlock(rwlock::ReadWriteLock) = unlock(get_write_lock(rwlock))
# Reading doesn't count as locked.
Base.islocked(rwlock::ReadWriteLock) = iswriting(rwlock)
# To be writing we must have no readers, else `writer` just indicates a writer is waiting.
iswriting(rwlock::ReadWriteLock) = @lock rwlock.condition ((rwlock.readers == 0) && rwlock.writer)
isreading(rwlock::ReadWriteLock) = @lock rwlock.condition (rwlock.readers > 0)

readlock(rwlock::ReadWriteLock) = lock(get_read_lock(rwlock))
readunlock(rwlock::ReadWriteLock) = unlock(get_read_lock(rwlock))

end # module

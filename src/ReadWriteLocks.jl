module ReadWriteLocks

export ReadWriteLock, read_lock, write_lock, lock!, unlock!

if isdefined(Base, :lock!)
    import Base: lock!
end

if isdefined(Base, :unlock!)
    import Base: unlock!
end

if !isdefined(Base, :Mutex)
    typealias Mutex ReentrantLock

    lock!(x::Mutex) = lock(x)
    unlock!(x::Mutex) = unlock(x)
end

abstract _Lock

immutable ReadLock{T<:_Lock}
    rwlock::T
end

immutable WriteLock{T<:_Lock}
    rwlock::T
end

type ReadWriteLock <: _Lock
    readers::Int
    writer::Bool
    lock::Mutex  # reentrant mutex
    condition::Condition
    read_lock::ReadLock
    write_lock::WriteLock

    function ReadWriteLock()
        rwlock = new(false, 0, Mutex(), Condition())
        rwlock.read_lock = ReadLock(rwlock)
        rwlock.write_lock = WriteLock(rwlock)

        return rwlock
    end
end

read_lock(rwlock::ReadWriteLock) = rwlock.read_lock
write_lock(rwlock::ReadWriteLock) = rwlock.write_lock

function lock!(read_lock::ReadLock)
    rwlock = read_lock.rwlock
    lock!(rwlock.lock)

    try
        while rwlock.writer
            wait(rwlock.condition)
        end

        rwlock.readers += 1
    finally
        unlock!(rwlock.lock)
    end

    return nothing
end

function unlock!(read_lock::ReadLock)
    rwlock = read_lock.rwlock
    lock!(rwlock.lock)

    try
        rwlock.readers -= 1
        if rwlock.readers == 0
            notify(rwlock.condition; all=true)
        end
    finally
        unlock!(rwlock.lock)
    end

    return nothing
end

function lock!(write_lock::WriteLock)
    rwlock = write_lock.rwlock
    lock!(rwlock.lock)

    try
        while rwlock.readers > 0 || rwlock.writer
            wait(rwlock.condition)
        end

        rwlock.writer = true
    finally
        unlock!(rwlock.lock)
    end

    return nothing
end

function unlock!(write_lock::WriteLock)
    rwlock = write_lock.rwlock
    lock!(rwlock.lock)

    try
        rwlock.writer = false
        notify(rwlock.condition; all=true)
    finally
        unlock!(rwlock.lock)
    end

    return nothing
end

end # module

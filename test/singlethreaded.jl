using FactCheck
using ReadWriteLocks

facts("Single-threaded tests") do
    context("Constructor") do
        rwlock = ReadWriteLock()

        @fact rwlock.read_lock.rwlock -> rwlock
        @fact rwlock.write_lock.rwlock -> rwlock
    end
end

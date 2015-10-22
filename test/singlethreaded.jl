using FactCheck
using ReadWriteLocks

facts("Single-threaded tests") do
    context("Initialization") do
        rwlock = ReadWriteLock()

        @fact rwlock.read_lock.rwlock --> rwlock
        @fact rwlock.write_lock.rwlock --> rwlock
        @fact rwlock.readers --> 0
        @fact rwlock.writer --> false
        @fact read_lock(rwlock) --> rwlock.read_lock
        @fact write_lock(rwlock) --> rwlock.write_lock
    end
end

facts("Two-threaded tests") do
    context("Read locks") do
        rwlock = ReadWriteLock()
        rlock = read_lock(rwlock)

        NUM_LOCKS = 10

        @async begin
            @fact rwlock.readers --> 0
            for i = 1:NUM_LOCKS
                @fact lock!(rlock) --> nothing
                @fact rwlock.readers --> i
            end
        end

        sleep(1)

        @fact rwlock.readers --> NUM_LOCKS

        @async begin
            @fact rwlock.readers --> NUM_LOCKS
            for i = NUM_LOCKS:-1:1
                @fact unlock!(rlock) --> nothing
                @fact rwlock.readers --> i - 1
            end
            @fact rwlock.readers --> 0
        end

        sleep(1)

        @fact rwlock.readers --> 0
    end
end

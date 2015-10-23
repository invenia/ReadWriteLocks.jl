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
        NUM_LOCKS = 10

        context("$NUM_LOCKS locks") do
            rwlock = ReadWriteLock()
            rlock = read_lock(rwlock)

            @async begin
                @fact rwlock.writer --> false
                @fact rwlock.readers --> 0
                for i = 1:NUM_LOCKS
                    @fact lock!(rlock) --> nothing
                    @fact rwlock.readers --> i
                end
            end

            sleep(1)

            @fact rwlock.readers --> NUM_LOCKS

            @async begin
                @fact rwlock.writer --> false
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

    context("Write locks") do
        context("two locks") do
            rwlock = ReadWriteLock()
            wlock = write_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @fact rwlock.writer --> false
                @fact rwlock.readers --> 0
                @fact lock!(wlock) --> nothing
                @fact rwlock.writer --> true
                @fact rwlock.readers --> 0
                @fact take!(c) --> :pretest
                put!(c, :prelock)
                @fact lock!(wlock) --> nothing

                # this code should never be reached
                @fact take!(c) --> :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @fact take!(c) --> :prelock
            put!(c, :posttest)

            @fact rwlock.writer --> true
            @fact rwlock.readers --> 0
        end

        context("unlock") do
            rwlock = ReadWriteLock()
            wlock = write_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @fact rwlock.writer --> false
                @fact rwlock.readers --> 0
                @fact lock!(wlock) --> nothing
                @fact rwlock.writer --> true
                @fact rwlock.readers --> 0
                @fact take!(c) --> :pretest
                put!(c, :preunlock)
                @fact unlock!(wlock) --> nothing
                @fact take!(c) --> :preunlock
                put!(c, :postunlock)
            end

            sleep(1)

            @fact take!(c) --> :postunlock
            put!(c, :posttest)

            @fact rwlock.writer --> false
            @fact rwlock.readers --> 0
        end
    end

    context("read and write locks") do
        context("write then read") do
            rwlock = ReadWriteLock()
            wlock = write_lock(rwlock)
            rlock = read_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @fact rwlock.writer --> false
                @fact rwlock.readers --> 0
                @fact lock!(wlock) --> nothing
                @fact rwlock.writer --> true
                @fact rwlock.readers --> 0
                @fact take!(c) --> :pretest
                put!(c, :prelock)
                @fact lock!(rlock) --> nothing

                # this code should never be reached
                @fact take!(c) --> :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @fact take!(c) --> :prelock
            put!(c, :posttest)

            @fact rwlock.writer --> true
            @fact rwlock.readers --> 0
        end

        context("read then write") do
            rwlock = ReadWriteLock()
            wlock = write_lock(rwlock)
            rlock = read_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @fact rwlock.writer --> false
                @fact rwlock.readers --> 0
                @fact lock!(rlock) --> nothing
                @fact rwlock.writer --> false
                @fact rwlock.readers --> 1
                @fact take!(c) --> :pretest
                put!(c, :prelock)
                @fact lock!(wlock) --> nothing

                # this code should never be reached
                @fact take!(c) --> :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @fact take!(c) --> :prelock
            put!(c, :posttest)

            @fact rwlock.writer --> false
            @fact rwlock.readers --> 1
        end
    end

end

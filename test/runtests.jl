using ReadWriteLocks
using Test

@testset "ReadWriteLock" begin

@testset "Constructor" begin
    @test ReadWriteLock() isa ReadWriteLock
    @test ReadWriteLock(0, false) isa ReadWriteLock
end

@testset "Single-threaded tests" begin
    @testset "Initialization" begin
        rwlock = ReadWriteLock()
        @test rwlock.read_lock.rwlock == rwlock
        @test rwlock.write_lock.rwlock == rwlock
        @test rwlock.readers == 0
        @test rwlock.writer == false
        @test get_read_lock(rwlock) == rwlock.read_lock
        @test get_write_lock(rwlock) == rwlock.write_lock
    end
end  # Single-threaded

@testset "Multi-threaded tests" begin
    @assert Threads.nthreads() > 1
    @testset "Read locks" begin
        NUM_LOCKS = 10

        @testset "$NUM_LOCKS locks" begin
            rwlock = ReadWriteLock()
            rlock = get_read_lock(rwlock)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                for i = 1:NUM_LOCKS
                    @test lock(rlock) == nothing
                    # lock(rlock)
                    @test rwlock.readers == i
                end
            end

            sleep(1)

            @test rwlock.readers == NUM_LOCKS

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == NUM_LOCKS
                for i in NUM_LOCKS:-1:1
                    @test unlock(rlock) == nothing
                    @test rwlock.readers == i - 1
                end
                @test rwlock.readers == 0
            end

            sleep(1)

            @test rwlock.readers == 0
        end
    end

    @testset "Write locks" begin
        @testset "two locks" begin
            rwlock = ReadWriteLock()
            wlock = get_write_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock(wlock) == nothing
                @test rwlock.writer == true
                @test rwlock.readers == 0
                @test take!(c) == :pretest
                put!(c, :prelock)
                @test lock(wlock) == nothing

                # this code should never be reached
                @test take!(c) == :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @test take!(c) == :prelock
            put!(c, :posttest)

            @test ReadWriteLocks.iswriting(rwlock)
        end

        @testset "unlock" begin
            rwlock = ReadWriteLock()
            wlock = get_write_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock(wlock) == nothing
                @test rwlock.writer == true
                @test rwlock.readers == 0
                @test take!(c) == :pretest
                put!(c, :preunlock)
                @test unlock(wlock) == nothing
                @test take!(c) == :preunlock
                put!(c, :postunlock)
            end

            sleep(1)

            @test take!(c) == :postunlock
            put!(c, :posttest)

            @test rwlock.writer == false
            @test rwlock.readers == 0
        end
    end

    @testset "read and write locks" begin
        @testset "write then read" begin
            rwlock = ReadWriteLock()
            wlock = get_write_lock(rwlock)
            rlock = get_read_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock(wlock) == nothing
                @test rwlock.writer == true
                @test rwlock.readers == 0
                @test take!(c) == :pretest
                put!(c, :prelock)
                @test lock(rlock) == nothing

                # this code should never be reached
                @test take!(c) == :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @test take!(c) == :prelock
            put!(c, :posttest)

            @test ReadWriteLocks.iswriting(rwlock)
        end

        @testset "read then write" begin
            rwlock = ReadWriteLock()
            wlock = get_write_lock(rwlock)
            rlock = get_read_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock(rlock) == nothing
                @test rwlock.writer == false
                @test rwlock.readers == 1
                @test take!(c) == :pretest
                put!(c, :prelock)
                @test lock(wlock) == nothing

                # this code should never be reached
                @test take!(c) == :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @test take!(c) == :prelock
            put!(c, :posttest)

            @test ReadWriteLocks.isreading(rwlock)
            @test rwlock.readers == 1
        end
    end
end  # Multi-threaded

@testset "Write-preferred" begin
    rw = ReadWriteLock()
    @testset "test read is blocked while writing" begin
        lock(rw)
        c = Channel()
        t = @async begin
            put!(c, nothing)
            readlock(rw)
            take!(c)
            readunlock(rw)
            true
        end
        take!(c)
        @test !istaskdone(t)
        unlock(rw)
        @test !istaskdone(t)
        put!(c, nothing)
        @test fetch(t)
    end

    @testset "test write is blocked until reader done" begin
        readlock(rw)
        c = Channel()
        t = @async begin
            put!(c, nothing)
            lock(rw)
            take!(c)
            @test islocked(rw)
            unlock(rw)
            true
        end
        take!(c)
        @test !istaskdone(t)
        readunlock(rw)
        @test !istaskdone(t)
        put!(c, nothing)
        @test fetch(t)
    end

    @testset "test new reads blocked on pending write, and vice versa" begin
        readlock(rw)
        # readlock doesn't count as "locked"
        @test !islocked(rw)
        # start another reader
        secondReaderLocked = Ref(false)
        c = Channel()
        r2 = @async begin
            put!(c, nothing)
            readlock(rw)
            secondReaderLocked[] = true
            take!(c)
            readunlock(rw)
            true
        end
        take!(c)
        wc = Channel()
        t = @async begin
            put!(wc, nothing)
            lock(rw)
            take!(wc)
            unlock(rw)
            true
        end
        take!(wc)
        sleep(1)
        # write task not done
        @test !istaskdone(t)
        # first reader not done
        @test !istaskdone(r2)
        # but first reader did lock
        @test secondReaderLocked[]
        # start a third reader
        thirdReaderLocked = Ref(false)
        c2 = Channel()
        r3 = @async begin
            put!(c2, nothing)
            readlock(rw)
            thirdReaderLocked[] = true
            take!(c2)
            readunlock(rw)
            true
        end
        take!(c2)
        # no tasks have finished yet
        @test !istaskdone(t)
        @test !istaskdone(r2)
        @test !istaskdone(r3)
        # but third reader didn't lock because it's blocked
        # on a _pending_ write
        @test !thirdReaderLocked[]
        # second writer, which should wait til after the already-queued third reader
        wc2 = Channel()
        t2 = @async begin
            put!(wc2, nothing)
            lock(rw)
            take!(wc2)
            unlock(rw)
            true
        end
        take!(wc2)
        # unblock r2
        put!(c, nothing)
        # it should finish
        @test fetch(r2)
        # now unlock 1st reader so write can happen
        readunlock(rw)
        # write task should finish
        put!(wc, nothing)
        @test fetch(t)
        # now that write has finished, r3 should have lock
        put!(c2, nothing)
        @test thirdReaderLocked[]
        @test fetch(r3)
        # only now r3 has finished should t2 have lock
        put!(wc2, nothing)
        @test fetch(t2)
        @test !islocked(rw)
    end
end

end  # ReadWriteLocks

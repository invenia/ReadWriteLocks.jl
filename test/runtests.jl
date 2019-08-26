using ReadWriteLocks
using Test

@testset "ReadWriteLock" begin

@testset "Constructor" begin
    @test ReadWriteLock() isa ReadWriteLock{ReentrantLock}
    @test ReadWriteLock(0, false, Threads.Mutex()) isa ReadWriteLock{Threads.Mutex}
end

@testset "Single-threaded tests" begin
    @testset "Initialization" begin
        rwlock = ReadWriteLock()

        @test rwlock.read_lock.rwlock == rwlock
        @test rwlock.write_lock.rwlock == rwlock
        @test rwlock.readers == 0
        @test rwlock.writer == false
        @test read_lock(rwlock) == rwlock.read_lock
        @test write_lock(rwlock) == rwlock.write_lock
    end
end  # Single-threaded

@testset "Two-threaded tests" begin
    @testset "Read locks" begin
        NUM_LOCKS = 10

        @testset "$NUM_LOCKS locks" begin
            rwlock = ReadWriteLock()
            rlock = read_lock(rwlock)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                for i = 1:NUM_LOCKS
                    @test lock!(rlock) == nothing
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
                    @test unlock!(rlock) == nothing
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
            wlock = write_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock!(wlock) == nothing
                @test rwlock.writer == true
                @test rwlock.readers == 0
                @test take!(c) == :pretest
                put!(c, :prelock)
                @test lock!(wlock) == nothing

                # this code should never be reached
                @test take!(c) == :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @test take!(c) == :prelock
            put!(c, :posttest)

            @test rwlock.writer == true
            @test rwlock.readers == 0
        end

        @testset "unlock" begin
            rwlock = ReadWriteLock()
            wlock = write_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock!(wlock) == nothing
                @test rwlock.writer == true
                @test rwlock.readers == 0
                @test take!(c) == :pretest
                put!(c, :preunlock)
                @test unlock!(wlock) == nothing
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
            wlock = write_lock(rwlock)
            rlock = read_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock!(wlock) == nothing
                @test rwlock.writer == true
                @test rwlock.readers == 0
                @test take!(c) == :pretest
                put!(c, :prelock)
                @test lock!(rlock) == nothing

                # this code should never be reached
                @test take!(c) == :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @test take!(c) == :prelock
            put!(c, :posttest)

            @test rwlock.writer == true
            @test rwlock.readers == 0
        end

        @testset "read then write" begin
            rwlock = ReadWriteLock()
            wlock = write_lock(rwlock)
            rlock = read_lock(rwlock)

            c = Channel{Symbol}(1)
            put!(c, :pretest)

            @async begin
                @test rwlock.writer == false
                @test rwlock.readers == 0
                @test lock!(rlock) == nothing
                @test rwlock.writer == false
                @test rwlock.readers == 1
                @test take!(c) == :pretest
                put!(c, :prelock)
                @test lock!(wlock) == nothing

                # this code should never be reached
                @test take!(c) == :prelock
                put!(c, :postlock)
            end

            sleep(1)

            @test take!(c) == :prelock
            put!(c, :posttest)

            @test rwlock.writer == false
            @test rwlock.readers == 1
        end
    end
end  # Two-threaded

end  # ReadWriteLocks

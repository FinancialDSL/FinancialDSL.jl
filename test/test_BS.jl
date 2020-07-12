
import FinancialDSL.BS

@testset "BS Price" begin
    @testset "no dividends" begin

        let
            s = 42
            k = 40
            r = 0.1
            sigma = 0.2
            t = 0.5

            @test BS.bscall(s, k*exp(-r*t), t, sigma) ≈ 4.759422392871542
            @test BS.bsput(s, k*exp(-r*t), t, sigma) ≈ 0.8085993729000975
            @test BS.price(BS.EuropeanCall(), s, k*exp(-r*t), t, sigma) ≈ 4.759422392871542
            @test BS.price(BS.EuropeanPut(), s, k*exp(-r*t), t, sigma) ≈ 0.8085993729000975
        end

        let
            s = 40.0
            k = 40.0
            r = 0.1
            t = 0.5
            sigma = 0.3

            @test BS.bscall(s, k*exp(-r*t), t, sigma) ≈ 4.3625999408029585
            @test BS.bsput(s, k*exp(-r*t), t, sigma) ≈ 2.4117769208315245
            @test BS.price(BS.EuropeanCall(), s, k*exp(-r*t), t, sigma) ≈ 4.3625999408029585
            @test BS.price(BS.EuropeanPut(), s, k*exp(-r*t), t, sigma) ≈ 2.4117769208315245
        end
    end

    @testset "dividends q" begin

        let
            s = 930
            k = 900
            r = 0.08
            sigma = 0.2
            t = 2/12
            q = 0.03

            @test BS.bscall(s*exp(-q*t), k*exp(-r*t), t, sigma) ≈ 51.83295679649086
            @test BS.bsput(s*exp(-q*t), k*exp(-r*t), t, sigma) ≈ 14.550996773772397
            @test BS.price(BS.EuropeanCall(), s*exp(-q*t), k*exp(-r*t), t, sigma) ≈ 51.83295679649086
            @test BS.price(BS.EuropeanPut(), s*exp(-q*t), k*exp(-r*t), t, sigma) ≈ 14.550996773772397
        end

        let
            s = 1.8
            k = 1.8
            r = 0.1
            rf = 0.03
            t = 0.5
            sigma = 0.2

            @test BS.bscall(s*exp(-rf*t), k*exp(-r*t), t, sigma) ≈ 0.13172208280604858
            @test BS.bsput(s*exp(-rf*t), k*exp(-r*t), t, sigma) ≈ 0.07073355562182104
            @test BS.price(BS.EuropeanCall(), s*exp(-rf*t), k*exp(-r*t), t, sigma) ≈ 0.13172208280604858
            @test BS.price(BS.EuropeanPut(), s*exp(-rf*t), k*exp(-r*t), t, sigma) ≈ 0.07073355562182104
        end
    end
end

@testset "impvol" begin
    @testset "no dividends" begin
        s = 40
        k = 40
        r = 0.1
        t = 1

        @test BS.impvol(BS.EuropeanCall(), 4.12, s, k*exp(-r*t), t) ≈ 0.099644799474057
        @test BS.impvol(BS.EuropeanPut(), 4.12, s, k*exp(-r*t), t) ≈ 0.3860639608047352

        @test BS.impvol(BS.EuropeanCall(), 17, s, k*exp(-r*t), t) ≈ 1.0332662114853954
        @test BS.impvol(BS.EuropeanPut(), 13.15, s, k*exp(-r*t), t) ≈ 1.0299775738714554
    end

    @testset "dividends q" begin
        s = 1.8
        k = 1.8
        r = 0.1
        rf = 0.03
        t = 0.5
        sigma = 0.2

        call_price = 0.13172208280604858
        put_price = 0.07073355562182104

        @test BS.impvol(BS.EuropeanCall(), call_price, s*exp(-rf*t), k*exp(-r*t), t) ≈ sigma
        @test BS.impvol(BS.EuropeanPut(), put_price, s*exp(-rf*t), k*exp(-r*t), t) ≈ sigma
    end
end

@testset "Greeks" begin

    s = 49
    k = 50
    r = 0.05
    t = 0.3846
    sigma = 0.2

    @testset "Delta" begin
        @test BS.delta(BS.EuropeanCall(), s, k*exp(-r*t), t, sigma) ≈ 0.5216016339715761
        @test BS.delta(BS.EuropeanPut(), s, k*exp(-r*t), t, sigma) ≈ -0.4783983660284239
    end

    @testset "Theta" begin
        @test BS.theta(BS.EuropeanCall(), s, k*exp(-r*t), t, r, sigma) ≈ -4.305389964546104
        @test BS.theta(BS.EuropeanPut(), s, k*exp(-r*t), t, r, sigma) ≈ -1.853005672196868
    end

    @testset "Gamma" begin
        @test BS.gamma(BS.EuropeanCall(), s, k*exp(-r*t), t, sigma) ≈ 0.06554537725247868
        @test BS.gamma(BS.EuropeanPut(), s, k*exp(-r*t), t, sigma) ≈ 0.06554537725247868
    end

    @testset "Vega" begin
        @test BS.vega(BS.EuropeanCall(), s, k*exp(-r*t), t, sigma) ≈ 12.105242754243843
        @test BS.vega(BS.EuropeanPut(), s, k*exp(-r*t), t, sigma) ≈ 12.105242754243843
    end

    @testset "Rho" begin
        @test BS.rho(BS.EuropeanCall(), s, k*exp(-r*t), t, sigma) ≈ 8.906574098800945
        @test BS.rho(BS.EuropeanPut(), s, k*exp(-r*t), t, sigma) ≈ -9.95716587794938
    end
end

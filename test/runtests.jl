using Test

const _EXAMPLES_DIR = joinpath(dirname(@__DIR__), "examples")

# Setup and initialize the subproblem solvers for the example using GLPK.
running_tests = true
include(joinpath(_EXAMPLES_DIR, "solvers", "setup_glpk.jl"))

@testset "JuDGE tests" begin
    @testset "Tree building" begin
        include(joinpath(_EXAMPLES_DIR, "custom_trees.jl"))
        @test TreeA()
        @test TreeB()
        @test TreeC()
        @test TreeD()
    end
    @testset "Multistage newsvendor" begin
        include(joinpath(_EXAMPLES_DIR, "newsvendor.jl"))
        @test newsvendor(cost = 5.0, price = 8.0, demands = [10, 80, 100]) ≈
              -53.333 atol = 1e-3
        @test newsvendor(
            cost = 5.0,
            price = 8.0,
            demands = [10, 80, 100],
            CVaR = Risk(0.5, 0.5),
        ) ≈ -30.0 atol = 1e-3
        @test newsvendor(
            depth = 2,
            cost = 5.0,
            price = 8.0,
            demands = [10, 20, 30],
            CVaR = Risk(0.15, 0.5),
        ) ≈ -61.011 atol = 1e-3
        @test newsvendor(
            depth = 3,
            cost = 5.0,
            price = 8.0,
            demands = [10, 20, 30],
            CVaR = Risk(0.15, 0.05),
        ) ≈ -90.526 atol = 1e-3
    end

    @testset "Inventory" begin
        include(joinpath(_EXAMPLES_DIR, "inventory.jl"))
        @test inventory(
            depth = 2,
            degree = 2,
            price_array = [
                0.1172393013694979,
                0.25653400961083994,
                4.2365322616699785e-6,
                0.7161790267880648,
                0.05823720128592225,
                0.04993686809222453,
                0.9201443039152302,
            ],
        ) ≈ -13.949 atol = 1e-3

        @test inventory(
            depth = 2,
            degree = 2,
            price_array = [
                0.1172393013694979,
                0.25653400961083994,
                4.2365322616699785e-6,
                0.7161790267880648,
                0.05823720128592225,
                0.04993686809222453,
                0.9201443039152302,
            ],
            risk = Risk(0.1, bound = 1.0),
        ) ≈ -10.467 atol = 1e-3
    end

    @testset "Stochastic Knapsack" begin
        include(joinpath(_EXAMPLES_DIR, "knapsacks.jl"))
        @test knapsack_fixed() ≈ -131.25 atol = 1e-3
        @test knapsack_shutdown() ≈ -145.25 atol = 1e-3
        @test knapsack_budget() ≈ -159.0 atol = 1e-3
    end

    @testset "Transportation network expansion" begin
        include(joinpath(_EXAMPLES_DIR, "transportation.jl"))
        @test transportation(visualise = false) ≈ 1924.35 atol = 1e-2
    end

    @testset "EVPI / VSS" begin
        include(joinpath(_EXAMPLES_DIR, "EVPI_and_VSS.jl"))
        rand_array = [
            [0.9285522637900692, 0.639554206763252],
            [0.2550390316498472, 0.12850390562178804],
            [0.01903038360488818, 0.8677540481810788],
            [0.029195083385896492, 0.9501500215728851],
            [0.5025252801061382, 0.360840817935415],
            [0.9645874251660775, 0.7742823273673713],
            [0.0013293971256227444, 0.1962305791266088],
            [0.49530589276470316, 0.5854358607381882],
            [0.8363603970811022, 0.4477968785843065],
            [0.5490328458349667, 0.7446942148334452],
            [0.7716572130803989, 0.1833665185052309],
            [0.17277566290022284, 0.04556885137272637],
            [0.4106757829026111, 0.8392756200113194],
            [0.9996910161845876, 0.9353282712864677],
            [0.5667914863182641, 0.4937475292065645],
            [0.6407854142180103, 0.345182009414815],
            [0.2247744035659487, 0.916501760104206],
            [0.7063421116428517, 0.6349092819034194],
            [0.26945021409079883, 0.9685137654313614],
            [0.13794691405084292, 0.08109652514566346],
            [0.23774800929785211, 0.6449053588249267],
            [0.9360620022251016, 0.8657805174717863],
            [0.6221207380633154, 0.5545887910182519],
            [0.9169806992029002, 0.4512789704567908],
            [0.3039241723843822, 0.06848673470971867],
            [0.6372134576343893, 0.3001451683954608],
            [0.5649893263779449, 0.8252831784097747],
            [0.7809494053110038, 0.7036479258527133],
            [0.12392317513422735, 0.022371298197023437],
            [0.22477507580636513, 0.518020939785814],
            [0.20215046908206924, 0.39169587043503196],
            [0.7729097183241953, 0.3686974874664699],
            [0.3254939985944736, 0.41473985186526763],
            [0.8227426391764456, 0.3512546747792742],
            [0.6111134789520087, 0.08600611003616687],
            [0.12468600337158997, 0.4834038695680498],
            [0.9093572022974008, 0.45105957375851546],
            [0.11774681622462935, 0.5510248259455395],
            [0.783369390293269, 0.41865644297032345],
            [0.17296743953635807, 0.8357113558305245],
            [
                0.37657728483886355,
                0.08919243502048602,
                0.8217304475404175,
                0.48063828796518493,
                0.2978651919639774,
            ],
            [
                0.5835818725363928,
                0.17583177169625852,
                0.9612707022193245,
                0.18311121016354148,
                0.04268245435421081,
            ],
            [
                0.2681393649799175,
                0.5947643237645366,
                0.12935887740372531,
                0.16137134771126815,
                0.5160906495292201,
            ],
            [
                0.7716353287872098,
                0.6560925268865281,
                0.8125359547954114,
                0.2711314984004618,
                0.8069037929594962,
            ],
            [
                0.07227293035235505,
                0.2985897526690493,
                0.6697162600525157,
                0.08151587754093836,
                0.7835462540680733,
            ],
            [
                0.6244539141761503,
                0.13031149003758746,
                0.1859636270194931,
                0.7053765545745261,
                0.06380472154935735,
            ],
            [
                0.6380570825067451,
                0.31528007638647493,
                0.8876242583607103,
                0.06093663616653355,
                0.19492276161317545,
            ],
            [
                0.2866370362345463,
                0.6543572329916341,
                0.46973880137006496,
                0.9433049593133176,
                0.8897831622447485,
            ],
            [
                0.3303996857917435,
                0.8283238502295649,
                0.2823539683780629,
                0.25669425376371935,
                0.26572532920739644,
            ],
            [
                0.7886640534042393,
                0.989764638944147,
                0.5317613502090843,
                0.8628325847010827,
                0.6645324597583944,
            ],
            [
                0.7691927127155196,
                0.3338126624950546,
                0.7561403354956311,
                0.5119831913213206,
                0.17628763004861803,
            ],
            [
                0.6780854355950252,
                0.9037237436427117,
                0.84061464364998,
                0.4043338588227203,
                0.974142749139157,
            ],
            [
                0.001933293058842045,
                0.8437972757494785,
                0.45563479110236815,
                0.6810782076256636,
                0.37170190270174586,
            ],
            [
                0.4564083603323068,
                0.03636401068027162,
                0.7311613676155448,
                0.919832534208727,
                0.8603600860028158,
            ],
            [
                0.6237407132624493,
                0.2181010251411235,
                0.9483966938604111,
                0.26046255081190495,
                0.5744939208804873,
            ],
            [
                0.9060695843471347,
                0.38949774172571283,
                0.4642625208242577,
                0.6901547433399953,
                0.44834770204492447,
            ],
            [
                0.9061046966128967,
                0.6650906197758282,
                0.016960760994876978,
                0.7556274828789891,
                0.9419973158464987,
            ],
            [
                0.15922171131775698,
                0.5703775855966942,
                0.004205426010382984,
                0.4064034025053689,
                0.9388977620725911,
            ],
            [
                0.8859640701556215,
                0.7035134477177418,
                0.17890714699942123,
                0.30674354442615615,
                0.6641564705323306,
            ],
            [
                0.326071428631451,
                0.7863979419912,
                0.44589586058564,
                0.059845177172276776,
                0.3916098674741799,
            ],
            [
                0.2844547493287328,
                0.565799734172199,
                0.577014275812689,
                0.18174135420750726,
                0.34164523779656686,
            ],
            [
                0.7310594436995184,
                0.9009484487906736,
                0.3241994172468603,
                0.2839161688399039,
                0.7791613271649067,
            ],
            [
                0.003962320810718678,
                0.9657117185614146,
                0.06457209778410355,
                0.5708570346074369,
                0.499899435901737,
            ],
            [
                0.702349480813441,
                0.3797107814143379,
                0.43888514844532533,
                0.981139395610767,
                0.8366923620274176,
            ],
            [
                0.3687874113942564,
                0.8428452695607893,
                0.1584963616121291,
                0.10238037016904933,
                0.7236718291925408,
            ],
            [
                0.7758997407567665,
                0.6696869005228854,
                0.9365993899565324,
                0.6756811021808136,
                0.972413730942771,
            ],
            [
                0.8942867823795821,
                0.8233930121549466,
                0.633717449933572,
                0.7773582969223765,
                0.9544638570781785,
            ],
            [
                0.9892662492442923,
                0.7385589631849714,
                0.06963768643191726,
                0.7769293456871889,
                0.6293435766769764,
            ],
            [
                0.1630984868304053,
                0.09717786340427792,
                0.5776212535118121,
                0.8241723148574815,
                0.26837582017083106,
            ],
            [
                0.11232179636490103,
                0.7130287223971308,
                0.5139557007797009,
                0.1250490925100054,
                0.6056539340381277,
            ],
            [
                0.2826511285198472,
                0.36369222097323073,
                0.6453610891943975,
                0.4945644189234,
                0.4558154334754496,
            ],
            [
                0.5898050904430596,
                0.6267820704760299,
                0.31774498845513044,
                0.10608656729701549,
                0.5972937705178831,
            ],
            [
                0.44681230236255454,
                0.7694224193863302,
                0.8387825741568138,
                0.5491948685067796,
                0.5462896645313304,
            ],
            [
                0.34647035849853647,
                0.677866306853439,
                0.14802567173884662,
                0.5853401452196185,
                0.49660699704474665,
            ],
            [
                0.04010450598951776,
                0.4323537358583909,
                0.6051597915404949,
                0.1228801164918174,
                0.023649010585060415,
            ],
            [
                0.8438028701302518,
                0.14833818836433177,
                0.1652647603232007,
                0.21682967335301084,
                0.9287668506162368,
            ],
            [
                0.3103853277827133,
                0.8948453201512141,
                0.28791320015120125,
                0.6603153683169105,
                0.9631949742645292,
            ],
            [
                0.5462457337828268,
                0.22858502379982393,
                0.44387469985482286,
                0.3668311840412648,
                0.12288713747244406,
            ],
            [
                0.028045156131478288,
                0.41427257951936136,
                0.010545889193398272,
                0.4945759323684624,
                0.3575686773710922,
            ],
            [
                0.8766891124164362,
                0.2456181847464125,
                0.29921230345027694,
                0.47084551798597496,
                0.8957277153607,
            ],
            [
                0.9329712080135879,
                0.11469632758247705,
                0.49247845826633396,
                0.20103190749151278,
                0.2917079950461181,
            ],
            [
                0.09939981199872938,
                0.9445165717478672,
                0.5157612326458747,
                0.36697128989458005,
                0.8274280033131702,
            ],
            [
                0.9507534786401275,
                0.34922306415564575,
                0.7484775579623038,
                0.023625200356430343,
                0.8004047957259981,
            ],
            [
                0.4977803879248546,
                0.5098359092437252,
                0.81854697124745,
                0.5701013785284206,
                0.3879490130089087,
            ],
            [
                0.20035638197983197,
                0.5654613196539646,
                0.9716569264742343,
                0.12771764452934464,
                0.17905214399196878,
            ],
            [
                0.6040996465101813,
                0.32940520735148504,
                0.23373006616735892,
                0.09450973234890658,
                0.8638314351164669,
            ],
            [
                0.23105272036649738,
                0.9059450157356039,
                0.18611931410278126,
                0.3399136572251058,
                0.8239112012239709,
            ],
            [
                0.5271155765957956,
                0.4032031931702931,
                0.4430440468872807,
                0.6438356803132312,
                0.5211173165985019,
            ],
            [
                0.5614801765852715,
                0.26788039947334474,
                0.8491296268057986,
                0.7239116097327583,
                0.652097728321968,
            ],
            [
                0.4428307054959737,
                0.753423030930253,
                0.8367998124196305,
                0.47116885695921584,
                0.9330149660778491,
            ],
            [
                0.6053155722211951,
                0.22185822182579473,
                0.5650413922607476,
                0.48696630519349426,
                0.34062009360935663,
            ],
            [
                0.5605607324300428,
                0.8500218596265186,
                0.7217616626188621,
                0.3957690487625243,
                0.2691714889418615,
            ],
            [
                0.16574698914725539,
                0.19201873313807716,
                0.2556734405193055,
                0.17149419714768688,
                0.07042308183718893,
            ],
            [
                0.7060096421270663,
                0.2492588340105124,
                0.4224747477153512,
                0.4233919129680461,
                0.39856518803392094,
            ],
            [
                0.031066433188569276,
                0.07699408909348882,
                0.7613382326605802,
                0.6739261870178432,
                0.47857264115005926,
            ],
            [
                0.601593922180921,
                0.19086535071903898,
                0.7371831981379018,
                0.07403635468341885,
                0.2806029786095192,
            ],
            [
                0.08351422911927542,
                0.11523238989461637,
                0.8919216772655922,
                0.5224456675864173,
                0.5981319804684919,
            ],
            [
                0.9957351161994494,
                0.16280270157317922,
                0.10621675042882628,
                0.6608967375244734,
                0.5868975506896927,
            ],
            [
                0.6072047896026491,
                0.8804229737640084,
                0.057201334660706316,
                0.4892636323692108,
                0.05382647168137056,
            ],
            [
                0.2818601077443652,
                0.6586510906414977,
                0.7251516984154529,
                0.8030514105728912,
                0.972205277675912,
            ],
            [
                0.8386102781333717,
                0.4966098314864431,
                0.4828441538674353,
                0.1070888655035076,
                0.6544437589025489,
            ],
            [
                0.26952941336849756,
                0.495583804060044,
                0.8055335690664109,
                0.27816432055210627,
                0.23525862034267075,
            ],
            [
                0.782612521564537,
                0.665363835418268,
                0.13126756051973376,
                0.6374482830222514,
                0.7048234586034166,
            ],
            [
                0.17928185588897083,
                0.7523064527040721,
                0.8113073483571704,
                0.8205438887833665,
                0.9177494986988455,
            ],
            [
                0.04528439717300281,
                0.5709512239860834,
                0.3729096463715742,
                0.7762162893943181,
                0.7038977948277818,
            ],
            [
                0.5966954349435003,
                0.24625980860735464,
                0.4834565873778751,
                0.9356308080620384,
                0.4547713091283845,
            ],
            [
                0.11168854269362716,
                0.389122926113437,
                0.9138591208524156,
                0.36016412794453134,
                0.6268904815801846,
            ],
            [
                0.8244439669102421,
                0.6355763413258122,
                0.3261561592207396,
                0.3004562720429351,
                0.18466250300778908,
            ],
            [
                0.34619762095669593,
                0.9891201476734026,
                0.21915334490799365,
                0.290867414187832,
                0.4316414310616521,
            ],
            [
                0.5265062835239567,
                0.15641333142347014,
                0.013721081076195185,
                0.9547458069843304,
                0.5572719378183824,
            ],
            [
                0.7107862242018355,
                0.760317181021867,
                0.2578734000761256,
                0.24161439820576325,
                0.6489745880599003,
            ],
            [
                0.07319113312597691,
                0.44708866652098656,
                0.6491318343110297,
                0.7178974641565323,
                0.01586319392518787,
            ],
            [
                0.989595414378452,
                0.8679858389102926,
                0.3399628761011151,
                0.9828782390582884,
                0.6559497585110725,
            ],
            [
                0.04342563932063137,
                0.2107429010966091,
                0.4120205040007596,
                0.48178634111996077,
                0.5483565212455386,
            ],
            [
                0.4660538502159528,
                0.4972773035217628,
                0.24984991057677441,
                0.015564301027926275,
                0.2990578261618395,
            ],
            [
                0.7438952746543379,
                0.8466248637630314,
                0.6014965836210135,
                0.829523784809316,
                0.6022004950220035,
            ],
            [
                0.24753559056074015,
                0.8405219586439603,
                0.1836669406760929,
                0.35136760645776177,
                0.53042084415301,
            ],
            [
                0.06629627165369989,
                0.872694016007725,
                0.9560848303230323,
                0.02142383513021917,
                0.02747718561373036,
            ],
            [
                0.8770057569256215,
                0.16291244867601073,
                0.45060039066991675,
                0.4497625424995626,
                0.04357736060010109,
            ],
            [
                0.30778444144437134,
                0.47196289167036176,
                0.5565272063194531,
                0.39688262731916124,
                0.8376889377000198,
            ],
        ]
        @test sum(evpi_vss(29, 5, false, 0.0, array = rand_array)) ≈ -17.651 atol =
            0.001
    end
end

running_tests = false

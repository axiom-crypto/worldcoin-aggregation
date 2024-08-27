// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract V2Claim128Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        assembly ("memory-safe") {
            // Enforce that Solidity memory layout is respected
            let data := mload(0x40)
            if iszero(eq(data, 0x80)) { revert(0, 0) }

            let success := true
            let f_p := 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47
            let f_q := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001
            function validate_ec_point(x, y) -> valid {
                {
                    let x_lt_p := lt(x, 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47)
                    let y_lt_p := lt(y, 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47)
                    valid := and(x_lt_p, y_lt_p)
                }
                {
                    let y_square := mulmod(y, y, 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47)
                    let x_square := mulmod(x, x, 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47)
                    let x_cube :=
                        mulmod(x_square, x, 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47)
                    let x_cube_plus_3 :=
                        addmod(x_cube, 3, 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47)
                    let is_affine := eq(x_cube_plus_3, y_square)
                    valid := and(valid, is_affine)
                }
            }
            mstore(0xa0, mod(calldataload(0x0), f_q))
            mstore(0xc0, mod(calldataload(0x20), f_q))
            mstore(0xe0, mod(calldataload(0x40), f_q))
            mstore(0x100, mod(calldataload(0x60), f_q))
            mstore(0x120, mod(calldataload(0x80), f_q))
            mstore(0x140, mod(calldataload(0xa0), f_q))
            mstore(0x160, mod(calldataload(0xc0), f_q))
            mstore(0x180, mod(calldataload(0xe0), f_q))
            mstore(0x1a0, mod(calldataload(0x100), f_q))
            mstore(0x1c0, mod(calldataload(0x120), f_q))
            mstore(0x1e0, mod(calldataload(0x140), f_q))
            mstore(0x200, mod(calldataload(0x160), f_q))
            mstore(0x220, mod(calldataload(0x180), f_q))
            mstore(0x240, mod(calldataload(0x1a0), f_q))
            mstore(0x260, mod(calldataload(0x1c0), f_q))
            mstore(0x280, mod(calldataload(0x1e0), f_q))
            mstore(0x2a0, mod(calldataload(0x200), f_q))
            mstore(0x2c0, mod(calldataload(0x220), f_q))
            mstore(0x80, 19249720738621557842544153648921016995920615484757851201077930022178027345614)

            {
                let x := calldataload(0x240)
                mstore(0x2e0, x)
                let y := calldataload(0x260)
                mstore(0x300, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x320, keccak256(0x80, 672))
            {
                let hash := mload(0x320)
                mstore(0x340, mod(hash, f_q))
                mstore(0x360, hash)
            }

            {
                let x := calldataload(0x280)
                mstore(0x380, x)
                let y := calldataload(0x2a0)
                mstore(0x3a0, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x2c0)
                mstore(0x3c0, x)
                let y := calldataload(0x2e0)
                mstore(0x3e0, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x400, keccak256(0x360, 160))
            {
                let hash := mload(0x400)
                mstore(0x420, mod(hash, f_q))
                mstore(0x440, hash)
            }
            mstore8(1120, 1)
            mstore(0x460, keccak256(0x440, 33))
            {
                let hash := mload(0x460)
                mstore(0x480, mod(hash, f_q))
                mstore(0x4a0, hash)
            }

            {
                let x := calldataload(0x300)
                mstore(0x4c0, x)
                let y := calldataload(0x320)
                mstore(0x4e0, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x340)
                mstore(0x500, x)
                let y := calldataload(0x360)
                mstore(0x520, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x380)
                mstore(0x540, x)
                let y := calldataload(0x3a0)
                mstore(0x560, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x580, keccak256(0x4a0, 224))
            {
                let hash := mload(0x580)
                mstore(0x5a0, mod(hash, f_q))
                mstore(0x5c0, hash)
            }

            {
                let x := calldataload(0x3c0)
                mstore(0x5e0, x)
                let y := calldataload(0x3e0)
                mstore(0x600, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x400)
                mstore(0x620, x)
                let y := calldataload(0x420)
                mstore(0x640, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x440)
                mstore(0x660, x)
                let y := calldataload(0x460)
                mstore(0x680, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x480)
                mstore(0x6a0, x)
                let y := calldataload(0x4a0)
                mstore(0x6c0, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x6e0, keccak256(0x5c0, 288))
            {
                let hash := mload(0x6e0)
                mstore(0x700, mod(hash, f_q))
                mstore(0x720, hash)
            }
            mstore(0x740, mod(calldataload(0x4c0), f_q))
            mstore(0x760, mod(calldataload(0x4e0), f_q))
            mstore(0x780, mod(calldataload(0x500), f_q))
            mstore(0x7a0, mod(calldataload(0x520), f_q))
            mstore(0x7c0, mod(calldataload(0x540), f_q))
            mstore(0x7e0, mod(calldataload(0x560), f_q))
            mstore(0x800, mod(calldataload(0x580), f_q))
            mstore(0x820, mod(calldataload(0x5a0), f_q))
            mstore(0x840, mod(calldataload(0x5c0), f_q))
            mstore(0x860, mod(calldataload(0x5e0), f_q))
            mstore(0x880, mod(calldataload(0x600), f_q))
            mstore(0x8a0, mod(calldataload(0x620), f_q))
            mstore(0x8c0, mod(calldataload(0x640), f_q))
            mstore(0x8e0, mod(calldataload(0x660), f_q))
            mstore(0x900, mod(calldataload(0x680), f_q))
            mstore(0x920, mod(calldataload(0x6a0), f_q))
            mstore(0x940, mod(calldataload(0x6c0), f_q))
            mstore(0x960, mod(calldataload(0x6e0), f_q))
            mstore(0x980, mod(calldataload(0x700), f_q))
            mstore(0x9a0, keccak256(0x720, 640))
            {
                let hash := mload(0x9a0)
                mstore(0x9c0, mod(hash, f_q))
                mstore(0x9e0, hash)
            }
            mstore8(2560, 1)
            mstore(0xa00, keccak256(0x9e0, 33))
            {
                let hash := mload(0xa00)
                mstore(0xa20, mod(hash, f_q))
                mstore(0xa40, hash)
            }

            {
                let x := calldataload(0x720)
                mstore(0xa60, x)
                let y := calldataload(0x740)
                mstore(0xa80, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0xaa0, keccak256(0xa40, 96))
            {
                let hash := mload(0xaa0)
                mstore(0xac0, mod(hash, f_q))
                mstore(0xae0, hash)
            }

            {
                let x := calldataload(0x760)
                mstore(0xb00, x)
                let y := calldataload(0x780)
                mstore(0xb20, y)
                success := and(validate_ec_point(x, y), success)
            }
            {
                let x := mload(0xa0)
                x := add(x, shl(88, mload(0xc0)))
                x := add(x, shl(176, mload(0xe0)))
                mstore(2880, x)
                let y := mload(0x100)
                y := add(y, shl(88, mload(0x120)))
                y := add(y, shl(176, mload(0x140)))
                mstore(2912, y)

                success := and(validate_ec_point(x, y), success)
            }
            {
                let x := mload(0x160)
                x := add(x, shl(88, mload(0x180)))
                x := add(x, shl(176, mload(0x1a0)))
                mstore(2944, x)
                let y := mload(0x1c0)
                y := add(y, shl(88, mload(0x1e0)))
                y := add(y, shl(176, mload(0x200)))
                mstore(2976, y)

                success := and(validate_ec_point(x, y), success)
            }
            mstore(0xbc0, mulmod(mload(0x700), mload(0x700), f_q))
            mstore(0xbe0, mulmod(mload(0xbc0), mload(0xbc0), f_q))
            mstore(0xc00, mulmod(mload(0xbe0), mload(0xbe0), f_q))
            mstore(0xc20, mulmod(mload(0xc00), mload(0xc00), f_q))
            mstore(0xc40, mulmod(mload(0xc20), mload(0xc20), f_q))
            mstore(0xc60, mulmod(mload(0xc40), mload(0xc40), f_q))
            mstore(0xc80, mulmod(mload(0xc60), mload(0xc60), f_q))
            mstore(0xca0, mulmod(mload(0xc80), mload(0xc80), f_q))
            mstore(0xcc0, mulmod(mload(0xca0), mload(0xca0), f_q))
            mstore(0xce0, mulmod(mload(0xcc0), mload(0xcc0), f_q))
            mstore(0xd00, mulmod(mload(0xce0), mload(0xce0), f_q))
            mstore(0xd20, mulmod(mload(0xd00), mload(0xd00), f_q))
            mstore(0xd40, mulmod(mload(0xd20), mload(0xd20), f_q))
            mstore(0xd60, mulmod(mload(0xd40), mload(0xd40), f_q))
            mstore(0xd80, mulmod(mload(0xd60), mload(0xd60), f_q))
            mstore(0xda0, mulmod(mload(0xd80), mload(0xd80), f_q))
            mstore(0xdc0, mulmod(mload(0xda0), mload(0xda0), f_q))
            mstore(0xde0, mulmod(mload(0xdc0), mload(0xdc0), f_q))
            mstore(0xe00, mulmod(mload(0xde0), mload(0xde0), f_q))
            mstore(0xe20, mulmod(mload(0xe00), mload(0xe00), f_q))
            mstore(0xe40, mulmod(mload(0xe20), mload(0xe20), f_q))
            mstore(0xe60, mulmod(mload(0xe40), mload(0xe40), f_q))
            mstore(0xe80, mulmod(mload(0xe60), mload(0xe60), f_q))
            mstore(
                0xea0,
                addmod(mload(0xe80), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q)
            )
            mstore(
                0xec0,
                mulmod(mload(0xea0), 21888240262557392955334514970720457388010314637169927192662615958087340972065, f_q)
            )
            mstore(
                0xee0,
                mulmod(mload(0xec0), 4506835738822104338668100540817374747935106310012997856968187171738630203507, f_q)
            )
            mstore(
                0xf00,
                addmod(mload(0x700), 17381407133017170883578305204439900340613258090403036486730017014837178292110, f_q)
            )
            mstore(
                0xf20,
                mulmod(mload(0xec0), 21710372849001950800533397158415938114909991150039389063546734567764856596059, f_q)
            )
            mstore(
                0xf40,
                addmod(mload(0x700), 177870022837324421713008586841336973638373250376645280151469618810951899558, f_q)
            )
            mstore(
                0xf60,
                mulmod(mload(0xec0), 1887003188133998471169152042388914354640772748308168868301418279904560637395, f_q)
            )
            mstore(
                0xf80,
                addmod(mload(0x700), 20001239683705276751077253702868360733907591652107865475396785906671247858222, f_q)
            )
            mstore(
                0xfa0,
                mulmod(mload(0xec0), 2785514556381676080176937710880804108647911392478702105860685610379369825016, f_q)
            )
            mstore(
                0xfc0,
                addmod(mload(0x700), 19102728315457599142069468034376470979900453007937332237837518576196438670601, f_q)
            )
            mstore(
                0xfe0,
                mulmod(mload(0xec0), 14655294445420895451632927078981340937842238432098198055057679026789553137428, f_q)
            )
            mstore(
                0x1000,
                addmod(mload(0x700), 7232948426418379770613478666275934150706125968317836288640525159786255358189, f_q)
            )
            mstore(
                0x1020,
                mulmod(mload(0xec0), 8734126352828345679573237859165904705806588461301144420590422589042130041188, f_q)
            )
            mstore(
                0x1040,
                addmod(mload(0x700), 13154116519010929542673167886091370382741775939114889923107781597533678454429, f_q)
            )
            mstore(
                0x1060,
                mulmod(mload(0xec0), 9741553891420464328295280489650144566903017206473301385034033384879943874347, f_q)
            )
            mstore(
                0x1080,
                addmod(mload(0x700), 12146688980418810893951125255607130521645347193942732958664170801695864621270, f_q)
            )
            mstore(0x10a0, mulmod(mload(0xec0), 1, f_q))
            mstore(
                0x10c0,
                addmod(mload(0x700), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q)
            )
            mstore(
                0x10e0,
                mulmod(mload(0xec0), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            mstore(
                0x1100,
                addmod(mload(0x700), 13513867906530865119835332133273263211836799082674232843258448413103731898270, f_q)
            )
            mstore(
                0x1120,
                mulmod(mload(0xec0), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q)
            )
            mstore(
                0x1140,
                addmod(mload(0x700), 10676941854703594198666993839846402519342119846958189386823924046696287912227, f_q)
            )
            mstore(
                0x1160,
                mulmod(mload(0xec0), 3615478808282855240548287271348143516886772452944084747768312988864436725401, f_q)
            )
            mstore(
                0x1180,
                addmod(mload(0x700), 18272764063556419981698118473909131571661591947471949595929891197711371770216, f_q)
            )
            mstore(
                0x11a0,
                mulmod(mload(0xec0), 1426404432721484388505361748317961535523355871255605456897797744433766488507, f_q)
            )
            mstore(
                0x11c0,
                addmod(mload(0x700), 20461838439117790833741043996939313553025008529160428886800406442142042007110, f_q)
            )
            mstore(
                0x11e0,
                mulmod(mload(0xec0), 216092043779272773661818549620449970334216366264741118684015851799902419467, f_q)
            )
            mstore(
                0x1200,
                addmod(mload(0x700), 21672150828060002448584587195636825118214148034151293225014188334775906076150, f_q)
            )
            mstore(
                0x1220,
                mulmod(mload(0xec0), 12619617507853212586156872920672483948819476989779550311307282715684870266992, f_q)
            )
            mstore(
                0x1240,
                addmod(mload(0x700), 9268625363986062636089532824584791139728887410636484032390921470890938228625, f_q)
            )
            mstore(
                0x1260,
                mulmod(mload(0xec0), 18610195890048912503953886742825279624920778288956610528523679659246523534888, f_q)
            )
            mstore(
                0x1280,
                addmod(mload(0x700), 3278046981790362718292519002431995463627586111459423815174524527329284960729, f_q)
            )
            mstore(
                0x12a0,
                mulmod(mload(0xec0), 19032961837237948602743626455740240236231119053033140765040043513661803148152, f_q)
            )
            mstore(
                0x12c0,
                addmod(mload(0x700), 2855281034601326619502779289517034852317245347382893578658160672914005347465, f_q)
            )
            mstore(
                0x12e0,
                mulmod(mload(0xec0), 14875928112196239563830800280253496262679717528621719058794366823499719730250, f_q)
            )
            mstore(
                0x1300,
                addmod(mload(0x700), 7012314759643035658415605465003778825868646871794315284903837363076088765367, f_q)
            )
            mstore(
                0x1320,
                mulmod(mload(0xec0), 915149353520972163646494413843788069594022902357002628455555785223409501882, f_q)
            )
            mstore(
                0x1340,
                addmod(mload(0x700), 20973093518318303058599911331413487018954341498059031715242648401352398993735, f_q)
            )
            mstore(
                0x1360,
                mulmod(mload(0xec0), 5522161504810533295870699551020523636289972223872138525048055197429246400245, f_q)
            )
            mstore(
                0x1380,
                addmod(mload(0x700), 16366081367028741926375706194236751452258392176543895818650148989146562095372, f_q)
            )
            mstore(
                0x13a0,
                mulmod(mload(0xec0), 3766081621734395783232337525162072736827576297943013392955872170138036189193, f_q)
            )
            mstore(
                0x13c0,
                addmod(mload(0x700), 18122161250104879439014068220095202351720788102473020950742332016437772306424, f_q)
            )
            mstore(
                0x13e0,
                mulmod(mload(0xec0), 9100833993744738801214480881117348002768153232283708533639316963648253510584, f_q)
            )
            mstore(
                0x1400,
                addmod(mload(0x700), 12787408878094536421031924864139927085780211168132325810058887222927554985033, f_q)
            )
            mstore(
                0x1420,
                mulmod(mload(0xec0), 4245441013247250116003069945606352967193023389718465410501109428393342802981, f_q)
            )
            mstore(
                0x1440,
                addmod(mload(0x700), 17642801858592025106243335799650922121355341010697568933197094758182465692636, f_q)
            )
            mstore(
                0x1460,
                mulmod(mload(0xec0), 6132660129994545119218258312491950835441607143741804980633129304664017206141, f_q)
            )
            mstore(
                0x1480,
                addmod(mload(0x700), 15755582741844730103028147432765324253106757256674229363065074881911791289476, f_q)
            )
            mstore(
                0x14a0,
                mulmod(mload(0xec0), 5854133144571823792863860130267644613802765696134002830362054821530146160770, f_q)
            )
            mstore(
                0x14c0,
                addmod(mload(0x700), 16034109727267451429382545614989630474745598704282031513336149365045662334847, f_q)
            )
            mstore(
                0x14e0,
                mulmod(mload(0xec0), 515148244606945972463850631189471072103916690263705052318085725998468254533, f_q)
            )
            mstore(
                0x1500,
                addmod(mload(0x700), 21373094627232329249782555114067804016444447710152329291380118460577340241084, f_q)
            )
            {
                let prod := mload(0xf00)

                prod := mulmod(mload(0xf40), prod, f_q)
                mstore(0x1520, prod)

                prod := mulmod(mload(0xf80), prod, f_q)
                mstore(0x1540, prod)

                prod := mulmod(mload(0xfc0), prod, f_q)
                mstore(0x1560, prod)

                prod := mulmod(mload(0x1000), prod, f_q)
                mstore(0x1580, prod)

                prod := mulmod(mload(0x1040), prod, f_q)
                mstore(0x15a0, prod)

                prod := mulmod(mload(0x1080), prod, f_q)
                mstore(0x15c0, prod)

                prod := mulmod(mload(0x10c0), prod, f_q)
                mstore(0x15e0, prod)

                prod := mulmod(mload(0x1100), prod, f_q)
                mstore(0x1600, prod)

                prod := mulmod(mload(0x1140), prod, f_q)
                mstore(0x1620, prod)

                prod := mulmod(mload(0x1180), prod, f_q)
                mstore(0x1640, prod)

                prod := mulmod(mload(0x11c0), prod, f_q)
                mstore(0x1660, prod)

                prod := mulmod(mload(0x1200), prod, f_q)
                mstore(0x1680, prod)

                prod := mulmod(mload(0x1240), prod, f_q)
                mstore(0x16a0, prod)

                prod := mulmod(mload(0x1280), prod, f_q)
                mstore(0x16c0, prod)

                prod := mulmod(mload(0x12c0), prod, f_q)
                mstore(0x16e0, prod)

                prod := mulmod(mload(0x1300), prod, f_q)
                mstore(0x1700, prod)

                prod := mulmod(mload(0x1340), prod, f_q)
                mstore(0x1720, prod)

                prod := mulmod(mload(0x1380), prod, f_q)
                mstore(0x1740, prod)

                prod := mulmod(mload(0x13c0), prod, f_q)
                mstore(0x1760, prod)

                prod := mulmod(mload(0x1400), prod, f_q)
                mstore(0x1780, prod)

                prod := mulmod(mload(0x1440), prod, f_q)
                mstore(0x17a0, prod)

                prod := mulmod(mload(0x1480), prod, f_q)
                mstore(0x17c0, prod)

                prod := mulmod(mload(0x14c0), prod, f_q)
                mstore(0x17e0, prod)

                prod := mulmod(mload(0x1500), prod, f_q)
                mstore(0x1800, prod)

                prod := mulmod(mload(0xea0), prod, f_q)
                mstore(0x1820, prod)
            }
            mstore(0x1860, 32)
            mstore(0x1880, 32)
            mstore(0x18a0, 32)
            mstore(0x18c0, mload(0x1820))
            mstore(0x18e0, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x1900, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x1860, 0xc0, 0x1840, 0x20), 1), success)
            {
                let inv := mload(0x1840)
                let v

                v := mload(0xea0)
                mstore(3744, mulmod(mload(0x1800), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1500)
                mstore(5376, mulmod(mload(0x17e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x14c0)
                mstore(5312, mulmod(mload(0x17c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1480)
                mstore(5248, mulmod(mload(0x17a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1440)
                mstore(5184, mulmod(mload(0x1780), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1400)
                mstore(5120, mulmod(mload(0x1760), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x13c0)
                mstore(5056, mulmod(mload(0x1740), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1380)
                mstore(4992, mulmod(mload(0x1720), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1340)
                mstore(4928, mulmod(mload(0x1700), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1300)
                mstore(4864, mulmod(mload(0x16e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x12c0)
                mstore(4800, mulmod(mload(0x16c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1280)
                mstore(4736, mulmod(mload(0x16a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1240)
                mstore(4672, mulmod(mload(0x1680), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1200)
                mstore(4608, mulmod(mload(0x1660), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x11c0)
                mstore(4544, mulmod(mload(0x1640), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1180)
                mstore(4480, mulmod(mload(0x1620), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1140)
                mstore(4416, mulmod(mload(0x1600), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1100)
                mstore(4352, mulmod(mload(0x15e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x10c0)
                mstore(4288, mulmod(mload(0x15c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1080)
                mstore(4224, mulmod(mload(0x15a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1040)
                mstore(4160, mulmod(mload(0x1580), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1000)
                mstore(4096, mulmod(mload(0x1560), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xfc0)
                mstore(4032, mulmod(mload(0x1540), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xf80)
                mstore(3968, mulmod(mload(0x1520), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xf40)
                mstore(3904, mulmod(mload(0xf00), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0xf00, inv)
            }
            mstore(0x1920, mulmod(mload(0xee0), mload(0xf00), f_q))
            mstore(0x1940, mulmod(mload(0xf20), mload(0xf40), f_q))
            mstore(0x1960, mulmod(mload(0xf60), mload(0xf80), f_q))
            mstore(0x1980, mulmod(mload(0xfa0), mload(0xfc0), f_q))
            mstore(0x19a0, mulmod(mload(0xfe0), mload(0x1000), f_q))
            mstore(0x19c0, mulmod(mload(0x1020), mload(0x1040), f_q))
            mstore(0x19e0, mulmod(mload(0x1060), mload(0x1080), f_q))
            mstore(0x1a00, mulmod(mload(0x10a0), mload(0x10c0), f_q))
            mstore(0x1a20, mulmod(mload(0x10e0), mload(0x1100), f_q))
            mstore(0x1a40, mulmod(mload(0x1120), mload(0x1140), f_q))
            mstore(0x1a60, mulmod(mload(0x1160), mload(0x1180), f_q))
            mstore(0x1a80, mulmod(mload(0x11a0), mload(0x11c0), f_q))
            mstore(0x1aa0, mulmod(mload(0x11e0), mload(0x1200), f_q))
            mstore(0x1ac0, mulmod(mload(0x1220), mload(0x1240), f_q))
            mstore(0x1ae0, mulmod(mload(0x1260), mload(0x1280), f_q))
            mstore(0x1b00, mulmod(mload(0x12a0), mload(0x12c0), f_q))
            mstore(0x1b20, mulmod(mload(0x12e0), mload(0x1300), f_q))
            mstore(0x1b40, mulmod(mload(0x1320), mload(0x1340), f_q))
            mstore(0x1b60, mulmod(mload(0x1360), mload(0x1380), f_q))
            mstore(0x1b80, mulmod(mload(0x13a0), mload(0x13c0), f_q))
            mstore(0x1ba0, mulmod(mload(0x13e0), mload(0x1400), f_q))
            mstore(0x1bc0, mulmod(mload(0x1420), mload(0x1440), f_q))
            mstore(0x1be0, mulmod(mload(0x1460), mload(0x1480), f_q))
            mstore(0x1c00, mulmod(mload(0x14a0), mload(0x14c0), f_q))
            mstore(0x1c20, mulmod(mload(0x14e0), mload(0x1500), f_q))
            {
                let result := mulmod(mload(0x1a00), mload(0xa0), f_q)
                result := addmod(mulmod(mload(0x1a20), mload(0xc0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1a40), mload(0xe0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1a60), mload(0x100), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1a80), mload(0x120), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1aa0), mload(0x140), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1ac0), mload(0x160), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1ae0), mload(0x180), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1b00), mload(0x1a0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1b20), mload(0x1c0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1b40), mload(0x1e0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1b60), mload(0x200), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1b80), mload(0x220), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1ba0), mload(0x240), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1bc0), mload(0x260), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1be0), mload(0x280), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1c00), mload(0x2a0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1c20), mload(0x2c0), f_q), result, f_q)
                mstore(7232, result)
            }
            mstore(0x1c60, mulmod(mload(0x780), mload(0x760), f_q))
            mstore(0x1c80, addmod(mload(0x740), mload(0x1c60), f_q))
            mstore(0x1ca0, addmod(mload(0x1c80), sub(f_q, mload(0x7a0)), f_q))
            mstore(0x1cc0, mulmod(mload(0x1ca0), mload(0x800), f_q))
            mstore(0x1ce0, mulmod(mload(0x5a0), mload(0x1cc0), f_q))
            mstore(0x1d00, addmod(1, sub(f_q, mload(0x8c0)), f_q))
            mstore(0x1d20, mulmod(mload(0x1d00), mload(0x1a00), f_q))
            mstore(0x1d40, addmod(mload(0x1ce0), mload(0x1d20), f_q))
            mstore(0x1d60, mulmod(mload(0x5a0), mload(0x1d40), f_q))
            mstore(0x1d80, mulmod(mload(0x8c0), mload(0x8c0), f_q))
            mstore(0x1da0, addmod(mload(0x1d80), sub(f_q, mload(0x8c0)), f_q))
            mstore(0x1dc0, mulmod(mload(0x1da0), mload(0x1920), f_q))
            mstore(0x1de0, addmod(mload(0x1d60), mload(0x1dc0), f_q))
            mstore(0x1e00, mulmod(mload(0x5a0), mload(0x1de0), f_q))
            mstore(0x1e20, addmod(1, sub(f_q, mload(0x1920)), f_q))
            mstore(0x1e40, addmod(mload(0x1940), mload(0x1960), f_q))
            mstore(0x1e60, addmod(mload(0x1e40), mload(0x1980), f_q))
            mstore(0x1e80, addmod(mload(0x1e60), mload(0x19a0), f_q))
            mstore(0x1ea0, addmod(mload(0x1e80), mload(0x19c0), f_q))
            mstore(0x1ec0, addmod(mload(0x1ea0), mload(0x19e0), f_q))
            mstore(0x1ee0, addmod(mload(0x1e20), sub(f_q, mload(0x1ec0)), f_q))
            mstore(0x1f00, mulmod(mload(0x860), mload(0x420), f_q))
            mstore(0x1f20, addmod(mload(0x7c0), mload(0x1f00), f_q))
            mstore(0x1f40, addmod(mload(0x1f20), mload(0x480), f_q))
            mstore(0x1f60, mulmod(mload(0x880), mload(0x420), f_q))
            mstore(0x1f80, addmod(mload(0x740), mload(0x1f60), f_q))
            mstore(0x1fa0, addmod(mload(0x1f80), mload(0x480), f_q))
            mstore(0x1fc0, mulmod(mload(0x1fa0), mload(0x1f40), f_q))
            mstore(0x1fe0, mulmod(mload(0x8a0), mload(0x420), f_q))
            mstore(0x2000, addmod(mload(0x1c40), mload(0x1fe0), f_q))
            mstore(0x2020, addmod(mload(0x2000), mload(0x480), f_q))
            mstore(0x2040, mulmod(mload(0x2020), mload(0x1fc0), f_q))
            mstore(0x2060, mulmod(mload(0x2040), mload(0x8e0), f_q))
            mstore(0x2080, mulmod(1, mload(0x420), f_q))
            mstore(0x20a0, mulmod(mload(0x700), mload(0x2080), f_q))
            mstore(0x20c0, addmod(mload(0x7c0), mload(0x20a0), f_q))
            mstore(0x20e0, addmod(mload(0x20c0), mload(0x480), f_q))
            mstore(
                0x2100,
                mulmod(4131629893567559867359510883348571134090853742863529169391034518566172092834, mload(0x420), f_q)
            )
            mstore(0x2120, mulmod(mload(0x700), mload(0x2100), f_q))
            mstore(0x2140, addmod(mload(0x740), mload(0x2120), f_q))
            mstore(0x2160, addmod(mload(0x2140), mload(0x480), f_q))
            mstore(0x2180, mulmod(mload(0x2160), mload(0x20e0), f_q))
            mstore(
                0x21a0,
                mulmod(8910878055287538404433155982483128285667088683464058436815641868457422632747, mload(0x420), f_q)
            )
            mstore(0x21c0, mulmod(mload(0x700), mload(0x21a0), f_q))
            mstore(0x21e0, addmod(mload(0x1c40), mload(0x21c0), f_q))
            mstore(0x2200, addmod(mload(0x21e0), mload(0x480), f_q))
            mstore(0x2220, mulmod(mload(0x2200), mload(0x2180), f_q))
            mstore(0x2240, mulmod(mload(0x2220), mload(0x8c0), f_q))
            mstore(0x2260, addmod(mload(0x2060), sub(f_q, mload(0x2240)), f_q))
            mstore(0x2280, mulmod(mload(0x2260), mload(0x1ee0), f_q))
            mstore(0x22a0, addmod(mload(0x1e00), mload(0x2280), f_q))
            mstore(0x22c0, mulmod(mload(0x5a0), mload(0x22a0), f_q))
            mstore(0x22e0, addmod(1, sub(f_q, mload(0x900)), f_q))
            mstore(0x2300, mulmod(mload(0x22e0), mload(0x1a00), f_q))
            mstore(0x2320, addmod(mload(0x22c0), mload(0x2300), f_q))
            mstore(0x2340, mulmod(mload(0x5a0), mload(0x2320), f_q))
            mstore(0x2360, mulmod(mload(0x900), mload(0x900), f_q))
            mstore(0x2380, addmod(mload(0x2360), sub(f_q, mload(0x900)), f_q))
            mstore(0x23a0, mulmod(mload(0x2380), mload(0x1920), f_q))
            mstore(0x23c0, addmod(mload(0x2340), mload(0x23a0), f_q))
            mstore(0x23e0, mulmod(mload(0x5a0), mload(0x23c0), f_q))
            mstore(0x2400, addmod(mload(0x940), mload(0x420), f_q))
            mstore(0x2420, mulmod(mload(0x2400), mload(0x920), f_q))
            mstore(0x2440, addmod(mload(0x980), mload(0x480), f_q))
            mstore(0x2460, mulmod(mload(0x2440), mload(0x2420), f_q))
            mstore(0x2480, mulmod(mload(0x740), mload(0x820), f_q))
            mstore(0x24a0, addmod(mload(0x2480), mload(0x420), f_q))
            mstore(0x24c0, mulmod(mload(0x24a0), mload(0x900), f_q))
            mstore(0x24e0, addmod(mload(0x7e0), mload(0x480), f_q))
            mstore(0x2500, mulmod(mload(0x24e0), mload(0x24c0), f_q))
            mstore(0x2520, addmod(mload(0x2460), sub(f_q, mload(0x2500)), f_q))
            mstore(0x2540, mulmod(mload(0x2520), mload(0x1ee0), f_q))
            mstore(0x2560, addmod(mload(0x23e0), mload(0x2540), f_q))
            mstore(0x2580, mulmod(mload(0x5a0), mload(0x2560), f_q))
            mstore(0x25a0, addmod(mload(0x940), sub(f_q, mload(0x980)), f_q))
            mstore(0x25c0, mulmod(mload(0x25a0), mload(0x1a00), f_q))
            mstore(0x25e0, addmod(mload(0x2580), mload(0x25c0), f_q))
            mstore(0x2600, mulmod(mload(0x5a0), mload(0x25e0), f_q))
            mstore(0x2620, mulmod(mload(0x25a0), mload(0x1ee0), f_q))
            mstore(0x2640, addmod(mload(0x940), sub(f_q, mload(0x960)), f_q))
            mstore(0x2660, mulmod(mload(0x2640), mload(0x2620), f_q))
            mstore(0x2680, addmod(mload(0x2600), mload(0x2660), f_q))
            mstore(0x26a0, mulmod(mload(0xe80), mload(0xe80), f_q))
            mstore(0x26c0, mulmod(mload(0x26a0), mload(0xe80), f_q))
            mstore(0x26e0, mulmod(mload(0x26c0), mload(0xe80), f_q))
            mstore(0x2700, mulmod(1, mload(0xe80), f_q))
            mstore(0x2720, mulmod(1, mload(0x26a0), f_q))
            mstore(0x2740, mulmod(1, mload(0x26c0), f_q))
            mstore(0x2760, mulmod(mload(0x2680), mload(0xea0), f_q))
            mstore(0x2780, mulmod(mload(0xbc0), mload(0x700), f_q))
            mstore(0x27a0, mulmod(mload(0x2780), mload(0x700), f_q))
            mstore(
                0x27c0,
                mulmod(mload(0x700), 9741553891420464328295280489650144566903017206473301385034033384879943874347, f_q)
            )
            mstore(0x27e0, addmod(mload(0xac0), sub(f_q, mload(0x27c0)), f_q))
            mstore(0x2800, mulmod(mload(0x700), 1, f_q))
            mstore(0x2820, addmod(mload(0xac0), sub(f_q, mload(0x2800)), f_q))
            mstore(
                0x2840,
                mulmod(mload(0x700), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            mstore(0x2860, addmod(mload(0xac0), sub(f_q, mload(0x2840)), f_q))
            mstore(
                0x2880,
                mulmod(mload(0x700), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q)
            )
            mstore(0x28a0, addmod(mload(0xac0), sub(f_q, mload(0x2880)), f_q))
            mstore(
                0x28c0,
                mulmod(mload(0x700), 3615478808282855240548287271348143516886772452944084747768312988864436725401, f_q)
            )
            mstore(0x28e0, addmod(mload(0xac0), sub(f_q, mload(0x28c0)), f_q))
            mstore(
                0x2900,
                mulmod(
                    13213688729882003894512633350385593288217014177373218494356903340348818451480, mload(0x2780), f_q
                )
            )
            mstore(0x2920, mulmod(mload(0x2900), 1, f_q))
            {
                let result := mulmod(mload(0xac0), mload(0x2900), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2920)), f_q), result, f_q)
                mstore(10560, result)
            }
            mstore(
                0x2960,
                mulmod(8207090019724696496350398458716998472718344609680392612601596849934418295470, mload(0x2780), f_q)
            )
            mstore(
                0x2980,
                mulmod(mload(0x2960), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            {
                let result := mulmod(mload(0xac0), mload(0x2960), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2980)), f_q), result, f_q)
                mstore(10656, result)
            }
            mstore(
                0x29c0,
                mulmod(7391709068497399131897422873231908718558236401035363928063603272120120747483, mload(0x2780), f_q)
            )
            mstore(
                0x29e0,
                mulmod(
                    mload(0x29c0), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q
                )
            )
            {
                let result := mulmod(mload(0xac0), mload(0x29c0), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x29e0)), f_q), result, f_q)
                mstore(10752, result)
            }
            mstore(
                0x2a20,
                mulmod(
                    19036273796805830823244991598792794567595348772040298280440552631112242221017, mload(0x2780), f_q
                )
            )
            mstore(
                0x2a40,
                mulmod(mload(0x2a20), 3615478808282855240548287271348143516886772452944084747768312988864436725401, f_q)
            )
            {
                let result := mulmod(mload(0xac0), mload(0x2a20), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2a40)), f_q), result, f_q)
                mstore(10848, result)
            }
            mstore(0x2a80, mulmod(1, mload(0x2820), f_q))
            mstore(0x2aa0, mulmod(mload(0x2a80), mload(0x2860), f_q))
            mstore(0x2ac0, mulmod(mload(0x2aa0), mload(0x28a0), f_q))
            mstore(0x2ae0, mulmod(mload(0x2ac0), mload(0x28e0), f_q))
            mstore(
                0x2b00,
                mulmod(13513867906530865119835332133273263211836799082674232843258448413103731898271, mload(0x700), f_q)
            )
            mstore(0x2b20, mulmod(mload(0x2b00), 1, f_q))
            {
                let result := mulmod(mload(0xac0), mload(0x2b00), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2b20)), f_q), result, f_q)
                mstore(11072, result)
            }
            mstore(
                0x2b60,
                mulmod(8374374965308410102411073611984011876711565317741801500439755773472076597346, mload(0x700), f_q)
            )
            mstore(
                0x2b80,
                mulmod(mload(0x2b60), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            {
                let result := mulmod(mload(0xac0), mload(0x2b60), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2b80)), f_q), result, f_q)
                mstore(11168, result)
            }
            mstore(
                0x2bc0,
                mulmod(12146688980418810893951125255607130521645347193942732958664170801695864621271, mload(0x700), f_q)
            )
            mstore(0x2be0, mulmod(mload(0x2bc0), 1, f_q))
            {
                let result := mulmod(mload(0xac0), mload(0x2bc0), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2be0)), f_q), result, f_q)
                mstore(11264, result)
            }
            mstore(
                0x2c20,
                mulmod(9741553891420464328295280489650144566903017206473301385034033384879943874346, mload(0x700), f_q)
            )
            mstore(
                0x2c40,
                mulmod(mload(0x2c20), 9741553891420464328295280489650144566903017206473301385034033384879943874347, f_q)
            )
            {
                let result := mulmod(mload(0xac0), mload(0x2c20), f_q)
                result := addmod(mulmod(mload(0x700), sub(f_q, mload(0x2c40)), f_q), result, f_q)
                mstore(11360, result)
            }
            mstore(0x2c80, mulmod(mload(0x2a80), mload(0x27e0), f_q))
            {
                let result := mulmod(mload(0xac0), 1, f_q)
                result :=
                    addmod(
                        mulmod(
                            mload(0x700), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q
                        ),
                        result,
                        f_q
                    )
                mstore(11424, result)
            }
            {
                let prod := mload(0x2940)

                prod := mulmod(mload(0x29a0), prod, f_q)
                mstore(0x2cc0, prod)

                prod := mulmod(mload(0x2a00), prod, f_q)
                mstore(0x2ce0, prod)

                prod := mulmod(mload(0x2a60), prod, f_q)
                mstore(0x2d00, prod)

                prod := mulmod(mload(0x2b40), prod, f_q)
                mstore(0x2d20, prod)

                prod := mulmod(mload(0x2ba0), prod, f_q)
                mstore(0x2d40, prod)

                prod := mulmod(mload(0x2aa0), prod, f_q)
                mstore(0x2d60, prod)

                prod := mulmod(mload(0x2c00), prod, f_q)
                mstore(0x2d80, prod)

                prod := mulmod(mload(0x2c60), prod, f_q)
                mstore(0x2da0, prod)

                prod := mulmod(mload(0x2c80), prod, f_q)
                mstore(0x2dc0, prod)

                prod := mulmod(mload(0x2ca0), prod, f_q)
                mstore(0x2de0, prod)

                prod := mulmod(mload(0x2a80), prod, f_q)
                mstore(0x2e00, prod)
            }
            mstore(0x2e40, 32)
            mstore(0x2e60, 32)
            mstore(0x2e80, 32)
            mstore(0x2ea0, mload(0x2e00))
            mstore(0x2ec0, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x2ee0, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x2e40, 0xc0, 0x2e20, 0x20), 1), success)
            {
                let inv := mload(0x2e20)
                let v

                v := mload(0x2a80)
                mstore(10880, mulmod(mload(0x2de0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2ca0)
                mstore(11424, mulmod(mload(0x2dc0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2c80)
                mstore(11392, mulmod(mload(0x2da0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2c60)
                mstore(11360, mulmod(mload(0x2d80), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2c00)
                mstore(11264, mulmod(mload(0x2d60), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2aa0)
                mstore(10912, mulmod(mload(0x2d40), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2ba0)
                mstore(11168, mulmod(mload(0x2d20), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2b40)
                mstore(11072, mulmod(mload(0x2d00), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2a60)
                mstore(10848, mulmod(mload(0x2ce0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2a00)
                mstore(10752, mulmod(mload(0x2cc0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x29a0)
                mstore(10656, mulmod(mload(0x2940), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0x2940, inv)
            }
            {
                let result := mload(0x2940)
                result := addmod(mload(0x29a0), result, f_q)
                result := addmod(mload(0x2a00), result, f_q)
                result := addmod(mload(0x2a60), result, f_q)
                mstore(12032, result)
            }
            mstore(0x2f20, mulmod(mload(0x2ae0), mload(0x2aa0), f_q))
            {
                let result := mload(0x2b40)
                result := addmod(mload(0x2ba0), result, f_q)
                mstore(12096, result)
            }
            mstore(0x2f60, mulmod(mload(0x2ae0), mload(0x2c80), f_q))
            {
                let result := mload(0x2c00)
                result := addmod(mload(0x2c60), result, f_q)
                mstore(12160, result)
            }
            mstore(0x2fa0, mulmod(mload(0x2ae0), mload(0x2a80), f_q))
            {
                let result := mload(0x2ca0)
                mstore(12224, result)
            }
            {
                let prod := mload(0x2f00)

                prod := mulmod(mload(0x2f40), prod, f_q)
                mstore(0x2fe0, prod)

                prod := mulmod(mload(0x2f80), prod, f_q)
                mstore(0x3000, prod)

                prod := mulmod(mload(0x2fc0), prod, f_q)
                mstore(0x3020, prod)
            }
            mstore(0x3060, 32)
            mstore(0x3080, 32)
            mstore(0x30a0, 32)
            mstore(0x30c0, mload(0x3020))
            mstore(0x30e0, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x3100, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x3060, 0xc0, 0x3040, 0x20), 1), success)
            {
                let inv := mload(0x3040)
                let v

                v := mload(0x2fc0)
                mstore(12224, mulmod(mload(0x3000), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2f80)
                mstore(12160, mulmod(mload(0x2fe0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2f40)
                mstore(12096, mulmod(mload(0x2f00), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0x2f00, inv)
            }
            mstore(0x3120, mulmod(mload(0x2f20), mload(0x2f40), f_q))
            mstore(0x3140, mulmod(mload(0x2f60), mload(0x2f80), f_q))
            mstore(0x3160, mulmod(mload(0x2fa0), mload(0x2fc0), f_q))
            mstore(0x3180, mulmod(mload(0x9c0), mload(0x9c0), f_q))
            mstore(0x31a0, mulmod(mload(0x3180), mload(0x9c0), f_q))
            mstore(0x31c0, mulmod(mload(0x31a0), mload(0x9c0), f_q))
            mstore(0x31e0, mulmod(mload(0x31c0), mload(0x9c0), f_q))
            mstore(0x3200, mulmod(mload(0x31e0), mload(0x9c0), f_q))
            mstore(0x3220, mulmod(mload(0x3200), mload(0x9c0), f_q))
            mstore(0x3240, mulmod(mload(0x3220), mload(0x9c0), f_q))
            mstore(0x3260, mulmod(mload(0x3240), mload(0x9c0), f_q))
            mstore(0x3280, mulmod(mload(0x3260), mload(0x9c0), f_q))
            mstore(0x32a0, mulmod(mload(0xa20), mload(0xa20), f_q))
            mstore(0x32c0, mulmod(mload(0x32a0), mload(0xa20), f_q))
            mstore(0x32e0, mulmod(mload(0x32c0), mload(0xa20), f_q))
            {
                let result := mulmod(mload(0x740), mload(0x2940), f_q)
                result := addmod(mulmod(mload(0x760), mload(0x29a0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x780), mload(0x2a00), f_q), result, f_q)
                result := addmod(mulmod(mload(0x7a0), mload(0x2a60), f_q), result, f_q)
                mstore(13056, result)
            }
            mstore(0x3320, mulmod(mload(0x3300), mload(0x2f00), f_q))
            mstore(0x3340, mulmod(sub(f_q, mload(0x3320)), 1, f_q))
            mstore(0x3360, mulmod(mload(0x3340), 1, f_q))
            mstore(0x3380, mulmod(1, mload(0x2f20), f_q))
            {
                let result := mulmod(mload(0x8c0), mload(0x2b40), f_q)
                result := addmod(mulmod(mload(0x8e0), mload(0x2ba0), f_q), result, f_q)
                mstore(13216, result)
            }
            mstore(0x33c0, mulmod(mload(0x33a0), mload(0x3120), f_q))
            mstore(0x33e0, mulmod(sub(f_q, mload(0x33c0)), 1, f_q))
            mstore(0x3400, mulmod(mload(0x3380), 1, f_q))
            {
                let result := mulmod(mload(0x900), mload(0x2b40), f_q)
                result := addmod(mulmod(mload(0x920), mload(0x2ba0), f_q), result, f_q)
                mstore(13344, result)
            }
            mstore(0x3440, mulmod(mload(0x3420), mload(0x3120), f_q))
            mstore(0x3460, mulmod(sub(f_q, mload(0x3440)), mload(0x9c0), f_q))
            mstore(0x3480, mulmod(mload(0x3380), mload(0x9c0), f_q))
            mstore(0x34a0, addmod(mload(0x33e0), mload(0x3460), f_q))
            mstore(0x34c0, mulmod(mload(0x34a0), mload(0xa20), f_q))
            mstore(0x34e0, mulmod(mload(0x3400), mload(0xa20), f_q))
            mstore(0x3500, mulmod(mload(0x3480), mload(0xa20), f_q))
            mstore(0x3520, addmod(mload(0x3360), mload(0x34c0), f_q))
            mstore(0x3540, mulmod(1, mload(0x2f60), f_q))
            {
                let result := mulmod(mload(0x940), mload(0x2c00), f_q)
                result := addmod(mulmod(mload(0x960), mload(0x2c60), f_q), result, f_q)
                mstore(13664, result)
            }
            mstore(0x3580, mulmod(mload(0x3560), mload(0x3140), f_q))
            mstore(0x35a0, mulmod(sub(f_q, mload(0x3580)), 1, f_q))
            mstore(0x35c0, mulmod(mload(0x3540), 1, f_q))
            mstore(0x35e0, mulmod(mload(0x35a0), mload(0x32a0), f_q))
            mstore(0x3600, mulmod(mload(0x35c0), mload(0x32a0), f_q))
            mstore(0x3620, addmod(mload(0x3520), mload(0x35e0), f_q))
            mstore(0x3640, mulmod(1, mload(0x2fa0), f_q))
            {
                let result := mulmod(mload(0x980), mload(0x2ca0), f_q)
                mstore(13920, result)
            }
            mstore(0x3680, mulmod(mload(0x3660), mload(0x3160), f_q))
            mstore(0x36a0, mulmod(sub(f_q, mload(0x3680)), 1, f_q))
            mstore(0x36c0, mulmod(mload(0x3640), 1, f_q))
            {
                let result := mulmod(mload(0x7c0), mload(0x2ca0), f_q)
                mstore(14048, result)
            }
            mstore(0x3700, mulmod(mload(0x36e0), mload(0x3160), f_q))
            mstore(0x3720, mulmod(sub(f_q, mload(0x3700)), mload(0x9c0), f_q))
            mstore(0x3740, mulmod(mload(0x3640), mload(0x9c0), f_q))
            mstore(0x3760, addmod(mload(0x36a0), mload(0x3720), f_q))
            {
                let result := mulmod(mload(0x7e0), mload(0x2ca0), f_q)
                mstore(14208, result)
            }
            mstore(0x37a0, mulmod(mload(0x3780), mload(0x3160), f_q))
            mstore(0x37c0, mulmod(sub(f_q, mload(0x37a0)), mload(0x3180), f_q))
            mstore(0x37e0, mulmod(mload(0x3640), mload(0x3180), f_q))
            mstore(0x3800, addmod(mload(0x3760), mload(0x37c0), f_q))
            {
                let result := mulmod(mload(0x800), mload(0x2ca0), f_q)
                mstore(14368, result)
            }
            mstore(0x3840, mulmod(mload(0x3820), mload(0x3160), f_q))
            mstore(0x3860, mulmod(sub(f_q, mload(0x3840)), mload(0x31a0), f_q))
            mstore(0x3880, mulmod(mload(0x3640), mload(0x31a0), f_q))
            mstore(0x38a0, addmod(mload(0x3800), mload(0x3860), f_q))
            {
                let result := mulmod(mload(0x820), mload(0x2ca0), f_q)
                mstore(14528, result)
            }
            mstore(0x38e0, mulmod(mload(0x38c0), mload(0x3160), f_q))
            mstore(0x3900, mulmod(sub(f_q, mload(0x38e0)), mload(0x31c0), f_q))
            mstore(0x3920, mulmod(mload(0x3640), mload(0x31c0), f_q))
            mstore(0x3940, addmod(mload(0x38a0), mload(0x3900), f_q))
            {
                let result := mulmod(mload(0x860), mload(0x2ca0), f_q)
                mstore(14688, result)
            }
            mstore(0x3980, mulmod(mload(0x3960), mload(0x3160), f_q))
            mstore(0x39a0, mulmod(sub(f_q, mload(0x3980)), mload(0x31e0), f_q))
            mstore(0x39c0, mulmod(mload(0x3640), mload(0x31e0), f_q))
            mstore(0x39e0, addmod(mload(0x3940), mload(0x39a0), f_q))
            {
                let result := mulmod(mload(0x880), mload(0x2ca0), f_q)
                mstore(14848, result)
            }
            mstore(0x3a20, mulmod(mload(0x3a00), mload(0x3160), f_q))
            mstore(0x3a40, mulmod(sub(f_q, mload(0x3a20)), mload(0x3200), f_q))
            mstore(0x3a60, mulmod(mload(0x3640), mload(0x3200), f_q))
            mstore(0x3a80, addmod(mload(0x39e0), mload(0x3a40), f_q))
            {
                let result := mulmod(mload(0x8a0), mload(0x2ca0), f_q)
                mstore(15008, result)
            }
            mstore(0x3ac0, mulmod(mload(0x3aa0), mload(0x3160), f_q))
            mstore(0x3ae0, mulmod(sub(f_q, mload(0x3ac0)), mload(0x3220), f_q))
            mstore(0x3b00, mulmod(mload(0x3640), mload(0x3220), f_q))
            mstore(0x3b20, addmod(mload(0x3a80), mload(0x3ae0), f_q))
            mstore(0x3b40, mulmod(mload(0x2700), mload(0x2fa0), f_q))
            mstore(0x3b60, mulmod(mload(0x2720), mload(0x2fa0), f_q))
            mstore(0x3b80, mulmod(mload(0x2740), mload(0x2fa0), f_q))
            {
                let result := mulmod(mload(0x2760), mload(0x2ca0), f_q)
                mstore(15264, result)
            }
            mstore(0x3bc0, mulmod(mload(0x3ba0), mload(0x3160), f_q))
            mstore(0x3be0, mulmod(sub(f_q, mload(0x3bc0)), mload(0x3240), f_q))
            mstore(0x3c00, mulmod(mload(0x3640), mload(0x3240), f_q))
            mstore(0x3c20, mulmod(mload(0x3b40), mload(0x3240), f_q))
            mstore(0x3c40, mulmod(mload(0x3b60), mload(0x3240), f_q))
            mstore(0x3c60, mulmod(mload(0x3b80), mload(0x3240), f_q))
            mstore(0x3c80, addmod(mload(0x3b20), mload(0x3be0), f_q))
            {
                let result := mulmod(mload(0x840), mload(0x2ca0), f_q)
                mstore(15520, result)
            }
            mstore(0x3cc0, mulmod(mload(0x3ca0), mload(0x3160), f_q))
            mstore(0x3ce0, mulmod(sub(f_q, mload(0x3cc0)), mload(0x3260), f_q))
            mstore(0x3d00, mulmod(mload(0x3640), mload(0x3260), f_q))
            mstore(0x3d20, addmod(mload(0x3c80), mload(0x3ce0), f_q))
            mstore(0x3d40, mulmod(mload(0x3d20), mload(0x32c0), f_q))
            mstore(0x3d60, mulmod(mload(0x36c0), mload(0x32c0), f_q))
            mstore(0x3d80, mulmod(mload(0x3740), mload(0x32c0), f_q))
            mstore(0x3da0, mulmod(mload(0x37e0), mload(0x32c0), f_q))
            mstore(0x3dc0, mulmod(mload(0x3880), mload(0x32c0), f_q))
            mstore(0x3de0, mulmod(mload(0x3920), mload(0x32c0), f_q))
            mstore(0x3e00, mulmod(mload(0x39c0), mload(0x32c0), f_q))
            mstore(0x3e20, mulmod(mload(0x3a60), mload(0x32c0), f_q))
            mstore(0x3e40, mulmod(mload(0x3b00), mload(0x32c0), f_q))
            mstore(0x3e60, mulmod(mload(0x3c00), mload(0x32c0), f_q))
            mstore(0x3e80, mulmod(mload(0x3c20), mload(0x32c0), f_q))
            mstore(0x3ea0, mulmod(mload(0x3c40), mload(0x32c0), f_q))
            mstore(0x3ec0, mulmod(mload(0x3c60), mload(0x32c0), f_q))
            mstore(0x3ee0, mulmod(mload(0x3d00), mload(0x32c0), f_q))
            mstore(0x3f00, addmod(mload(0x3620), mload(0x3d40), f_q))
            mstore(0x3f20, mulmod(1, mload(0x2ae0), f_q))
            mstore(0x3f40, mulmod(1, mload(0xac0), f_q))
            mstore(0x3f60, 0x0000000000000000000000000000000000000000000000000000000000000001)
            mstore(0x3f80, 0x0000000000000000000000000000000000000000000000000000000000000002)
            mstore(0x3fa0, mload(0x3f00))
            success := and(eq(staticcall(gas(), 0x7, 0x3f60, 0x60, 0x3f60, 0x40), 1), success)
            mstore(0x3fc0, mload(0x3f60))
            mstore(0x3fe0, mload(0x3f80))
            mstore(0x4000, mload(0x2e0))
            mstore(0x4020, mload(0x300))
            success := and(eq(staticcall(gas(), 0x6, 0x3fc0, 0x80, 0x3fc0, 0x40), 1), success)
            mstore(0x4040, mload(0x4c0))
            mstore(0x4060, mload(0x4e0))
            mstore(0x4080, mload(0x34e0))
            success := and(eq(staticcall(gas(), 0x7, 0x4040, 0x60, 0x4040, 0x40), 1), success)
            mstore(0x40a0, mload(0x3fc0))
            mstore(0x40c0, mload(0x3fe0))
            mstore(0x40e0, mload(0x4040))
            mstore(0x4100, mload(0x4060))
            success := and(eq(staticcall(gas(), 0x6, 0x40a0, 0x80, 0x40a0, 0x40), 1), success)
            mstore(0x4120, mload(0x500))
            mstore(0x4140, mload(0x520))
            mstore(0x4160, mload(0x3500))
            success := and(eq(staticcall(gas(), 0x7, 0x4120, 0x60, 0x4120, 0x40), 1), success)
            mstore(0x4180, mload(0x40a0))
            mstore(0x41a0, mload(0x40c0))
            mstore(0x41c0, mload(0x4120))
            mstore(0x41e0, mload(0x4140))
            success := and(eq(staticcall(gas(), 0x6, 0x4180, 0x80, 0x4180, 0x40), 1), success)
            mstore(0x4200, mload(0x380))
            mstore(0x4220, mload(0x3a0))
            mstore(0x4240, mload(0x3600))
            success := and(eq(staticcall(gas(), 0x7, 0x4200, 0x60, 0x4200, 0x40), 1), success)
            mstore(0x4260, mload(0x4180))
            mstore(0x4280, mload(0x41a0))
            mstore(0x42a0, mload(0x4200))
            mstore(0x42c0, mload(0x4220))
            success := and(eq(staticcall(gas(), 0x6, 0x4260, 0x80, 0x4260, 0x40), 1), success)
            mstore(0x42e0, mload(0x3c0))
            mstore(0x4300, mload(0x3e0))
            mstore(0x4320, mload(0x3d60))
            success := and(eq(staticcall(gas(), 0x7, 0x42e0, 0x60, 0x42e0, 0x40), 1), success)
            mstore(0x4340, mload(0x4260))
            mstore(0x4360, mload(0x4280))
            mstore(0x4380, mload(0x42e0))
            mstore(0x43a0, mload(0x4300))
            success := and(eq(staticcall(gas(), 0x6, 0x4340, 0x80, 0x4340, 0x40), 1), success)
            mstore(0x43c0, 0x2e2574d50f941f0e43c690a26aaa5b6c3838c57f4e691864143cfaebfd85fda6)
            mstore(0x43e0, 0x19d3fcc79298ceb02bf7330736fadfc2fc7d2b31296d1f9f7b924954ca22def4)
            mstore(0x4400, mload(0x3d80))
            success := and(eq(staticcall(gas(), 0x7, 0x43c0, 0x60, 0x43c0, 0x40), 1), success)
            mstore(0x4420, mload(0x4340))
            mstore(0x4440, mload(0x4360))
            mstore(0x4460, mload(0x43c0))
            mstore(0x4480, mload(0x43e0))
            success := and(eq(staticcall(gas(), 0x6, 0x4420, 0x80, 0x4420, 0x40), 1), success)
            mstore(0x44a0, 0x2eb40e2b0c13a6f4b989cffa9dbc452447bfd9f04a79f6379aefea8c9850a550)
            mstore(0x44c0, 0x0efe5496541e2bd648d490f11ad542e1dec3127f818b8065843d0dd81358416c)
            mstore(0x44e0, mload(0x3da0))
            success := and(eq(staticcall(gas(), 0x7, 0x44a0, 0x60, 0x44a0, 0x40), 1), success)
            mstore(0x4500, mload(0x4420))
            mstore(0x4520, mload(0x4440))
            mstore(0x4540, mload(0x44a0))
            mstore(0x4560, mload(0x44c0))
            success := and(eq(staticcall(gas(), 0x6, 0x4500, 0x80, 0x4500, 0x40), 1), success)
            mstore(0x4580, 0x2d5064a1f4dd9516f3a1cce1f9922af6cfe65407fd525c7c8b28bab62993843b)
            mstore(0x45a0, 0x17018e2fdf777bd2ca472f3ce2e9888d22fedb841b641d6f4f935d8d7cd4a45d)
            mstore(0x45c0, mload(0x3dc0))
            success := and(eq(staticcall(gas(), 0x7, 0x4580, 0x60, 0x4580, 0x40), 1), success)
            mstore(0x45e0, mload(0x4500))
            mstore(0x4600, mload(0x4520))
            mstore(0x4620, mload(0x4580))
            mstore(0x4640, mload(0x45a0))
            success := and(eq(staticcall(gas(), 0x6, 0x45e0, 0x80, 0x45e0, 0x40), 1), success)
            mstore(0x4660, 0x174cc1788b2fcdbe6ef3d5f8de7bc720dd37530b3631ce81982ab8caf36e6b46)
            mstore(0x4680, 0x296771a2946551b4f1b56169978f915fdfd176de675b8d080e2cd67c822af6e6)
            mstore(0x46a0, mload(0x3de0))
            success := and(eq(staticcall(gas(), 0x7, 0x4660, 0x60, 0x4660, 0x40), 1), success)
            mstore(0x46c0, mload(0x45e0))
            mstore(0x46e0, mload(0x4600))
            mstore(0x4700, mload(0x4660))
            mstore(0x4720, mload(0x4680))
            success := and(eq(staticcall(gas(), 0x6, 0x46c0, 0x80, 0x46c0, 0x40), 1), success)
            mstore(0x4740, 0x04c143dc1ea8f2302b8fd37d75278628ea30bda01cdbbdfe313431297bc1fea6)
            mstore(0x4760, 0x2f9f31962207c19e6719fc6fa199df6a5af81c25b31e6395f3feb695f9570d92)
            mstore(0x4780, mload(0x3e00))
            success := and(eq(staticcall(gas(), 0x7, 0x4740, 0x60, 0x4740, 0x40), 1), success)
            mstore(0x47a0, mload(0x46c0))
            mstore(0x47c0, mload(0x46e0))
            mstore(0x47e0, mload(0x4740))
            mstore(0x4800, mload(0x4760))
            success := and(eq(staticcall(gas(), 0x6, 0x47a0, 0x80, 0x47a0, 0x40), 1), success)
            mstore(0x4820, 0x1d3f5729c370812d05740885d3ef03153dcb06a997d7f2c3f692b4805d725367)
            mstore(0x4840, 0x2a5a7bf3bff61f8fb4d92238b7677cd2dfa4f591b6bac03a2334753d9095732a)
            mstore(0x4860, mload(0x3e20))
            success := and(eq(staticcall(gas(), 0x7, 0x4820, 0x60, 0x4820, 0x40), 1), success)
            mstore(0x4880, mload(0x47a0))
            mstore(0x48a0, mload(0x47c0))
            mstore(0x48c0, mload(0x4820))
            mstore(0x48e0, mload(0x4840))
            success := and(eq(staticcall(gas(), 0x6, 0x4880, 0x80, 0x4880, 0x40), 1), success)
            mstore(0x4900, 0x279370dda0964bf67c5a7edfdc9907ef068dcc9041c5d3306466427ea8b10cf8)
            mstore(0x4920, 0x2aef15e79bb043e6a99d64790c415b11f05c845b63157babf05071dec0960e92)
            mstore(0x4940, mload(0x3e40))
            success := and(eq(staticcall(gas(), 0x7, 0x4900, 0x60, 0x4900, 0x40), 1), success)
            mstore(0x4960, mload(0x4880))
            mstore(0x4980, mload(0x48a0))
            mstore(0x49a0, mload(0x4900))
            mstore(0x49c0, mload(0x4920))
            success := and(eq(staticcall(gas(), 0x6, 0x4960, 0x80, 0x4960, 0x40), 1), success)
            mstore(0x49e0, mload(0x5e0))
            mstore(0x4a00, mload(0x600))
            mstore(0x4a20, mload(0x3e60))
            success := and(eq(staticcall(gas(), 0x7, 0x49e0, 0x60, 0x49e0, 0x40), 1), success)
            mstore(0x4a40, mload(0x4960))
            mstore(0x4a60, mload(0x4980))
            mstore(0x4a80, mload(0x49e0))
            mstore(0x4aa0, mload(0x4a00))
            success := and(eq(staticcall(gas(), 0x6, 0x4a40, 0x80, 0x4a40, 0x40), 1), success)
            mstore(0x4ac0, mload(0x620))
            mstore(0x4ae0, mload(0x640))
            mstore(0x4b00, mload(0x3e80))
            success := and(eq(staticcall(gas(), 0x7, 0x4ac0, 0x60, 0x4ac0, 0x40), 1), success)
            mstore(0x4b20, mload(0x4a40))
            mstore(0x4b40, mload(0x4a60))
            mstore(0x4b60, mload(0x4ac0))
            mstore(0x4b80, mload(0x4ae0))
            success := and(eq(staticcall(gas(), 0x6, 0x4b20, 0x80, 0x4b20, 0x40), 1), success)
            mstore(0x4ba0, mload(0x660))
            mstore(0x4bc0, mload(0x680))
            mstore(0x4be0, mload(0x3ea0))
            success := and(eq(staticcall(gas(), 0x7, 0x4ba0, 0x60, 0x4ba0, 0x40), 1), success)
            mstore(0x4c00, mload(0x4b20))
            mstore(0x4c20, mload(0x4b40))
            mstore(0x4c40, mload(0x4ba0))
            mstore(0x4c60, mload(0x4bc0))
            success := and(eq(staticcall(gas(), 0x6, 0x4c00, 0x80, 0x4c00, 0x40), 1), success)
            mstore(0x4c80, mload(0x6a0))
            mstore(0x4ca0, mload(0x6c0))
            mstore(0x4cc0, mload(0x3ec0))
            success := and(eq(staticcall(gas(), 0x7, 0x4c80, 0x60, 0x4c80, 0x40), 1), success)
            mstore(0x4ce0, mload(0x4c00))
            mstore(0x4d00, mload(0x4c20))
            mstore(0x4d20, mload(0x4c80))
            mstore(0x4d40, mload(0x4ca0))
            success := and(eq(staticcall(gas(), 0x6, 0x4ce0, 0x80, 0x4ce0, 0x40), 1), success)
            mstore(0x4d60, mload(0x540))
            mstore(0x4d80, mload(0x560))
            mstore(0x4da0, mload(0x3ee0))
            success := and(eq(staticcall(gas(), 0x7, 0x4d60, 0x60, 0x4d60, 0x40), 1), success)
            mstore(0x4dc0, mload(0x4ce0))
            mstore(0x4de0, mload(0x4d00))
            mstore(0x4e00, mload(0x4d60))
            mstore(0x4e20, mload(0x4d80))
            success := and(eq(staticcall(gas(), 0x6, 0x4dc0, 0x80, 0x4dc0, 0x40), 1), success)
            mstore(0x4e40, mload(0xa60))
            mstore(0x4e60, mload(0xa80))
            mstore(0x4e80, sub(f_q, mload(0x3f20)))
            success := and(eq(staticcall(gas(), 0x7, 0x4e40, 0x60, 0x4e40, 0x40), 1), success)
            mstore(0x4ea0, mload(0x4dc0))
            mstore(0x4ec0, mload(0x4de0))
            mstore(0x4ee0, mload(0x4e40))
            mstore(0x4f00, mload(0x4e60))
            success := and(eq(staticcall(gas(), 0x6, 0x4ea0, 0x80, 0x4ea0, 0x40), 1), success)
            mstore(0x4f20, mload(0xb00))
            mstore(0x4f40, mload(0xb20))
            mstore(0x4f60, mload(0x3f40))
            success := and(eq(staticcall(gas(), 0x7, 0x4f20, 0x60, 0x4f20, 0x40), 1), success)
            mstore(0x4f80, mload(0x4ea0))
            mstore(0x4fa0, mload(0x4ec0))
            mstore(0x4fc0, mload(0x4f20))
            mstore(0x4fe0, mload(0x4f40))
            success := and(eq(staticcall(gas(), 0x6, 0x4f80, 0x80, 0x4f80, 0x40), 1), success)
            mstore(0x5000, mload(0x4f80))
            mstore(0x5020, mload(0x4fa0))
            mstore(0x5040, mload(0xb00))
            mstore(0x5060, mload(0xb20))
            mstore(0x5080, mload(0xb40))
            mstore(0x50a0, mload(0xb60))
            mstore(0x50c0, mload(0xb80))
            mstore(0x50e0, mload(0xba0))
            mstore(0x5100, keccak256(0x5000, 256))
            mstore(20768, mod(mload(20736), f_q))
            mstore(0x5140, mulmod(mload(0x5120), mload(0x5120), f_q))
            mstore(0x5160, mulmod(1, mload(0x5120), f_q))
            mstore(0x5180, mload(0x5080))
            mstore(0x51a0, mload(0x50a0))
            mstore(0x51c0, mload(0x5160))
            success := and(eq(staticcall(gas(), 0x7, 0x5180, 0x60, 0x5180, 0x40), 1), success)
            mstore(0x51e0, mload(0x5000))
            mstore(0x5200, mload(0x5020))
            mstore(0x5220, mload(0x5180))
            mstore(0x5240, mload(0x51a0))
            success := and(eq(staticcall(gas(), 0x6, 0x51e0, 0x80, 0x51e0, 0x40), 1), success)
            mstore(0x5260, mload(0x50c0))
            mstore(0x5280, mload(0x50e0))
            mstore(0x52a0, mload(0x5160))
            success := and(eq(staticcall(gas(), 0x7, 0x5260, 0x60, 0x5260, 0x40), 1), success)
            mstore(0x52c0, mload(0x5040))
            mstore(0x52e0, mload(0x5060))
            mstore(0x5300, mload(0x5260))
            mstore(0x5320, mload(0x5280))
            success := and(eq(staticcall(gas(), 0x6, 0x52c0, 0x80, 0x52c0, 0x40), 1), success)
            mstore(0x5340, mload(0x51e0))
            mstore(0x5360, mload(0x5200))
            mstore(0x5380, 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2)
            mstore(0x53a0, 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed)
            mstore(0x53c0, 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b)
            mstore(0x53e0, 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa)
            mstore(0x5400, mload(0x52c0))
            mstore(0x5420, mload(0x52e0))
            mstore(0x5440, 0x172aa93c41f16e1e04d62ac976a5d945f4be0acab990c6dc19ac4a7cf68bf77b)
            mstore(0x5460, 0x2ae0c8c3a090f7200ff398ee9845bbae8f8c1445ae7b632212775f60a0e21600)
            mstore(0x5480, 0x190fa476a5b352809ed41d7a0d7fe12b8f685e3c12a6d83855dba27aaf469643)
            mstore(0x54a0, 0x1c0a500618907df9e4273d5181e31088deb1f05132de037cbfe73888f97f77c9)
            success := and(eq(staticcall(gas(), 0x8, 0x5340, 0x180, 0x5340, 0x20), 1), success)
            success := and(eq(mload(0x5340), 1), success)

            // Revert if anything fails
            if iszero(success) { revert(0, 0) }

            // Return empty bytes on success
            return(0, 0)
        }
    }
}

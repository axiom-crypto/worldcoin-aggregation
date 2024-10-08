// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract V1Claim128Verifier {
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
            mstore(0x80, 12539156402519065942152929369317526928626503019059017840615728598672903251921)

            {
                let x := calldataload(0x1c0)
                mstore(0x260, x)
                let y := calldataload(0x1e0)
                mstore(0x280, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x2a0, keccak256(0x80, 544))
            {
                let hash := mload(0x2a0)
                mstore(0x2c0, mod(hash, f_q))
                mstore(0x2e0, hash)
            }

            {
                let x := calldataload(0x200)
                mstore(0x300, x)
                let y := calldataload(0x220)
                mstore(0x320, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x240)
                mstore(0x340, x)
                let y := calldataload(0x260)
                mstore(0x360, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x380, keccak256(0x2e0, 160))
            {
                let hash := mload(0x380)
                mstore(0x3a0, mod(hash, f_q))
                mstore(0x3c0, hash)
            }
            mstore8(992, 1)
            mstore(0x3e0, keccak256(0x3c0, 33))
            {
                let hash := mload(0x3e0)
                mstore(0x400, mod(hash, f_q))
                mstore(0x420, hash)
            }

            {
                let x := calldataload(0x280)
                mstore(0x440, x)
                let y := calldataload(0x2a0)
                mstore(0x460, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x2c0)
                mstore(0x480, x)
                let y := calldataload(0x2e0)
                mstore(0x4a0, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x300)
                mstore(0x4c0, x)
                let y := calldataload(0x320)
                mstore(0x4e0, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x500, keccak256(0x420, 224))
            {
                let hash := mload(0x500)
                mstore(0x520, mod(hash, f_q))
                mstore(0x540, hash)
            }

            {
                let x := calldataload(0x340)
                mstore(0x560, x)
                let y := calldataload(0x360)
                mstore(0x580, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x380)
                mstore(0x5a0, x)
                let y := calldataload(0x3a0)
                mstore(0x5c0, y)
                success := and(validate_ec_point(x, y), success)
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
            mstore(0x660, keccak256(0x540, 288))
            {
                let hash := mload(0x660)
                mstore(0x680, mod(hash, f_q))
                mstore(0x6a0, hash)
            }
            mstore(0x6c0, mod(calldataload(0x440), f_q))
            mstore(0x6e0, mod(calldataload(0x460), f_q))
            mstore(0x700, mod(calldataload(0x480), f_q))
            mstore(0x720, mod(calldataload(0x4a0), f_q))
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
            mstore(0x920, keccak256(0x6a0, 640))
            {
                let hash := mload(0x920)
                mstore(0x940, mod(hash, f_q))
                mstore(0x960, hash)
            }
            mstore8(2432, 1)
            mstore(0x980, keccak256(0x960, 33))
            {
                let hash := mload(0x980)
                mstore(0x9a0, mod(hash, f_q))
                mstore(0x9c0, hash)
            }

            {
                let x := calldataload(0x6a0)
                mstore(0x9e0, x)
                let y := calldataload(0x6c0)
                mstore(0xa00, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0xa20, keccak256(0x9c0, 96))
            {
                let hash := mload(0xa20)
                mstore(0xa40, mod(hash, f_q))
                mstore(0xa60, hash)
            }

            {
                let x := calldataload(0x6e0)
                mstore(0xa80, x)
                let y := calldataload(0x700)
                mstore(0xaa0, y)
                success := and(validate_ec_point(x, y), success)
            }
            {
                let x := mload(0xa0)
                x := add(x, shl(88, mload(0xc0)))
                x := add(x, shl(176, mload(0xe0)))
                mstore(2752, x)
                let y := mload(0x100)
                y := add(y, shl(88, mload(0x120)))
                y := add(y, shl(176, mload(0x140)))
                mstore(2784, y)

                success := and(validate_ec_point(x, y), success)
            }
            {
                let x := mload(0x160)
                x := add(x, shl(88, mload(0x180)))
                x := add(x, shl(176, mload(0x1a0)))
                mstore(2816, x)
                let y := mload(0x1c0)
                y := add(y, shl(88, mload(0x1e0)))
                y := add(y, shl(176, mload(0x200)))
                mstore(2848, y)

                success := and(validate_ec_point(x, y), success)
            }
            mstore(0xb40, mulmod(mload(0x680), mload(0x680), f_q))
            mstore(0xb60, mulmod(mload(0xb40), mload(0xb40), f_q))
            mstore(0xb80, mulmod(mload(0xb60), mload(0xb60), f_q))
            mstore(0xba0, mulmod(mload(0xb80), mload(0xb80), f_q))
            mstore(0xbc0, mulmod(mload(0xba0), mload(0xba0), f_q))
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
            mstore(
                0xe20,
                addmod(mload(0xe00), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q)
            )
            mstore(
                0xe40,
                mulmod(mload(0xe20), 21888240262557392955334514970720457388010314637169927192662615958087340972065, f_q)
            )
            mstore(
                0xe60,
                mulmod(mload(0xe40), 4506835738822104338668100540817374747935106310012997856968187171738630203507, f_q)
            )
            mstore(
                0xe80,
                addmod(mload(0x680), 17381407133017170883578305204439900340613258090403036486730017014837178292110, f_q)
            )
            mstore(
                0xea0,
                mulmod(mload(0xe40), 21710372849001950800533397158415938114909991150039389063546734567764856596059, f_q)
            )
            mstore(
                0xec0,
                addmod(mload(0x680), 177870022837324421713008586841336973638373250376645280151469618810951899558, f_q)
            )
            mstore(
                0xee0,
                mulmod(mload(0xe40), 1887003188133998471169152042388914354640772748308168868301418279904560637395, f_q)
            )
            mstore(
                0xf00,
                addmod(mload(0x680), 20001239683705276751077253702868360733907591652107865475396785906671247858222, f_q)
            )
            mstore(
                0xf20,
                mulmod(mload(0xe40), 2785514556381676080176937710880804108647911392478702105860685610379369825016, f_q)
            )
            mstore(
                0xf40,
                addmod(mload(0x680), 19102728315457599142069468034376470979900453007937332237837518576196438670601, f_q)
            )
            mstore(
                0xf60,
                mulmod(mload(0xe40), 14655294445420895451632927078981340937842238432098198055057679026789553137428, f_q)
            )
            mstore(
                0xf80,
                addmod(mload(0x680), 7232948426418379770613478666275934150706125968317836288640525159786255358189, f_q)
            )
            mstore(
                0xfa0,
                mulmod(mload(0xe40), 8734126352828345679573237859165904705806588461301144420590422589042130041188, f_q)
            )
            mstore(
                0xfc0,
                addmod(mload(0x680), 13154116519010929542673167886091370382741775939114889923107781597533678454429, f_q)
            )
            mstore(
                0xfe0,
                mulmod(mload(0xe40), 9741553891420464328295280489650144566903017206473301385034033384879943874347, f_q)
            )
            mstore(
                0x1000,
                addmod(mload(0x680), 12146688980418810893951125255607130521645347193942732958664170801695864621270, f_q)
            )
            mstore(0x1020, mulmod(mload(0xe40), 1, f_q))
            mstore(
                0x1040,
                addmod(mload(0x680), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q)
            )
            mstore(
                0x1060,
                mulmod(mload(0xe40), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            mstore(
                0x1080,
                addmod(mload(0x680), 13513867906530865119835332133273263211836799082674232843258448413103731898270, f_q)
            )
            mstore(
                0x10a0,
                mulmod(mload(0xe40), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q)
            )
            mstore(
                0x10c0,
                addmod(mload(0x680), 10676941854703594198666993839846402519342119846958189386823924046696287912227, f_q)
            )
            mstore(
                0x10e0,
                mulmod(mload(0xe40), 3615478808282855240548287271348143516886772452944084747768312988864436725401, f_q)
            )
            mstore(
                0x1100,
                addmod(mload(0x680), 18272764063556419981698118473909131571661591947471949595929891197711371770216, f_q)
            )
            mstore(
                0x1120,
                mulmod(mload(0xe40), 1426404432721484388505361748317961535523355871255605456897797744433766488507, f_q)
            )
            mstore(
                0x1140,
                addmod(mload(0x680), 20461838439117790833741043996939313553025008529160428886800406442142042007110, f_q)
            )
            mstore(
                0x1160,
                mulmod(mload(0xe40), 216092043779272773661818549620449970334216366264741118684015851799902419467, f_q)
            )
            mstore(
                0x1180,
                addmod(mload(0x680), 21672150828060002448584587195636825118214148034151293225014188334775906076150, f_q)
            )
            mstore(
                0x11a0,
                mulmod(mload(0xe40), 12619617507853212586156872920672483948819476989779550311307282715684870266992, f_q)
            )
            mstore(
                0x11c0,
                addmod(mload(0x680), 9268625363986062636089532824584791139728887410636484032390921470890938228625, f_q)
            )
            mstore(
                0x11e0,
                mulmod(mload(0xe40), 18610195890048912503953886742825279624920778288956610528523679659246523534888, f_q)
            )
            mstore(
                0x1200,
                addmod(mload(0x680), 3278046981790362718292519002431995463627586111459423815174524527329284960729, f_q)
            )
            mstore(
                0x1220,
                mulmod(mload(0xe40), 19032961837237948602743626455740240236231119053033140765040043513661803148152, f_q)
            )
            mstore(
                0x1240,
                addmod(mload(0x680), 2855281034601326619502779289517034852317245347382893578658160672914005347465, f_q)
            )
            mstore(
                0x1260,
                mulmod(mload(0xe40), 14875928112196239563830800280253496262679717528621719058794366823499719730250, f_q)
            )
            mstore(
                0x1280,
                addmod(mload(0x680), 7012314759643035658415605465003778825868646871794315284903837363076088765367, f_q)
            )
            mstore(
                0x12a0,
                mulmod(mload(0xe40), 915149353520972163646494413843788069594022902357002628455555785223409501882, f_q)
            )
            mstore(
                0x12c0,
                addmod(mload(0x680), 20973093518318303058599911331413487018954341498059031715242648401352398993735, f_q)
            )
            mstore(
                0x12e0,
                mulmod(mload(0xe40), 5522161504810533295870699551020523636289972223872138525048055197429246400245, f_q)
            )
            mstore(
                0x1300,
                addmod(mload(0x680), 16366081367028741926375706194236751452258392176543895818650148989146562095372, f_q)
            )
            mstore(
                0x1320,
                mulmod(mload(0xe40), 3766081621734395783232337525162072736827576297943013392955872170138036189193, f_q)
            )
            mstore(
                0x1340,
                addmod(mload(0x680), 18122161250104879439014068220095202351720788102473020950742332016437772306424, f_q)
            )
            mstore(
                0x1360,
                mulmod(mload(0xe40), 9100833993744738801214480881117348002768153232283708533639316963648253510584, f_q)
            )
            mstore(
                0x1380,
                addmod(mload(0x680), 12787408878094536421031924864139927085780211168132325810058887222927554985033, f_q)
            )
            {
                let prod := mload(0xe80)

                prod := mulmod(mload(0xec0), prod, f_q)
                mstore(0x13a0, prod)

                prod := mulmod(mload(0xf00), prod, f_q)
                mstore(0x13c0, prod)

                prod := mulmod(mload(0xf40), prod, f_q)
                mstore(0x13e0, prod)

                prod := mulmod(mload(0xf80), prod, f_q)
                mstore(0x1400, prod)

                prod := mulmod(mload(0xfc0), prod, f_q)
                mstore(0x1420, prod)

                prod := mulmod(mload(0x1000), prod, f_q)
                mstore(0x1440, prod)

                prod := mulmod(mload(0x1040), prod, f_q)
                mstore(0x1460, prod)

                prod := mulmod(mload(0x1080), prod, f_q)
                mstore(0x1480, prod)

                prod := mulmod(mload(0x10c0), prod, f_q)
                mstore(0x14a0, prod)

                prod := mulmod(mload(0x1100), prod, f_q)
                mstore(0x14c0, prod)

                prod := mulmod(mload(0x1140), prod, f_q)
                mstore(0x14e0, prod)

                prod := mulmod(mload(0x1180), prod, f_q)
                mstore(0x1500, prod)

                prod := mulmod(mload(0x11c0), prod, f_q)
                mstore(0x1520, prod)

                prod := mulmod(mload(0x1200), prod, f_q)
                mstore(0x1540, prod)

                prod := mulmod(mload(0x1240), prod, f_q)
                mstore(0x1560, prod)

                prod := mulmod(mload(0x1280), prod, f_q)
                mstore(0x1580, prod)

                prod := mulmod(mload(0x12c0), prod, f_q)
                mstore(0x15a0, prod)

                prod := mulmod(mload(0x1300), prod, f_q)
                mstore(0x15c0, prod)

                prod := mulmod(mload(0x1340), prod, f_q)
                mstore(0x15e0, prod)

                prod := mulmod(mload(0x1380), prod, f_q)
                mstore(0x1600, prod)

                prod := mulmod(mload(0xe20), prod, f_q)
                mstore(0x1620, prod)
            }
            mstore(0x1660, 32)
            mstore(0x1680, 32)
            mstore(0x16a0, 32)
            mstore(0x16c0, mload(0x1620))
            mstore(0x16e0, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x1700, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x1660, 0xc0, 0x1640, 0x20), 1), success)
            {
                let inv := mload(0x1640)
                let v

                v := mload(0xe20)
                mstore(3616, mulmod(mload(0x1600), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1380)
                mstore(4992, mulmod(mload(0x15e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1340)
                mstore(4928, mulmod(mload(0x15c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1300)
                mstore(4864, mulmod(mload(0x15a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x12c0)
                mstore(4800, mulmod(mload(0x1580), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1280)
                mstore(4736, mulmod(mload(0x1560), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1240)
                mstore(4672, mulmod(mload(0x1540), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1200)
                mstore(4608, mulmod(mload(0x1520), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x11c0)
                mstore(4544, mulmod(mload(0x1500), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1180)
                mstore(4480, mulmod(mload(0x14e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1140)
                mstore(4416, mulmod(mload(0x14c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1100)
                mstore(4352, mulmod(mload(0x14a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x10c0)
                mstore(4288, mulmod(mload(0x1480), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1080)
                mstore(4224, mulmod(mload(0x1460), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1040)
                mstore(4160, mulmod(mload(0x1440), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1000)
                mstore(4096, mulmod(mload(0x1420), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xfc0)
                mstore(4032, mulmod(mload(0x1400), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xf80)
                mstore(3968, mulmod(mload(0x13e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xf40)
                mstore(3904, mulmod(mload(0x13c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xf00)
                mstore(3840, mulmod(mload(0x13a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0xec0)
                mstore(3776, mulmod(mload(0xe80), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0xe80, inv)
            }
            mstore(0x1720, mulmod(mload(0xe60), mload(0xe80), f_q))
            mstore(0x1740, mulmod(mload(0xea0), mload(0xec0), f_q))
            mstore(0x1760, mulmod(mload(0xee0), mload(0xf00), f_q))
            mstore(0x1780, mulmod(mload(0xf20), mload(0xf40), f_q))
            mstore(0x17a0, mulmod(mload(0xf60), mload(0xf80), f_q))
            mstore(0x17c0, mulmod(mload(0xfa0), mload(0xfc0), f_q))
            mstore(0x17e0, mulmod(mload(0xfe0), mload(0x1000), f_q))
            mstore(0x1800, mulmod(mload(0x1020), mload(0x1040), f_q))
            mstore(0x1820, mulmod(mload(0x1060), mload(0x1080), f_q))
            mstore(0x1840, mulmod(mload(0x10a0), mload(0x10c0), f_q))
            mstore(0x1860, mulmod(mload(0x10e0), mload(0x1100), f_q))
            mstore(0x1880, mulmod(mload(0x1120), mload(0x1140), f_q))
            mstore(0x18a0, mulmod(mload(0x1160), mload(0x1180), f_q))
            mstore(0x18c0, mulmod(mload(0x11a0), mload(0x11c0), f_q))
            mstore(0x18e0, mulmod(mload(0x11e0), mload(0x1200), f_q))
            mstore(0x1900, mulmod(mload(0x1220), mload(0x1240), f_q))
            mstore(0x1920, mulmod(mload(0x1260), mload(0x1280), f_q))
            mstore(0x1940, mulmod(mload(0x12a0), mload(0x12c0), f_q))
            mstore(0x1960, mulmod(mload(0x12e0), mload(0x1300), f_q))
            mstore(0x1980, mulmod(mload(0x1320), mload(0x1340), f_q))
            mstore(0x19a0, mulmod(mload(0x1360), mload(0x1380), f_q))
            {
                let result := mulmod(mload(0x1800), mload(0xa0), f_q)
                result := addmod(mulmod(mload(0x1820), mload(0xc0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1840), mload(0xe0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1860), mload(0x100), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1880), mload(0x120), f_q), result, f_q)
                result := addmod(mulmod(mload(0x18a0), mload(0x140), f_q), result, f_q)
                result := addmod(mulmod(mload(0x18c0), mload(0x160), f_q), result, f_q)
                result := addmod(mulmod(mload(0x18e0), mload(0x180), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1900), mload(0x1a0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1920), mload(0x1c0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1940), mload(0x1e0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1960), mload(0x200), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1980), mload(0x220), f_q), result, f_q)
                result := addmod(mulmod(mload(0x19a0), mload(0x240), f_q), result, f_q)
                mstore(6592, result)
            }
            mstore(0x19e0, mulmod(mload(0x700), mload(0x6e0), f_q))
            mstore(0x1a00, addmod(mload(0x6c0), mload(0x19e0), f_q))
            mstore(0x1a20, addmod(mload(0x1a00), sub(f_q, mload(0x720)), f_q))
            mstore(0x1a40, mulmod(mload(0x1a20), mload(0x780), f_q))
            mstore(0x1a60, mulmod(mload(0x520), mload(0x1a40), f_q))
            mstore(0x1a80, addmod(1, sub(f_q, mload(0x840)), f_q))
            mstore(0x1aa0, mulmod(mload(0x1a80), mload(0x1800), f_q))
            mstore(0x1ac0, addmod(mload(0x1a60), mload(0x1aa0), f_q))
            mstore(0x1ae0, mulmod(mload(0x520), mload(0x1ac0), f_q))
            mstore(0x1b00, mulmod(mload(0x840), mload(0x840), f_q))
            mstore(0x1b20, addmod(mload(0x1b00), sub(f_q, mload(0x840)), f_q))
            mstore(0x1b40, mulmod(mload(0x1b20), mload(0x1720), f_q))
            mstore(0x1b60, addmod(mload(0x1ae0), mload(0x1b40), f_q))
            mstore(0x1b80, mulmod(mload(0x520), mload(0x1b60), f_q))
            mstore(0x1ba0, addmod(1, sub(f_q, mload(0x1720)), f_q))
            mstore(0x1bc0, addmod(mload(0x1740), mload(0x1760), f_q))
            mstore(0x1be0, addmod(mload(0x1bc0), mload(0x1780), f_q))
            mstore(0x1c00, addmod(mload(0x1be0), mload(0x17a0), f_q))
            mstore(0x1c20, addmod(mload(0x1c00), mload(0x17c0), f_q))
            mstore(0x1c40, addmod(mload(0x1c20), mload(0x17e0), f_q))
            mstore(0x1c60, addmod(mload(0x1ba0), sub(f_q, mload(0x1c40)), f_q))
            mstore(0x1c80, mulmod(mload(0x7e0), mload(0x3a0), f_q))
            mstore(0x1ca0, addmod(mload(0x740), mload(0x1c80), f_q))
            mstore(0x1cc0, addmod(mload(0x1ca0), mload(0x400), f_q))
            mstore(0x1ce0, mulmod(mload(0x800), mload(0x3a0), f_q))
            mstore(0x1d00, addmod(mload(0x6c0), mload(0x1ce0), f_q))
            mstore(0x1d20, addmod(mload(0x1d00), mload(0x400), f_q))
            mstore(0x1d40, mulmod(mload(0x1d20), mload(0x1cc0), f_q))
            mstore(0x1d60, mulmod(mload(0x820), mload(0x3a0), f_q))
            mstore(0x1d80, addmod(mload(0x19c0), mload(0x1d60), f_q))
            mstore(0x1da0, addmod(mload(0x1d80), mload(0x400), f_q))
            mstore(0x1dc0, mulmod(mload(0x1da0), mload(0x1d40), f_q))
            mstore(0x1de0, mulmod(mload(0x1dc0), mload(0x860), f_q))
            mstore(0x1e00, mulmod(1, mload(0x3a0), f_q))
            mstore(0x1e20, mulmod(mload(0x680), mload(0x1e00), f_q))
            mstore(0x1e40, addmod(mload(0x740), mload(0x1e20), f_q))
            mstore(0x1e60, addmod(mload(0x1e40), mload(0x400), f_q))
            mstore(
                0x1e80,
                mulmod(4131629893567559867359510883348571134090853742863529169391034518566172092834, mload(0x3a0), f_q)
            )
            mstore(0x1ea0, mulmod(mload(0x680), mload(0x1e80), f_q))
            mstore(0x1ec0, addmod(mload(0x6c0), mload(0x1ea0), f_q))
            mstore(0x1ee0, addmod(mload(0x1ec0), mload(0x400), f_q))
            mstore(0x1f00, mulmod(mload(0x1ee0), mload(0x1e60), f_q))
            mstore(
                0x1f20,
                mulmod(8910878055287538404433155982483128285667088683464058436815641868457422632747, mload(0x3a0), f_q)
            )
            mstore(0x1f40, mulmod(mload(0x680), mload(0x1f20), f_q))
            mstore(0x1f60, addmod(mload(0x19c0), mload(0x1f40), f_q))
            mstore(0x1f80, addmod(mload(0x1f60), mload(0x400), f_q))
            mstore(0x1fa0, mulmod(mload(0x1f80), mload(0x1f00), f_q))
            mstore(0x1fc0, mulmod(mload(0x1fa0), mload(0x840), f_q))
            mstore(0x1fe0, addmod(mload(0x1de0), sub(f_q, mload(0x1fc0)), f_q))
            mstore(0x2000, mulmod(mload(0x1fe0), mload(0x1c60), f_q))
            mstore(0x2020, addmod(mload(0x1b80), mload(0x2000), f_q))
            mstore(0x2040, mulmod(mload(0x520), mload(0x2020), f_q))
            mstore(0x2060, addmod(1, sub(f_q, mload(0x880)), f_q))
            mstore(0x2080, mulmod(mload(0x2060), mload(0x1800), f_q))
            mstore(0x20a0, addmod(mload(0x2040), mload(0x2080), f_q))
            mstore(0x20c0, mulmod(mload(0x520), mload(0x20a0), f_q))
            mstore(0x20e0, mulmod(mload(0x880), mload(0x880), f_q))
            mstore(0x2100, addmod(mload(0x20e0), sub(f_q, mload(0x880)), f_q))
            mstore(0x2120, mulmod(mload(0x2100), mload(0x1720), f_q))
            mstore(0x2140, addmod(mload(0x20c0), mload(0x2120), f_q))
            mstore(0x2160, mulmod(mload(0x520), mload(0x2140), f_q))
            mstore(0x2180, addmod(mload(0x8c0), mload(0x3a0), f_q))
            mstore(0x21a0, mulmod(mload(0x2180), mload(0x8a0), f_q))
            mstore(0x21c0, addmod(mload(0x900), mload(0x400), f_q))
            mstore(0x21e0, mulmod(mload(0x21c0), mload(0x21a0), f_q))
            mstore(0x2200, mulmod(mload(0x6c0), mload(0x7a0), f_q))
            mstore(0x2220, addmod(mload(0x2200), mload(0x3a0), f_q))
            mstore(0x2240, mulmod(mload(0x2220), mload(0x880), f_q))
            mstore(0x2260, addmod(mload(0x760), mload(0x400), f_q))
            mstore(0x2280, mulmod(mload(0x2260), mload(0x2240), f_q))
            mstore(0x22a0, addmod(mload(0x21e0), sub(f_q, mload(0x2280)), f_q))
            mstore(0x22c0, mulmod(mload(0x22a0), mload(0x1c60), f_q))
            mstore(0x22e0, addmod(mload(0x2160), mload(0x22c0), f_q))
            mstore(0x2300, mulmod(mload(0x520), mload(0x22e0), f_q))
            mstore(0x2320, addmod(mload(0x8c0), sub(f_q, mload(0x900)), f_q))
            mstore(0x2340, mulmod(mload(0x2320), mload(0x1800), f_q))
            mstore(0x2360, addmod(mload(0x2300), mload(0x2340), f_q))
            mstore(0x2380, mulmod(mload(0x520), mload(0x2360), f_q))
            mstore(0x23a0, mulmod(mload(0x2320), mload(0x1c60), f_q))
            mstore(0x23c0, addmod(mload(0x8c0), sub(f_q, mload(0x8e0)), f_q))
            mstore(0x23e0, mulmod(mload(0x23c0), mload(0x23a0), f_q))
            mstore(0x2400, addmod(mload(0x2380), mload(0x23e0), f_q))
            mstore(0x2420, mulmod(mload(0xe00), mload(0xe00), f_q))
            mstore(0x2440, mulmod(mload(0x2420), mload(0xe00), f_q))
            mstore(0x2460, mulmod(mload(0x2440), mload(0xe00), f_q))
            mstore(0x2480, mulmod(1, mload(0xe00), f_q))
            mstore(0x24a0, mulmod(1, mload(0x2420), f_q))
            mstore(0x24c0, mulmod(1, mload(0x2440), f_q))
            mstore(0x24e0, mulmod(mload(0x2400), mload(0xe20), f_q))
            mstore(0x2500, mulmod(mload(0xb40), mload(0x680), f_q))
            mstore(0x2520, mulmod(mload(0x2500), mload(0x680), f_q))
            mstore(
                0x2540,
                mulmod(mload(0x680), 9741553891420464328295280489650144566903017206473301385034033384879943874347, f_q)
            )
            mstore(0x2560, addmod(mload(0xa40), sub(f_q, mload(0x2540)), f_q))
            mstore(0x2580, mulmod(mload(0x680), 1, f_q))
            mstore(0x25a0, addmod(mload(0xa40), sub(f_q, mload(0x2580)), f_q))
            mstore(
                0x25c0,
                mulmod(mload(0x680), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            mstore(0x25e0, addmod(mload(0xa40), sub(f_q, mload(0x25c0)), f_q))
            mstore(
                0x2600,
                mulmod(mload(0x680), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q)
            )
            mstore(0x2620, addmod(mload(0xa40), sub(f_q, mload(0x2600)), f_q))
            mstore(
                0x2640,
                mulmod(mload(0x680), 3615478808282855240548287271348143516886772452944084747768312988864436725401, f_q)
            )
            mstore(0x2660, addmod(mload(0xa40), sub(f_q, mload(0x2640)), f_q))
            mstore(
                0x2680,
                mulmod(
                    13213688729882003894512633350385593288217014177373218494356903340348818451480, mload(0x2500), f_q
                )
            )
            mstore(0x26a0, mulmod(mload(0x2680), 1, f_q))
            {
                let result := mulmod(mload(0xa40), mload(0x2680), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x26a0)), f_q), result, f_q)
                mstore(9920, result)
            }
            mstore(
                0x26e0,
                mulmod(8207090019724696496350398458716998472718344609680392612601596849934418295470, mload(0x2500), f_q)
            )
            mstore(
                0x2700,
                mulmod(mload(0x26e0), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            {
                let result := mulmod(mload(0xa40), mload(0x26e0), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x2700)), f_q), result, f_q)
                mstore(10016, result)
            }
            mstore(
                0x2740,
                mulmod(7391709068497399131897422873231908718558236401035363928063603272120120747483, mload(0x2500), f_q)
            )
            mstore(
                0x2760,
                mulmod(
                    mload(0x2740), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q
                )
            )
            {
                let result := mulmod(mload(0xa40), mload(0x2740), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x2760)), f_q), result, f_q)
                mstore(10112, result)
            }
            mstore(
                0x27a0,
                mulmod(
                    19036273796805830823244991598792794567595348772040298280440552631112242221017, mload(0x2500), f_q
                )
            )
            mstore(
                0x27c0,
                mulmod(mload(0x27a0), 3615478808282855240548287271348143516886772452944084747768312988864436725401, f_q)
            )
            {
                let result := mulmod(mload(0xa40), mload(0x27a0), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x27c0)), f_q), result, f_q)
                mstore(10208, result)
            }
            mstore(0x2800, mulmod(1, mload(0x25a0), f_q))
            mstore(0x2820, mulmod(mload(0x2800), mload(0x25e0), f_q))
            mstore(0x2840, mulmod(mload(0x2820), mload(0x2620), f_q))
            mstore(0x2860, mulmod(mload(0x2840), mload(0x2660), f_q))
            mstore(
                0x2880,
                mulmod(13513867906530865119835332133273263211836799082674232843258448413103731898271, mload(0x680), f_q)
            )
            mstore(0x28a0, mulmod(mload(0x2880), 1, f_q))
            {
                let result := mulmod(mload(0xa40), mload(0x2880), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x28a0)), f_q), result, f_q)
                mstore(10432, result)
            }
            mstore(
                0x28e0,
                mulmod(8374374965308410102411073611984011876711565317741801500439755773472076597346, mload(0x680), f_q)
            )
            mstore(
                0x2900,
                mulmod(mload(0x28e0), 8374374965308410102411073611984011876711565317741801500439755773472076597347, f_q)
            )
            {
                let result := mulmod(mload(0xa40), mload(0x28e0), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x2900)), f_q), result, f_q)
                mstore(10528, result)
            }
            mstore(
                0x2940,
                mulmod(12146688980418810893951125255607130521645347193942732958664170801695864621271, mload(0x680), f_q)
            )
            mstore(0x2960, mulmod(mload(0x2940), 1, f_q))
            {
                let result := mulmod(mload(0xa40), mload(0x2940), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x2960)), f_q), result, f_q)
                mstore(10624, result)
            }
            mstore(
                0x29a0,
                mulmod(9741553891420464328295280489650144566903017206473301385034033384879943874346, mload(0x680), f_q)
            )
            mstore(
                0x29c0,
                mulmod(mload(0x29a0), 9741553891420464328295280489650144566903017206473301385034033384879943874347, f_q)
            )
            {
                let result := mulmod(mload(0xa40), mload(0x29a0), f_q)
                result := addmod(mulmod(mload(0x680), sub(f_q, mload(0x29c0)), f_q), result, f_q)
                mstore(10720, result)
            }
            mstore(0x2a00, mulmod(mload(0x2800), mload(0x2560), f_q))
            {
                let result := mulmod(mload(0xa40), 1, f_q)
                result :=
                    addmod(
                        mulmod(
                            mload(0x680), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q
                        ),
                        result,
                        f_q
                    )
                mstore(10784, result)
            }
            {
                let prod := mload(0x26c0)

                prod := mulmod(mload(0x2720), prod, f_q)
                mstore(0x2a40, prod)

                prod := mulmod(mload(0x2780), prod, f_q)
                mstore(0x2a60, prod)

                prod := mulmod(mload(0x27e0), prod, f_q)
                mstore(0x2a80, prod)

                prod := mulmod(mload(0x28c0), prod, f_q)
                mstore(0x2aa0, prod)

                prod := mulmod(mload(0x2920), prod, f_q)
                mstore(0x2ac0, prod)

                prod := mulmod(mload(0x2820), prod, f_q)
                mstore(0x2ae0, prod)

                prod := mulmod(mload(0x2980), prod, f_q)
                mstore(0x2b00, prod)

                prod := mulmod(mload(0x29e0), prod, f_q)
                mstore(0x2b20, prod)

                prod := mulmod(mload(0x2a00), prod, f_q)
                mstore(0x2b40, prod)

                prod := mulmod(mload(0x2a20), prod, f_q)
                mstore(0x2b60, prod)

                prod := mulmod(mload(0x2800), prod, f_q)
                mstore(0x2b80, prod)
            }
            mstore(0x2bc0, 32)
            mstore(0x2be0, 32)
            mstore(0x2c00, 32)
            mstore(0x2c20, mload(0x2b80))
            mstore(0x2c40, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x2c60, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x2bc0, 0xc0, 0x2ba0, 0x20), 1), success)
            {
                let inv := mload(0x2ba0)
                let v

                v := mload(0x2800)
                mstore(10240, mulmod(mload(0x2b60), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2a20)
                mstore(10784, mulmod(mload(0x2b40), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2a00)
                mstore(10752, mulmod(mload(0x2b20), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x29e0)
                mstore(10720, mulmod(mload(0x2b00), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2980)
                mstore(10624, mulmod(mload(0x2ae0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2820)
                mstore(10272, mulmod(mload(0x2ac0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2920)
                mstore(10528, mulmod(mload(0x2aa0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x28c0)
                mstore(10432, mulmod(mload(0x2a80), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x27e0)
                mstore(10208, mulmod(mload(0x2a60), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2780)
                mstore(10112, mulmod(mload(0x2a40), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2720)
                mstore(10016, mulmod(mload(0x26c0), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0x26c0, inv)
            }
            {
                let result := mload(0x26c0)
                result := addmod(mload(0x2720), result, f_q)
                result := addmod(mload(0x2780), result, f_q)
                result := addmod(mload(0x27e0), result, f_q)
                mstore(11392, result)
            }
            mstore(0x2ca0, mulmod(mload(0x2860), mload(0x2820), f_q))
            {
                let result := mload(0x28c0)
                result := addmod(mload(0x2920), result, f_q)
                mstore(11456, result)
            }
            mstore(0x2ce0, mulmod(mload(0x2860), mload(0x2a00), f_q))
            {
                let result := mload(0x2980)
                result := addmod(mload(0x29e0), result, f_q)
                mstore(11520, result)
            }
            mstore(0x2d20, mulmod(mload(0x2860), mload(0x2800), f_q))
            {
                let result := mload(0x2a20)
                mstore(11584, result)
            }
            {
                let prod := mload(0x2c80)

                prod := mulmod(mload(0x2cc0), prod, f_q)
                mstore(0x2d60, prod)

                prod := mulmod(mload(0x2d00), prod, f_q)
                mstore(0x2d80, prod)

                prod := mulmod(mload(0x2d40), prod, f_q)
                mstore(0x2da0, prod)
            }
            mstore(0x2de0, 32)
            mstore(0x2e00, 32)
            mstore(0x2e20, 32)
            mstore(0x2e40, mload(0x2da0))
            mstore(0x2e60, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x2e80, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x2de0, 0xc0, 0x2dc0, 0x20), 1), success)
            {
                let inv := mload(0x2dc0)
                let v

                v := mload(0x2d40)
                mstore(11584, mulmod(mload(0x2d80), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2d00)
                mstore(11520, mulmod(mload(0x2d60), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2cc0)
                mstore(11456, mulmod(mload(0x2c80), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0x2c80, inv)
            }
            mstore(0x2ea0, mulmod(mload(0x2ca0), mload(0x2cc0), f_q))
            mstore(0x2ec0, mulmod(mload(0x2ce0), mload(0x2d00), f_q))
            mstore(0x2ee0, mulmod(mload(0x2d20), mload(0x2d40), f_q))
            mstore(0x2f00, mulmod(mload(0x940), mload(0x940), f_q))
            mstore(0x2f20, mulmod(mload(0x2f00), mload(0x940), f_q))
            mstore(0x2f40, mulmod(mload(0x2f20), mload(0x940), f_q))
            mstore(0x2f60, mulmod(mload(0x2f40), mload(0x940), f_q))
            mstore(0x2f80, mulmod(mload(0x2f60), mload(0x940), f_q))
            mstore(0x2fa0, mulmod(mload(0x2f80), mload(0x940), f_q))
            mstore(0x2fc0, mulmod(mload(0x2fa0), mload(0x940), f_q))
            mstore(0x2fe0, mulmod(mload(0x2fc0), mload(0x940), f_q))
            mstore(0x3000, mulmod(mload(0x2fe0), mload(0x940), f_q))
            mstore(0x3020, mulmod(mload(0x9a0), mload(0x9a0), f_q))
            mstore(0x3040, mulmod(mload(0x3020), mload(0x9a0), f_q))
            mstore(0x3060, mulmod(mload(0x3040), mload(0x9a0), f_q))
            {
                let result := mulmod(mload(0x6c0), mload(0x26c0), f_q)
                result := addmod(mulmod(mload(0x6e0), mload(0x2720), f_q), result, f_q)
                result := addmod(mulmod(mload(0x700), mload(0x2780), f_q), result, f_q)
                result := addmod(mulmod(mload(0x720), mload(0x27e0), f_q), result, f_q)
                mstore(12416, result)
            }
            mstore(0x30a0, mulmod(mload(0x3080), mload(0x2c80), f_q))
            mstore(0x30c0, mulmod(sub(f_q, mload(0x30a0)), 1, f_q))
            mstore(0x30e0, mulmod(mload(0x30c0), 1, f_q))
            mstore(0x3100, mulmod(1, mload(0x2ca0), f_q))
            {
                let result := mulmod(mload(0x840), mload(0x28c0), f_q)
                result := addmod(mulmod(mload(0x860), mload(0x2920), f_q), result, f_q)
                mstore(12576, result)
            }
            mstore(0x3140, mulmod(mload(0x3120), mload(0x2ea0), f_q))
            mstore(0x3160, mulmod(sub(f_q, mload(0x3140)), 1, f_q))
            mstore(0x3180, mulmod(mload(0x3100), 1, f_q))
            {
                let result := mulmod(mload(0x880), mload(0x28c0), f_q)
                result := addmod(mulmod(mload(0x8a0), mload(0x2920), f_q), result, f_q)
                mstore(12704, result)
            }
            mstore(0x31c0, mulmod(mload(0x31a0), mload(0x2ea0), f_q))
            mstore(0x31e0, mulmod(sub(f_q, mload(0x31c0)), mload(0x940), f_q))
            mstore(0x3200, mulmod(mload(0x3100), mload(0x940), f_q))
            mstore(0x3220, addmod(mload(0x3160), mload(0x31e0), f_q))
            mstore(0x3240, mulmod(mload(0x3220), mload(0x9a0), f_q))
            mstore(0x3260, mulmod(mload(0x3180), mload(0x9a0), f_q))
            mstore(0x3280, mulmod(mload(0x3200), mload(0x9a0), f_q))
            mstore(0x32a0, addmod(mload(0x30e0), mload(0x3240), f_q))
            mstore(0x32c0, mulmod(1, mload(0x2ce0), f_q))
            {
                let result := mulmod(mload(0x8c0), mload(0x2980), f_q)
                result := addmod(mulmod(mload(0x8e0), mload(0x29e0), f_q), result, f_q)
                mstore(13024, result)
            }
            mstore(0x3300, mulmod(mload(0x32e0), mload(0x2ec0), f_q))
            mstore(0x3320, mulmod(sub(f_q, mload(0x3300)), 1, f_q))
            mstore(0x3340, mulmod(mload(0x32c0), 1, f_q))
            mstore(0x3360, mulmod(mload(0x3320), mload(0x3020), f_q))
            mstore(0x3380, mulmod(mload(0x3340), mload(0x3020), f_q))
            mstore(0x33a0, addmod(mload(0x32a0), mload(0x3360), f_q))
            mstore(0x33c0, mulmod(1, mload(0x2d20), f_q))
            {
                let result := mulmod(mload(0x900), mload(0x2a20), f_q)
                mstore(13280, result)
            }
            mstore(0x3400, mulmod(mload(0x33e0), mload(0x2ee0), f_q))
            mstore(0x3420, mulmod(sub(f_q, mload(0x3400)), 1, f_q))
            mstore(0x3440, mulmod(mload(0x33c0), 1, f_q))
            {
                let result := mulmod(mload(0x740), mload(0x2a20), f_q)
                mstore(13408, result)
            }
            mstore(0x3480, mulmod(mload(0x3460), mload(0x2ee0), f_q))
            mstore(0x34a0, mulmod(sub(f_q, mload(0x3480)), mload(0x940), f_q))
            mstore(0x34c0, mulmod(mload(0x33c0), mload(0x940), f_q))
            mstore(0x34e0, addmod(mload(0x3420), mload(0x34a0), f_q))
            {
                let result := mulmod(mload(0x760), mload(0x2a20), f_q)
                mstore(13568, result)
            }
            mstore(0x3520, mulmod(mload(0x3500), mload(0x2ee0), f_q))
            mstore(0x3540, mulmod(sub(f_q, mload(0x3520)), mload(0x2f00), f_q))
            mstore(0x3560, mulmod(mload(0x33c0), mload(0x2f00), f_q))
            mstore(0x3580, addmod(mload(0x34e0), mload(0x3540), f_q))
            {
                let result := mulmod(mload(0x780), mload(0x2a20), f_q)
                mstore(13728, result)
            }
            mstore(0x35c0, mulmod(mload(0x35a0), mload(0x2ee0), f_q))
            mstore(0x35e0, mulmod(sub(f_q, mload(0x35c0)), mload(0x2f20), f_q))
            mstore(0x3600, mulmod(mload(0x33c0), mload(0x2f20), f_q))
            mstore(0x3620, addmod(mload(0x3580), mload(0x35e0), f_q))
            {
                let result := mulmod(mload(0x7a0), mload(0x2a20), f_q)
                mstore(13888, result)
            }
            mstore(0x3660, mulmod(mload(0x3640), mload(0x2ee0), f_q))
            mstore(0x3680, mulmod(sub(f_q, mload(0x3660)), mload(0x2f40), f_q))
            mstore(0x36a0, mulmod(mload(0x33c0), mload(0x2f40), f_q))
            mstore(0x36c0, addmod(mload(0x3620), mload(0x3680), f_q))
            {
                let result := mulmod(mload(0x7e0), mload(0x2a20), f_q)
                mstore(14048, result)
            }
            mstore(0x3700, mulmod(mload(0x36e0), mload(0x2ee0), f_q))
            mstore(0x3720, mulmod(sub(f_q, mload(0x3700)), mload(0x2f60), f_q))
            mstore(0x3740, mulmod(mload(0x33c0), mload(0x2f60), f_q))
            mstore(0x3760, addmod(mload(0x36c0), mload(0x3720), f_q))
            {
                let result := mulmod(mload(0x800), mload(0x2a20), f_q)
                mstore(14208, result)
            }
            mstore(0x37a0, mulmod(mload(0x3780), mload(0x2ee0), f_q))
            mstore(0x37c0, mulmod(sub(f_q, mload(0x37a0)), mload(0x2f80), f_q))
            mstore(0x37e0, mulmod(mload(0x33c0), mload(0x2f80), f_q))
            mstore(0x3800, addmod(mload(0x3760), mload(0x37c0), f_q))
            {
                let result := mulmod(mload(0x820), mload(0x2a20), f_q)
                mstore(14368, result)
            }
            mstore(0x3840, mulmod(mload(0x3820), mload(0x2ee0), f_q))
            mstore(0x3860, mulmod(sub(f_q, mload(0x3840)), mload(0x2fa0), f_q))
            mstore(0x3880, mulmod(mload(0x33c0), mload(0x2fa0), f_q))
            mstore(0x38a0, addmod(mload(0x3800), mload(0x3860), f_q))
            mstore(0x38c0, mulmod(mload(0x2480), mload(0x2d20), f_q))
            mstore(0x38e0, mulmod(mload(0x24a0), mload(0x2d20), f_q))
            mstore(0x3900, mulmod(mload(0x24c0), mload(0x2d20), f_q))
            {
                let result := mulmod(mload(0x24e0), mload(0x2a20), f_q)
                mstore(14624, result)
            }
            mstore(0x3940, mulmod(mload(0x3920), mload(0x2ee0), f_q))
            mstore(0x3960, mulmod(sub(f_q, mload(0x3940)), mload(0x2fc0), f_q))
            mstore(0x3980, mulmod(mload(0x33c0), mload(0x2fc0), f_q))
            mstore(0x39a0, mulmod(mload(0x38c0), mload(0x2fc0), f_q))
            mstore(0x39c0, mulmod(mload(0x38e0), mload(0x2fc0), f_q))
            mstore(0x39e0, mulmod(mload(0x3900), mload(0x2fc0), f_q))
            mstore(0x3a00, addmod(mload(0x38a0), mload(0x3960), f_q))
            {
                let result := mulmod(mload(0x7c0), mload(0x2a20), f_q)
                mstore(14880, result)
            }
            mstore(0x3a40, mulmod(mload(0x3a20), mload(0x2ee0), f_q))
            mstore(0x3a60, mulmod(sub(f_q, mload(0x3a40)), mload(0x2fe0), f_q))
            mstore(0x3a80, mulmod(mload(0x33c0), mload(0x2fe0), f_q))
            mstore(0x3aa0, addmod(mload(0x3a00), mload(0x3a60), f_q))
            mstore(0x3ac0, mulmod(mload(0x3aa0), mload(0x3040), f_q))
            mstore(0x3ae0, mulmod(mload(0x3440), mload(0x3040), f_q))
            mstore(0x3b00, mulmod(mload(0x34c0), mload(0x3040), f_q))
            mstore(0x3b20, mulmod(mload(0x3560), mload(0x3040), f_q))
            mstore(0x3b40, mulmod(mload(0x3600), mload(0x3040), f_q))
            mstore(0x3b60, mulmod(mload(0x36a0), mload(0x3040), f_q))
            mstore(0x3b80, mulmod(mload(0x3740), mload(0x3040), f_q))
            mstore(0x3ba0, mulmod(mload(0x37e0), mload(0x3040), f_q))
            mstore(0x3bc0, mulmod(mload(0x3880), mload(0x3040), f_q))
            mstore(0x3be0, mulmod(mload(0x3980), mload(0x3040), f_q))
            mstore(0x3c00, mulmod(mload(0x39a0), mload(0x3040), f_q))
            mstore(0x3c20, mulmod(mload(0x39c0), mload(0x3040), f_q))
            mstore(0x3c40, mulmod(mload(0x39e0), mload(0x3040), f_q))
            mstore(0x3c60, mulmod(mload(0x3a80), mload(0x3040), f_q))
            mstore(0x3c80, addmod(mload(0x33a0), mload(0x3ac0), f_q))
            mstore(0x3ca0, mulmod(1, mload(0x2860), f_q))
            mstore(0x3cc0, mulmod(1, mload(0xa40), f_q))
            mstore(0x3ce0, 0x0000000000000000000000000000000000000000000000000000000000000001)
            mstore(0x3d00, 0x0000000000000000000000000000000000000000000000000000000000000002)
            mstore(0x3d20, mload(0x3c80))
            success := and(eq(staticcall(gas(), 0x7, 0x3ce0, 0x60, 0x3ce0, 0x40), 1), success)
            mstore(0x3d40, mload(0x3ce0))
            mstore(0x3d60, mload(0x3d00))
            mstore(0x3d80, mload(0x260))
            mstore(0x3da0, mload(0x280))
            success := and(eq(staticcall(gas(), 0x6, 0x3d40, 0x80, 0x3d40, 0x40), 1), success)
            mstore(0x3dc0, mload(0x440))
            mstore(0x3de0, mload(0x460))
            mstore(0x3e00, mload(0x3260))
            success := and(eq(staticcall(gas(), 0x7, 0x3dc0, 0x60, 0x3dc0, 0x40), 1), success)
            mstore(0x3e20, mload(0x3d40))
            mstore(0x3e40, mload(0x3d60))
            mstore(0x3e60, mload(0x3dc0))
            mstore(0x3e80, mload(0x3de0))
            success := and(eq(staticcall(gas(), 0x6, 0x3e20, 0x80, 0x3e20, 0x40), 1), success)
            mstore(0x3ea0, mload(0x480))
            mstore(0x3ec0, mload(0x4a0))
            mstore(0x3ee0, mload(0x3280))
            success := and(eq(staticcall(gas(), 0x7, 0x3ea0, 0x60, 0x3ea0, 0x40), 1), success)
            mstore(0x3f00, mload(0x3e20))
            mstore(0x3f20, mload(0x3e40))
            mstore(0x3f40, mload(0x3ea0))
            mstore(0x3f60, mload(0x3ec0))
            success := and(eq(staticcall(gas(), 0x6, 0x3f00, 0x80, 0x3f00, 0x40), 1), success)
            mstore(0x3f80, mload(0x300))
            mstore(0x3fa0, mload(0x320))
            mstore(0x3fc0, mload(0x3380))
            success := and(eq(staticcall(gas(), 0x7, 0x3f80, 0x60, 0x3f80, 0x40), 1), success)
            mstore(0x3fe0, mload(0x3f00))
            mstore(0x4000, mload(0x3f20))
            mstore(0x4020, mload(0x3f80))
            mstore(0x4040, mload(0x3fa0))
            success := and(eq(staticcall(gas(), 0x6, 0x3fe0, 0x80, 0x3fe0, 0x40), 1), success)
            mstore(0x4060, mload(0x340))
            mstore(0x4080, mload(0x360))
            mstore(0x40a0, mload(0x3ae0))
            success := and(eq(staticcall(gas(), 0x7, 0x4060, 0x60, 0x4060, 0x40), 1), success)
            mstore(0x40c0, mload(0x3fe0))
            mstore(0x40e0, mload(0x4000))
            mstore(0x4100, mload(0x4060))
            mstore(0x4120, mload(0x4080))
            success := and(eq(staticcall(gas(), 0x6, 0x40c0, 0x80, 0x40c0, 0x40), 1), success)
            mstore(0x4140, 0x2e2c62958327624f1e912d84cbcf289ef1b4827837d2770a2050d58805ff0ba5)
            mstore(0x4160, 0x003f7e15335234a3c73cad4c8b72d3feaf4c22d3cf79e489a6cf294a13d09002)
            mstore(0x4180, mload(0x3b00))
            success := and(eq(staticcall(gas(), 0x7, 0x4140, 0x60, 0x4140, 0x40), 1), success)
            mstore(0x41a0, mload(0x40c0))
            mstore(0x41c0, mload(0x40e0))
            mstore(0x41e0, mload(0x4140))
            mstore(0x4200, mload(0x4160))
            success := and(eq(staticcall(gas(), 0x6, 0x41a0, 0x80, 0x41a0, 0x40), 1), success)
            mstore(0x4220, 0x2eb40e2b0c13a6f4b989cffa9dbc452447bfd9f04a79f6379aefea8c9850a550)
            mstore(0x4240, 0x0efe5496541e2bd648d490f11ad542e1dec3127f818b8065843d0dd81358416c)
            mstore(0x4260, mload(0x3b20))
            success := and(eq(staticcall(gas(), 0x7, 0x4220, 0x60, 0x4220, 0x40), 1), success)
            mstore(0x4280, mload(0x41a0))
            mstore(0x42a0, mload(0x41c0))
            mstore(0x42c0, mload(0x4220))
            mstore(0x42e0, mload(0x4240))
            success := and(eq(staticcall(gas(), 0x6, 0x4280, 0x80, 0x4280, 0x40), 1), success)
            mstore(0x4300, 0x1f21fd61145ead9072c6b3d3a253db4249828372afed456f6ed8dbfb14531159)
            mstore(0x4320, 0x213fac86d1de445df5b670fb775e61021061b9b99e446d609b580f03f4125529)
            mstore(0x4340, mload(0x3b40))
            success := and(eq(staticcall(gas(), 0x7, 0x4300, 0x60, 0x4300, 0x40), 1), success)
            mstore(0x4360, mload(0x4280))
            mstore(0x4380, mload(0x42a0))
            mstore(0x43a0, mload(0x4300))
            mstore(0x43c0, mload(0x4320))
            success := and(eq(staticcall(gas(), 0x6, 0x4360, 0x80, 0x4360, 0x40), 1), success)
            mstore(0x43e0, 0x006067601d43cabf1c84e9a4df42c4067affbc2588fb2bfed01ebcf5f6281f1b)
            mstore(0x4400, 0x0c8dbf13eab08fb3151c8c35d8ce7a0c0ba9271dc7b84859cce1bcc8a2851ee2)
            mstore(0x4420, mload(0x3b60))
            success := and(eq(staticcall(gas(), 0x7, 0x43e0, 0x60, 0x43e0, 0x40), 1), success)
            mstore(0x4440, mload(0x4360))
            mstore(0x4460, mload(0x4380))
            mstore(0x4480, mload(0x43e0))
            mstore(0x44a0, mload(0x4400))
            success := and(eq(staticcall(gas(), 0x6, 0x4440, 0x80, 0x4440, 0x40), 1), success)
            mstore(0x44c0, 0x0023cf36ddddf5a021fe5ea2e28331c829d80e8b5ba4d4b8caacdced7ebbc7b2)
            mstore(0x44e0, 0x1fc3721cef42bc6a7f47c43ed3a133f4bb9a9222dbf0e699806e49a43b74d4ab)
            mstore(0x4500, mload(0x3b80))
            success := and(eq(staticcall(gas(), 0x7, 0x44c0, 0x60, 0x44c0, 0x40), 1), success)
            mstore(0x4520, mload(0x4440))
            mstore(0x4540, mload(0x4460))
            mstore(0x4560, mload(0x44c0))
            mstore(0x4580, mload(0x44e0))
            success := and(eq(staticcall(gas(), 0x6, 0x4520, 0x80, 0x4520, 0x40), 1), success)
            mstore(0x45a0, 0x1b51ee2038735da053903a18c32e3bd3150d289f6b95fb0d2a22b510ee4426a8)
            mstore(0x45c0, 0x27bfd563a8a95f1aefa028638fa0eb9a14cc3303cba0867808e6017707cc4ebc)
            mstore(0x45e0, mload(0x3ba0))
            success := and(eq(staticcall(gas(), 0x7, 0x45a0, 0x60, 0x45a0, 0x40), 1), success)
            mstore(0x4600, mload(0x4520))
            mstore(0x4620, mload(0x4540))
            mstore(0x4640, mload(0x45a0))
            mstore(0x4660, mload(0x45c0))
            success := and(eq(staticcall(gas(), 0x6, 0x4600, 0x80, 0x4600, 0x40), 1), success)
            mstore(0x4680, 0x1915583aea9c9cdf4e21b4011ecc863792e6cc400a50d49360313da28ebfe8b0)
            mstore(0x46a0, 0x21e7be0dc27687e3f27bfd06cb043f7028adc2033722d8c21cbd9607d235264a)
            mstore(0x46c0, mload(0x3bc0))
            success := and(eq(staticcall(gas(), 0x7, 0x4680, 0x60, 0x4680, 0x40), 1), success)
            mstore(0x46e0, mload(0x4600))
            mstore(0x4700, mload(0x4620))
            mstore(0x4720, mload(0x4680))
            mstore(0x4740, mload(0x46a0))
            success := and(eq(staticcall(gas(), 0x6, 0x46e0, 0x80, 0x46e0, 0x40), 1), success)
            mstore(0x4760, mload(0x560))
            mstore(0x4780, mload(0x580))
            mstore(0x47a0, mload(0x3be0))
            success := and(eq(staticcall(gas(), 0x7, 0x4760, 0x60, 0x4760, 0x40), 1), success)
            mstore(0x47c0, mload(0x46e0))
            mstore(0x47e0, mload(0x4700))
            mstore(0x4800, mload(0x4760))
            mstore(0x4820, mload(0x4780))
            success := and(eq(staticcall(gas(), 0x6, 0x47c0, 0x80, 0x47c0, 0x40), 1), success)
            mstore(0x4840, mload(0x5a0))
            mstore(0x4860, mload(0x5c0))
            mstore(0x4880, mload(0x3c00))
            success := and(eq(staticcall(gas(), 0x7, 0x4840, 0x60, 0x4840, 0x40), 1), success)
            mstore(0x48a0, mload(0x47c0))
            mstore(0x48c0, mload(0x47e0))
            mstore(0x48e0, mload(0x4840))
            mstore(0x4900, mload(0x4860))
            success := and(eq(staticcall(gas(), 0x6, 0x48a0, 0x80, 0x48a0, 0x40), 1), success)
            mstore(0x4920, mload(0x5e0))
            mstore(0x4940, mload(0x600))
            mstore(0x4960, mload(0x3c20))
            success := and(eq(staticcall(gas(), 0x7, 0x4920, 0x60, 0x4920, 0x40), 1), success)
            mstore(0x4980, mload(0x48a0))
            mstore(0x49a0, mload(0x48c0))
            mstore(0x49c0, mload(0x4920))
            mstore(0x49e0, mload(0x4940))
            success := and(eq(staticcall(gas(), 0x6, 0x4980, 0x80, 0x4980, 0x40), 1), success)
            mstore(0x4a00, mload(0x620))
            mstore(0x4a20, mload(0x640))
            mstore(0x4a40, mload(0x3c40))
            success := and(eq(staticcall(gas(), 0x7, 0x4a00, 0x60, 0x4a00, 0x40), 1), success)
            mstore(0x4a60, mload(0x4980))
            mstore(0x4a80, mload(0x49a0))
            mstore(0x4aa0, mload(0x4a00))
            mstore(0x4ac0, mload(0x4a20))
            success := and(eq(staticcall(gas(), 0x6, 0x4a60, 0x80, 0x4a60, 0x40), 1), success)
            mstore(0x4ae0, mload(0x4c0))
            mstore(0x4b00, mload(0x4e0))
            mstore(0x4b20, mload(0x3c60))
            success := and(eq(staticcall(gas(), 0x7, 0x4ae0, 0x60, 0x4ae0, 0x40), 1), success)
            mstore(0x4b40, mload(0x4a60))
            mstore(0x4b60, mload(0x4a80))
            mstore(0x4b80, mload(0x4ae0))
            mstore(0x4ba0, mload(0x4b00))
            success := and(eq(staticcall(gas(), 0x6, 0x4b40, 0x80, 0x4b40, 0x40), 1), success)
            mstore(0x4bc0, mload(0x9e0))
            mstore(0x4be0, mload(0xa00))
            mstore(0x4c00, sub(f_q, mload(0x3ca0)))
            success := and(eq(staticcall(gas(), 0x7, 0x4bc0, 0x60, 0x4bc0, 0x40), 1), success)
            mstore(0x4c20, mload(0x4b40))
            mstore(0x4c40, mload(0x4b60))
            mstore(0x4c60, mload(0x4bc0))
            mstore(0x4c80, mload(0x4be0))
            success := and(eq(staticcall(gas(), 0x6, 0x4c20, 0x80, 0x4c20, 0x40), 1), success)
            mstore(0x4ca0, mload(0xa80))
            mstore(0x4cc0, mload(0xaa0))
            mstore(0x4ce0, mload(0x3cc0))
            success := and(eq(staticcall(gas(), 0x7, 0x4ca0, 0x60, 0x4ca0, 0x40), 1), success)
            mstore(0x4d00, mload(0x4c20))
            mstore(0x4d20, mload(0x4c40))
            mstore(0x4d40, mload(0x4ca0))
            mstore(0x4d60, mload(0x4cc0))
            success := and(eq(staticcall(gas(), 0x6, 0x4d00, 0x80, 0x4d00, 0x40), 1), success)
            mstore(0x4d80, mload(0x4d00))
            mstore(0x4da0, mload(0x4d20))
            mstore(0x4dc0, mload(0xa80))
            mstore(0x4de0, mload(0xaa0))
            mstore(0x4e00, mload(0xac0))
            mstore(0x4e20, mload(0xae0))
            mstore(0x4e40, mload(0xb00))
            mstore(0x4e60, mload(0xb20))
            mstore(0x4e80, keccak256(0x4d80, 256))
            mstore(20128, mod(mload(20096), f_q))
            mstore(0x4ec0, mulmod(mload(0x4ea0), mload(0x4ea0), f_q))
            mstore(0x4ee0, mulmod(1, mload(0x4ea0), f_q))
            mstore(0x4f00, mload(0x4e00))
            mstore(0x4f20, mload(0x4e20))
            mstore(0x4f40, mload(0x4ee0))
            success := and(eq(staticcall(gas(), 0x7, 0x4f00, 0x60, 0x4f00, 0x40), 1), success)
            mstore(0x4f60, mload(0x4d80))
            mstore(0x4f80, mload(0x4da0))
            mstore(0x4fa0, mload(0x4f00))
            mstore(0x4fc0, mload(0x4f20))
            success := and(eq(staticcall(gas(), 0x6, 0x4f60, 0x80, 0x4f60, 0x40), 1), success)
            mstore(0x4fe0, mload(0x4e40))
            mstore(0x5000, mload(0x4e60))
            mstore(0x5020, mload(0x4ee0))
            success := and(eq(staticcall(gas(), 0x7, 0x4fe0, 0x60, 0x4fe0, 0x40), 1), success)
            mstore(0x5040, mload(0x4dc0))
            mstore(0x5060, mload(0x4de0))
            mstore(0x5080, mload(0x4fe0))
            mstore(0x50a0, mload(0x5000))
            success := and(eq(staticcall(gas(), 0x6, 0x5040, 0x80, 0x5040, 0x40), 1), success)
            mstore(0x50c0, mload(0x4f60))
            mstore(0x50e0, mload(0x4f80))
            mstore(0x5100, 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2)
            mstore(0x5120, 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed)
            mstore(0x5140, 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b)
            mstore(0x5160, 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa)
            mstore(0x5180, mload(0x5040))
            mstore(0x51a0, mload(0x5060))
            mstore(0x51c0, 0x172aa93c41f16e1e04d62ac976a5d945f4be0acab990c6dc19ac4a7cf68bf77b)
            mstore(0x51e0, 0x2ae0c8c3a090f7200ff398ee9845bbae8f8c1445ae7b632212775f60a0e21600)
            mstore(0x5200, 0x190fa476a5b352809ed41d7a0d7fe12b8f685e3c12a6d83855dba27aaf469643)
            mstore(0x5220, 0x1c0a500618907df9e4273d5181e31088deb1f05132de037cbfe73888f97f77c9)
            success := and(eq(staticcall(gas(), 0x8, 0x50c0, 0x180, 0x50c0, 0x20), 1), success)
            success := and(eq(mload(0x50c0), 1), success)

            // Revert if anything fails
            if iszero(success) { revert(0, 0) }

            // Return empty bytes on success
            return(0, 0)
        }
    }
}

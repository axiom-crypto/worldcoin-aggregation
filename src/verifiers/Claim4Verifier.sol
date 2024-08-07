// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Claim4Verifier {
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
            mstore(0x2e0, mod(calldataload(0x240), f_q))
            mstore(0x300, mod(calldataload(0x260), f_q))
            mstore(0x320, mod(calldataload(0x280), f_q))
            mstore(0x340, mod(calldataload(0x2a0), f_q))
            mstore(0x360, mod(calldataload(0x2c0), f_q))
            mstore(0x380, mod(calldataload(0x2e0), f_q))
            mstore(0x3a0, mod(calldataload(0x300), f_q))
            mstore(0x80, 11985152612602924806915379286109290280026179843004438827061179092789083795063)

            {
                let x := calldataload(0x320)
                mstore(0x3c0, x)
                let y := calldataload(0x340)
                mstore(0x3e0, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x400, keccak256(0x80, 896))
            {
                let hash := mload(0x400)
                mstore(0x420, mod(hash, f_q))
                mstore(0x440, hash)
            }

            {
                let x := calldataload(0x360)
                mstore(0x460, x)
                let y := calldataload(0x380)
                mstore(0x480, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x3a0)
                mstore(0x4a0, x)
                let y := calldataload(0x3c0)
                mstore(0x4c0, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x4e0, keccak256(0x440, 160))
            {
                let hash := mload(0x4e0)
                mstore(0x500, mod(hash, f_q))
                mstore(0x520, hash)
            }
            mstore8(1344, 1)
            mstore(0x540, keccak256(0x520, 33))
            {
                let hash := mload(0x540)
                mstore(0x560, mod(hash, f_q))
                mstore(0x580, hash)
            }

            {
                let x := calldataload(0x3e0)
                mstore(0x5a0, x)
                let y := calldataload(0x400)
                mstore(0x5c0, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x420)
                mstore(0x5e0, x)
                let y := calldataload(0x440)
                mstore(0x600, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x460)
                mstore(0x620, x)
                let y := calldataload(0x480)
                mstore(0x640, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x660, keccak256(0x580, 224))
            {
                let hash := mload(0x660)
                mstore(0x680, mod(hash, f_q))
                mstore(0x6a0, hash)
            }

            {
                let x := calldataload(0x4a0)
                mstore(0x6c0, x)
                let y := calldataload(0x4c0)
                mstore(0x6e0, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x4e0)
                mstore(0x700, x)
                let y := calldataload(0x500)
                mstore(0x720, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x520)
                mstore(0x740, x)
                let y := calldataload(0x540)
                mstore(0x760, y)
                success := and(validate_ec_point(x, y), success)
            }

            {
                let x := calldataload(0x560)
                mstore(0x780, x)
                let y := calldataload(0x580)
                mstore(0x7a0, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0x7c0, keccak256(0x6a0, 288))
            {
                let hash := mload(0x7c0)
                mstore(0x7e0, mod(hash, f_q))
                mstore(0x800, hash)
            }
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
            mstore(0x9a0, mod(calldataload(0x720), f_q))
            mstore(0x9c0, mod(calldataload(0x740), f_q))
            mstore(0x9e0, mod(calldataload(0x760), f_q))
            mstore(0xa00, mod(calldataload(0x780), f_q))
            mstore(0xa20, mod(calldataload(0x7a0), f_q))
            mstore(0xa40, mod(calldataload(0x7c0), f_q))
            mstore(0xa60, mod(calldataload(0x7e0), f_q))
            mstore(0xa80, keccak256(0x800, 640))
            {
                let hash := mload(0xa80)
                mstore(0xaa0, mod(hash, f_q))
                mstore(0xac0, hash)
            }
            mstore8(2784, 1)
            mstore(0xae0, keccak256(0xac0, 33))
            {
                let hash := mload(0xae0)
                mstore(0xb00, mod(hash, f_q))
                mstore(0xb20, hash)
            }

            {
                let x := calldataload(0x800)
                mstore(0xb40, x)
                let y := calldataload(0x820)
                mstore(0xb60, y)
                success := and(validate_ec_point(x, y), success)
            }
            mstore(0xb80, keccak256(0xb20, 96))
            {
                let hash := mload(0xb80)
                mstore(0xba0, mod(hash, f_q))
                mstore(0xbc0, hash)
            }

            {
                let x := calldataload(0x840)
                mstore(0xbe0, x)
                let y := calldataload(0x860)
                mstore(0xc00, y)
                success := and(validate_ec_point(x, y), success)
            }
            {
                let x := mload(0xa0)
                x := add(x, shl(88, mload(0xc0)))
                x := add(x, shl(176, mload(0xe0)))
                mstore(3104, x)
                let y := mload(0x100)
                y := add(y, shl(88, mload(0x120)))
                y := add(y, shl(176, mload(0x140)))
                mstore(3136, y)

                success := and(validate_ec_point(x, y), success)
            }
            {
                let x := mload(0x160)
                x := add(x, shl(88, mload(0x180)))
                x := add(x, shl(176, mload(0x1a0)))
                mstore(3168, x)
                let y := mload(0x1c0)
                y := add(y, shl(88, mload(0x1e0)))
                y := add(y, shl(176, mload(0x200)))
                mstore(3200, y)

                success := and(validate_ec_point(x, y), success)
            }
            mstore(0xca0, mulmod(mload(0x7e0), mload(0x7e0), f_q))
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
            mstore(0xea0, mulmod(mload(0xe80), mload(0xe80), f_q))
            mstore(0xec0, mulmod(mload(0xea0), mload(0xea0), f_q))
            mstore(0xee0, mulmod(mload(0xec0), mload(0xec0), f_q))
            mstore(0xf00, mulmod(mload(0xee0), mload(0xee0), f_q))
            mstore(0xf20, mulmod(mload(0xf00), mload(0xf00), f_q))
            mstore(0xf40, mulmod(mload(0xf20), mload(0xf20), f_q))
            mstore(
                0xf60,
                addmod(mload(0xf40), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q)
            )
            mstore(
                0xf80,
                mulmod(mload(0xf60), 21888237653275510688422624196183639687472264873923820041627027729598873448513, f_q)
            )
            mstore(
                0xfa0,
                mulmod(mload(0xf80), 13225785879531581993054172815365636627224369411478295502904397545373139154045, f_q)
            )
            mstore(
                0xfc0,
                addmod(mload(0x7e0), 8662456992307693229192232929891638461323994988937738840793806641202669341572, f_q)
            )
            mstore(
                0xfe0,
                mulmod(mload(0xf80), 10939663269433627367777756708678102241564365262857670666700619874077960926249, f_q)
            )
            mstore(
                0x1000,
                addmod(mload(0x7e0), 10948579602405647854468649036579172846983999137558363676997584312497847569368, f_q)
            )
            mstore(
                0x1020,
                mulmod(mload(0xf80), 11016257578652593686382655500910603527869149377564754001549454008164059876499, f_q)
            )
            mstore(
                0x1040,
                addmod(mload(0x7e0), 10871985293186681535863750244346671560679215022851280342148750178411748619118, f_q)
            )
            mstore(
                0x1060,
                mulmod(mload(0xf80), 15402826414547299628414612080036060696555554914079673875872749760617770134879, f_q)
            )
            mstore(
                0x1080,
                addmod(mload(0x7e0), 6485416457291975593831793665221214391992809486336360467825454425958038360738, f_q)
            )
            mstore(
                0x10a0,
                mulmod(mload(0xf80), 21710372849001950800533397158415938114909991150039389063546734567764856596059, f_q)
            )
            mstore(
                0x10c0,
                addmod(mload(0x7e0), 177870022837324421713008586841336973638373250376645280151469618810951899558, f_q)
            )
            mstore(
                0x10e0,
                mulmod(mload(0xf80), 2785514556381676080176937710880804108647911392478702105860685610379369825016, f_q)
            )
            mstore(
                0x1100,
                addmod(mload(0x7e0), 19102728315457599142069468034376470979900453007937332237837518576196438670601, f_q)
            )
            mstore(
                0x1120,
                mulmod(mload(0xf80), 8734126352828345679573237859165904705806588461301144420590422589042130041188, f_q)
            )
            mstore(
                0x1140,
                addmod(mload(0x7e0), 13154116519010929542673167886091370382741775939114889923107781597533678454429, f_q)
            )
            mstore(0x1160, mulmod(mload(0xf80), 1, f_q))
            mstore(
                0x1180,
                addmod(mload(0x7e0), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q)
            )
            mstore(
                0x11a0,
                mulmod(mload(0xf80), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q)
            )
            mstore(
                0x11c0,
                addmod(mload(0x7e0), 10676941854703594198666993839846402519342119846958189386823924046696287912227, f_q)
            )
            mstore(
                0x11e0,
                mulmod(mload(0xf80), 1426404432721484388505361748317961535523355871255605456897797744433766488507, f_q)
            )
            mstore(
                0x1200,
                addmod(mload(0x7e0), 20461838439117790833741043996939313553025008529160428886800406442142042007110, f_q)
            )
            mstore(
                0x1220,
                mulmod(mload(0xf80), 12619617507853212586156872920672483948819476989779550311307282715684870266992, f_q)
            )
            mstore(
                0x1240,
                addmod(mload(0x7e0), 9268625363986062636089532824584791139728887410636484032390921470890938228625, f_q)
            )
            mstore(
                0x1260,
                mulmod(mload(0xf80), 19032961837237948602743626455740240236231119053033140765040043513661803148152, f_q)
            )
            mstore(
                0x1280,
                addmod(mload(0x7e0), 2855281034601326619502779289517034852317245347382893578658160672914005347465, f_q)
            )
            mstore(
                0x12a0,
                mulmod(mload(0xf80), 915149353520972163646494413843788069594022902357002628455555785223409501882, f_q)
            )
            mstore(
                0x12c0,
                addmod(mload(0x7e0), 20973093518318303058599911331413487018954341498059031715242648401352398993735, f_q)
            )
            mstore(
                0x12e0,
                mulmod(mload(0xf80), 3766081621734395783232337525162072736827576297943013392955872170138036189193, f_q)
            )
            mstore(
                0x1300,
                addmod(mload(0x7e0), 18122161250104879439014068220095202351720788102473020950742332016437772306424, f_q)
            )
            mstore(
                0x1320,
                mulmod(mload(0xf80), 4245441013247250116003069945606352967193023389718465410501109428393342802981, f_q)
            )
            mstore(
                0x1340,
                addmod(mload(0x7e0), 17642801858592025106243335799650922121355341010697568933197094758182465692636, f_q)
            )
            mstore(
                0x1360,
                mulmod(mload(0xf80), 5854133144571823792863860130267644613802765696134002830362054821530146160770, f_q)
            )
            mstore(
                0x1380,
                addmod(mload(0x7e0), 16034109727267451429382545614989630474745598704282031513336149365045662334847, f_q)
            )
            mstore(
                0x13a0,
                mulmod(mload(0xf80), 5980488956150442207659150513163747165544364597008566989111579977672498964212, f_q)
            )
            mstore(
                0x13c0,
                addmod(mload(0x7e0), 15907753915688833014587255232093527923003999803407467354586624208903309531405, f_q)
            )
            mstore(
                0x13e0,
                mulmod(mload(0xf80), 14557038802599140430182096396825290815503940951075961210638273254419942783582, f_q)
            )
            mstore(
                0x1400,
                addmod(mload(0x7e0), 7331204069240134792064309348431984273044423449340073133059930932155865712035, f_q)
            )
            mstore(
                0x1420,
                mulmod(mload(0xf80), 13553911191894110065493137367144919847521088405945523452288398666974237857208, f_q)
            )
            mstore(
                0x1440,
                addmod(mload(0x7e0), 8334331679945165156753268378112355241027275994470510891409805519601570638409, f_q)
            )
            mstore(
                0x1460,
                mulmod(mload(0xf80), 9697063347556872083384215826199993067635178715531258559890418744774301211662, f_q)
            )
            mstore(
                0x1480,
                addmod(mload(0x7e0), 12191179524282403138862189919057282020913185684884775783807785441801507283955, f_q)
            )
            mstore(
                0x14a0,
                mulmod(mload(0xf80), 10807735674816066981985242612061336605021639643453679977988966079770672437131, f_q)
            )
            mstore(
                0x14c0,
                addmod(mload(0x7e0), 11080507197023208240261163133195938483526724756962354365709238106805136058486, f_q)
            )
            mstore(
                0x14e0,
                mulmod(mload(0xf80), 12459868075641381822485233712013080087763946065665469821362892189399541605692, f_q)
            )
            mstore(
                0x1500,
                addmod(mload(0x7e0), 9428374796197893399761172033244195000784418334750564522335311997176266889925, f_q)
            )
            mstore(
                0x1520,
                mulmod(mload(0xf80), 16038300751658239075779628684257016433412502747804121525056508685985277092575, f_q)
            )
            mstore(
                0x1540,
                addmod(mload(0x7e0), 5849942120181036146466777061000258655135861652611912818641695500590531403042, f_q)
            )
            mstore(
                0x1560,
                mulmod(mload(0xf80), 6955697244493336113861667751840378876927906302623587437721024018233754910398, f_q)
            )
            mstore(
                0x1580,
                addmod(mload(0x7e0), 14932545627345939108384737993416896211620458097792446905977180168342053585219, f_q)
            )
            mstore(
                0x15a0,
                mulmod(mload(0xf80), 13498745591877810872211159461644682954739332524336278910448604883789771736885, f_q)
            )
            mstore(
                0x15c0,
                addmod(mload(0x7e0), 8389497279961464350035246283612592133809031876079755433249599302786036758732, f_q)
            )
            mstore(
                0x15e0,
                mulmod(mload(0xf80), 20345677989844117909528750049476969581182118546166966482506114734614108237981, f_q)
            )
            mstore(
                0x1600,
                addmod(mload(0x7e0), 1542564881995157312717655695780305507366245854249067861192089451961700257636, f_q)
            )
            mstore(
                0x1620,
                mulmod(mload(0xf80), 790608022292213379425324383664216541739009722347092850716054055768832299157, f_q)
            )
            mstore(
                0x1640,
                addmod(mload(0x7e0), 21097634849547061842821081361593058546809354678068941492982150130806976196460, f_q)
            )
            mstore(
                0x1660,
                mulmod(mload(0xf80), 5289443209903185443361862148540090689648485914368835830972895623576469023722, f_q)
            )
            mstore(
                0x1680,
                addmod(mload(0x7e0), 16598799661936089778884543596717184398899878486047198512725308562999339471895, f_q)
            )
            mstore(
                0x16a0,
                mulmod(mload(0xf80), 15161189183906287273290738379431332336600234154579306802151507052820126345529, f_q)
            )
            mstore(
                0x16c0,
                addmod(mload(0x7e0), 6727053687932987948955667365825942751948130245836727541546697133755682150088, f_q)
            )
            mstore(
                0x16e0,
                mulmod(mload(0xf80), 557567375339945239933617516585967620814823575807691402619711360028043331811, f_q)
            )
            mstore(
                0x1700,
                addmod(mload(0x7e0), 21330675496499329982312788228671307467733540824608342941078492826547765163806, f_q)
            )
            mstore(
                0x1720,
                mulmod(mload(0xf80), 16611719114775828483319365659907682366622074960672212059891361227499450055959, f_q)
            )
            mstore(
                0x1740,
                addmod(mload(0x7e0), 5276523757063446738927040085349592721926289439743822283806842959076358439658, f_q)
            )
            mstore(
                0x1760,
                mulmod(mload(0xf80), 4509404676247677387317362072810231899718070082381452255950861037254608304934, f_q)
            )
            mstore(
                0x1780,
                addmod(mload(0x7e0), 17378838195591597834929043672447043188830294318034582087747343149321200190683, f_q)
            )
            {
                let prod := mload(0xfc0)

                prod := mulmod(mload(0x1000), prod, f_q)
                mstore(0x17a0, prod)

                prod := mulmod(mload(0x1040), prod, f_q)
                mstore(0x17c0, prod)

                prod := mulmod(mload(0x1080), prod, f_q)
                mstore(0x17e0, prod)

                prod := mulmod(mload(0x10c0), prod, f_q)
                mstore(0x1800, prod)

                prod := mulmod(mload(0x1100), prod, f_q)
                mstore(0x1820, prod)

                prod := mulmod(mload(0x1140), prod, f_q)
                mstore(0x1840, prod)

                prod := mulmod(mload(0x1180), prod, f_q)
                mstore(0x1860, prod)

                prod := mulmod(mload(0x11c0), prod, f_q)
                mstore(0x1880, prod)

                prod := mulmod(mload(0x1200), prod, f_q)
                mstore(0x18a0, prod)

                prod := mulmod(mload(0x1240), prod, f_q)
                mstore(0x18c0, prod)

                prod := mulmod(mload(0x1280), prod, f_q)
                mstore(0x18e0, prod)

                prod := mulmod(mload(0x12c0), prod, f_q)
                mstore(0x1900, prod)

                prod := mulmod(mload(0x1300), prod, f_q)
                mstore(0x1920, prod)

                prod := mulmod(mload(0x1340), prod, f_q)
                mstore(0x1940, prod)

                prod := mulmod(mload(0x1380), prod, f_q)
                mstore(0x1960, prod)

                prod := mulmod(mload(0x13c0), prod, f_q)
                mstore(0x1980, prod)

                prod := mulmod(mload(0x1400), prod, f_q)
                mstore(0x19a0, prod)

                prod := mulmod(mload(0x1440), prod, f_q)
                mstore(0x19c0, prod)

                prod := mulmod(mload(0x1480), prod, f_q)
                mstore(0x19e0, prod)

                prod := mulmod(mload(0x14c0), prod, f_q)
                mstore(0x1a00, prod)

                prod := mulmod(mload(0x1500), prod, f_q)
                mstore(0x1a20, prod)

                prod := mulmod(mload(0x1540), prod, f_q)
                mstore(0x1a40, prod)

                prod := mulmod(mload(0x1580), prod, f_q)
                mstore(0x1a60, prod)

                prod := mulmod(mload(0x15c0), prod, f_q)
                mstore(0x1a80, prod)

                prod := mulmod(mload(0x1600), prod, f_q)
                mstore(0x1aa0, prod)

                prod := mulmod(mload(0x1640), prod, f_q)
                mstore(0x1ac0, prod)

                prod := mulmod(mload(0x1680), prod, f_q)
                mstore(0x1ae0, prod)

                prod := mulmod(mload(0x16c0), prod, f_q)
                mstore(0x1b00, prod)

                prod := mulmod(mload(0x1700), prod, f_q)
                mstore(0x1b20, prod)

                prod := mulmod(mload(0x1740), prod, f_q)
                mstore(0x1b40, prod)

                prod := mulmod(mload(0x1780), prod, f_q)
                mstore(0x1b60, prod)

                prod := mulmod(mload(0xf60), prod, f_q)
                mstore(0x1b80, prod)
            }
            mstore(0x1bc0, 32)
            mstore(0x1be0, 32)
            mstore(0x1c00, 32)
            mstore(0x1c20, mload(0x1b80))
            mstore(0x1c40, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x1c60, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x1bc0, 0xc0, 0x1ba0, 0x20), 1), success)
            {
                let inv := mload(0x1ba0)
                let v

                v := mload(0xf60)
                mstore(3936, mulmod(mload(0x1b60), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1780)
                mstore(6016, mulmod(mload(0x1b40), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1740)
                mstore(5952, mulmod(mload(0x1b20), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1700)
                mstore(5888, mulmod(mload(0x1b00), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x16c0)
                mstore(5824, mulmod(mload(0x1ae0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1680)
                mstore(5760, mulmod(mload(0x1ac0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1640)
                mstore(5696, mulmod(mload(0x1aa0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1600)
                mstore(5632, mulmod(mload(0x1a80), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x15c0)
                mstore(5568, mulmod(mload(0x1a60), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1580)
                mstore(5504, mulmod(mload(0x1a40), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1540)
                mstore(5440, mulmod(mload(0x1a20), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1500)
                mstore(5376, mulmod(mload(0x1a00), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x14c0)
                mstore(5312, mulmod(mload(0x19e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1480)
                mstore(5248, mulmod(mload(0x19c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1440)
                mstore(5184, mulmod(mload(0x19a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1400)
                mstore(5120, mulmod(mload(0x1980), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x13c0)
                mstore(5056, mulmod(mload(0x1960), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1380)
                mstore(4992, mulmod(mload(0x1940), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1340)
                mstore(4928, mulmod(mload(0x1920), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1300)
                mstore(4864, mulmod(mload(0x1900), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x12c0)
                mstore(4800, mulmod(mload(0x18e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1280)
                mstore(4736, mulmod(mload(0x18c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1240)
                mstore(4672, mulmod(mload(0x18a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1200)
                mstore(4608, mulmod(mload(0x1880), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x11c0)
                mstore(4544, mulmod(mload(0x1860), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1180)
                mstore(4480, mulmod(mload(0x1840), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1140)
                mstore(4416, mulmod(mload(0x1820), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1100)
                mstore(4352, mulmod(mload(0x1800), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x10c0)
                mstore(4288, mulmod(mload(0x17e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1080)
                mstore(4224, mulmod(mload(0x17c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1040)
                mstore(4160, mulmod(mload(0x17a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x1000)
                mstore(4096, mulmod(mload(0xfc0), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0xfc0, inv)
            }
            mstore(0x1c80, mulmod(mload(0xfa0), mload(0xfc0), f_q))
            mstore(0x1ca0, mulmod(mload(0xfe0), mload(0x1000), f_q))
            mstore(0x1cc0, mulmod(mload(0x1020), mload(0x1040), f_q))
            mstore(0x1ce0, mulmod(mload(0x1060), mload(0x1080), f_q))
            mstore(0x1d00, mulmod(mload(0x10a0), mload(0x10c0), f_q))
            mstore(0x1d20, mulmod(mload(0x10e0), mload(0x1100), f_q))
            mstore(0x1d40, mulmod(mload(0x1120), mload(0x1140), f_q))
            mstore(0x1d60, mulmod(mload(0x1160), mload(0x1180), f_q))
            mstore(0x1d80, mulmod(mload(0x11a0), mload(0x11c0), f_q))
            mstore(0x1da0, mulmod(mload(0x11e0), mload(0x1200), f_q))
            mstore(0x1dc0, mulmod(mload(0x1220), mload(0x1240), f_q))
            mstore(0x1de0, mulmod(mload(0x1260), mload(0x1280), f_q))
            mstore(0x1e00, mulmod(mload(0x12a0), mload(0x12c0), f_q))
            mstore(0x1e20, mulmod(mload(0x12e0), mload(0x1300), f_q))
            mstore(0x1e40, mulmod(mload(0x1320), mload(0x1340), f_q))
            mstore(0x1e60, mulmod(mload(0x1360), mload(0x1380), f_q))
            mstore(0x1e80, mulmod(mload(0x13a0), mload(0x13c0), f_q))
            mstore(0x1ea0, mulmod(mload(0x13e0), mload(0x1400), f_q))
            mstore(0x1ec0, mulmod(mload(0x1420), mload(0x1440), f_q))
            mstore(0x1ee0, mulmod(mload(0x1460), mload(0x1480), f_q))
            mstore(0x1f00, mulmod(mload(0x14a0), mload(0x14c0), f_q))
            mstore(0x1f20, mulmod(mload(0x14e0), mload(0x1500), f_q))
            mstore(0x1f40, mulmod(mload(0x1520), mload(0x1540), f_q))
            mstore(0x1f60, mulmod(mload(0x1560), mload(0x1580), f_q))
            mstore(0x1f80, mulmod(mload(0x15a0), mload(0x15c0), f_q))
            mstore(0x1fa0, mulmod(mload(0x15e0), mload(0x1600), f_q))
            mstore(0x1fc0, mulmod(mload(0x1620), mload(0x1640), f_q))
            mstore(0x1fe0, mulmod(mload(0x1660), mload(0x1680), f_q))
            mstore(0x2000, mulmod(mload(0x16a0), mload(0x16c0), f_q))
            mstore(0x2020, mulmod(mload(0x16e0), mload(0x1700), f_q))
            mstore(0x2040, mulmod(mload(0x1720), mload(0x1740), f_q))
            mstore(0x2060, mulmod(mload(0x1760), mload(0x1780), f_q))
            {
                let result := mulmod(mload(0x1d60), mload(0xa0), f_q)
                result := addmod(mulmod(mload(0x1d80), mload(0xc0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1da0), mload(0xe0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1dc0), mload(0x100), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1de0), mload(0x120), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1e00), mload(0x140), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1e20), mload(0x160), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1e40), mload(0x180), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1e60), mload(0x1a0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1e80), mload(0x1c0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1ea0), mload(0x1e0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1ec0), mload(0x200), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1ee0), mload(0x220), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1f00), mload(0x240), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1f20), mload(0x260), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1f40), mload(0x280), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1f60), mload(0x2a0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1f80), mload(0x2c0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1fa0), mload(0x2e0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1fc0), mload(0x300), f_q), result, f_q)
                result := addmod(mulmod(mload(0x1fe0), mload(0x320), f_q), result, f_q)
                result := addmod(mulmod(mload(0x2000), mload(0x340), f_q), result, f_q)
                result := addmod(mulmod(mload(0x2020), mload(0x360), f_q), result, f_q)
                result := addmod(mulmod(mload(0x2040), mload(0x380), f_q), result, f_q)
                result := addmod(mulmod(mload(0x2060), mload(0x3a0), f_q), result, f_q)
                mstore(8320, result)
            }
            mstore(0x20a0, mulmod(mload(0x860), mload(0x840), f_q))
            mstore(0x20c0, addmod(mload(0x820), mload(0x20a0), f_q))
            mstore(0x20e0, addmod(mload(0x20c0), sub(f_q, mload(0x880)), f_q))
            mstore(0x2100, mulmod(mload(0x20e0), mload(0x8e0), f_q))
            mstore(0x2120, mulmod(mload(0x680), mload(0x2100), f_q))
            mstore(0x2140, addmod(1, sub(f_q, mload(0x9a0)), f_q))
            mstore(0x2160, mulmod(mload(0x2140), mload(0x1d60), f_q))
            mstore(0x2180, addmod(mload(0x2120), mload(0x2160), f_q))
            mstore(0x21a0, mulmod(mload(0x680), mload(0x2180), f_q))
            mstore(0x21c0, mulmod(mload(0x9a0), mload(0x9a0), f_q))
            mstore(0x21e0, addmod(mload(0x21c0), sub(f_q, mload(0x9a0)), f_q))
            mstore(0x2200, mulmod(mload(0x21e0), mload(0x1c80), f_q))
            mstore(0x2220, addmod(mload(0x21a0), mload(0x2200), f_q))
            mstore(0x2240, mulmod(mload(0x680), mload(0x2220), f_q))
            mstore(0x2260, addmod(1, sub(f_q, mload(0x1c80)), f_q))
            mstore(0x2280, addmod(mload(0x1ca0), mload(0x1cc0), f_q))
            mstore(0x22a0, addmod(mload(0x2280), mload(0x1ce0), f_q))
            mstore(0x22c0, addmod(mload(0x22a0), mload(0x1d00), f_q))
            mstore(0x22e0, addmod(mload(0x22c0), mload(0x1d20), f_q))
            mstore(0x2300, addmod(mload(0x22e0), mload(0x1d40), f_q))
            mstore(0x2320, addmod(mload(0x2260), sub(f_q, mload(0x2300)), f_q))
            mstore(0x2340, mulmod(mload(0x940), mload(0x500), f_q))
            mstore(0x2360, addmod(mload(0x8a0), mload(0x2340), f_q))
            mstore(0x2380, addmod(mload(0x2360), mload(0x560), f_q))
            mstore(0x23a0, mulmod(mload(0x960), mload(0x500), f_q))
            mstore(0x23c0, addmod(mload(0x820), mload(0x23a0), f_q))
            mstore(0x23e0, addmod(mload(0x23c0), mload(0x560), f_q))
            mstore(0x2400, mulmod(mload(0x23e0), mload(0x2380), f_q))
            mstore(0x2420, mulmod(mload(0x980), mload(0x500), f_q))
            mstore(0x2440, addmod(mload(0x2080), mload(0x2420), f_q))
            mstore(0x2460, addmod(mload(0x2440), mload(0x560), f_q))
            mstore(0x2480, mulmod(mload(0x2460), mload(0x2400), f_q))
            mstore(0x24a0, mulmod(mload(0x2480), mload(0x9c0), f_q))
            mstore(0x24c0, mulmod(1, mload(0x500), f_q))
            mstore(0x24e0, mulmod(mload(0x7e0), mload(0x24c0), f_q))
            mstore(0x2500, addmod(mload(0x8a0), mload(0x24e0), f_q))
            mstore(0x2520, addmod(mload(0x2500), mload(0x560), f_q))
            mstore(
                0x2540,
                mulmod(4131629893567559867359510883348571134090853742863529169391034518566172092834, mload(0x500), f_q)
            )
            mstore(0x2560, mulmod(mload(0x7e0), mload(0x2540), f_q))
            mstore(0x2580, addmod(mload(0x820), mload(0x2560), f_q))
            mstore(0x25a0, addmod(mload(0x2580), mload(0x560), f_q))
            mstore(0x25c0, mulmod(mload(0x25a0), mload(0x2520), f_q))
            mstore(
                0x25e0,
                mulmod(8910878055287538404433155982483128285667088683464058436815641868457422632747, mload(0x500), f_q)
            )
            mstore(0x2600, mulmod(mload(0x7e0), mload(0x25e0), f_q))
            mstore(0x2620, addmod(mload(0x2080), mload(0x2600), f_q))
            mstore(0x2640, addmod(mload(0x2620), mload(0x560), f_q))
            mstore(0x2660, mulmod(mload(0x2640), mload(0x25c0), f_q))
            mstore(0x2680, mulmod(mload(0x2660), mload(0x9a0), f_q))
            mstore(0x26a0, addmod(mload(0x24a0), sub(f_q, mload(0x2680)), f_q))
            mstore(0x26c0, mulmod(mload(0x26a0), mload(0x2320), f_q))
            mstore(0x26e0, addmod(mload(0x2240), mload(0x26c0), f_q))
            mstore(0x2700, mulmod(mload(0x680), mload(0x26e0), f_q))
            mstore(0x2720, addmod(1, sub(f_q, mload(0x9e0)), f_q))
            mstore(0x2740, mulmod(mload(0x2720), mload(0x1d60), f_q))
            mstore(0x2760, addmod(mload(0x2700), mload(0x2740), f_q))
            mstore(0x2780, mulmod(mload(0x680), mload(0x2760), f_q))
            mstore(0x27a0, mulmod(mload(0x9e0), mload(0x9e0), f_q))
            mstore(0x27c0, addmod(mload(0x27a0), sub(f_q, mload(0x9e0)), f_q))
            mstore(0x27e0, mulmod(mload(0x27c0), mload(0x1c80), f_q))
            mstore(0x2800, addmod(mload(0x2780), mload(0x27e0), f_q))
            mstore(0x2820, mulmod(mload(0x680), mload(0x2800), f_q))
            mstore(0x2840, addmod(mload(0xa20), mload(0x500), f_q))
            mstore(0x2860, mulmod(mload(0x2840), mload(0xa00), f_q))
            mstore(0x2880, addmod(mload(0xa60), mload(0x560), f_q))
            mstore(0x28a0, mulmod(mload(0x2880), mload(0x2860), f_q))
            mstore(0x28c0, mulmod(mload(0x820), mload(0x900), f_q))
            mstore(0x28e0, addmod(mload(0x28c0), mload(0x500), f_q))
            mstore(0x2900, mulmod(mload(0x28e0), mload(0x9e0), f_q))
            mstore(0x2920, addmod(mload(0x8c0), mload(0x560), f_q))
            mstore(0x2940, mulmod(mload(0x2920), mload(0x2900), f_q))
            mstore(0x2960, addmod(mload(0x28a0), sub(f_q, mload(0x2940)), f_q))
            mstore(0x2980, mulmod(mload(0x2960), mload(0x2320), f_q))
            mstore(0x29a0, addmod(mload(0x2820), mload(0x2980), f_q))
            mstore(0x29c0, mulmod(mload(0x680), mload(0x29a0), f_q))
            mstore(0x29e0, addmod(mload(0xa20), sub(f_q, mload(0xa60)), f_q))
            mstore(0x2a00, mulmod(mload(0x29e0), mload(0x1d60), f_q))
            mstore(0x2a20, addmod(mload(0x29c0), mload(0x2a00), f_q))
            mstore(0x2a40, mulmod(mload(0x680), mload(0x2a20), f_q))
            mstore(0x2a60, mulmod(mload(0x29e0), mload(0x2320), f_q))
            mstore(0x2a80, addmod(mload(0xa20), sub(f_q, mload(0xa40)), f_q))
            mstore(0x2aa0, mulmod(mload(0x2a80), mload(0x2a60), f_q))
            mstore(0x2ac0, addmod(mload(0x2a40), mload(0x2aa0), f_q))
            mstore(0x2ae0, mulmod(mload(0xf40), mload(0xf40), f_q))
            mstore(0x2b00, mulmod(mload(0x2ae0), mload(0xf40), f_q))
            mstore(0x2b20, mulmod(mload(0x2b00), mload(0xf40), f_q))
            mstore(0x2b40, mulmod(1, mload(0xf40), f_q))
            mstore(0x2b60, mulmod(1, mload(0x2ae0), f_q))
            mstore(0x2b80, mulmod(1, mload(0x2b00), f_q))
            mstore(0x2ba0, mulmod(mload(0x2ac0), mload(0xf60), f_q))
            mstore(0x2bc0, mulmod(mload(0xca0), mload(0x7e0), f_q))
            mstore(0x2be0, mulmod(mload(0x2bc0), mload(0x7e0), f_q))
            mstore(
                0x2c00,
                mulmod(mload(0x7e0), 8734126352828345679573237859165904705806588461301144420590422589042130041188, f_q)
            )
            mstore(0x2c20, addmod(mload(0xba0), sub(f_q, mload(0x2c00)), f_q))
            mstore(0x2c40, mulmod(mload(0x7e0), 1, f_q))
            mstore(0x2c60, addmod(mload(0xba0), sub(f_q, mload(0x2c40)), f_q))
            mstore(
                0x2c80,
                mulmod(mload(0x7e0), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q)
            )
            mstore(0x2ca0, addmod(mload(0xba0), sub(f_q, mload(0x2c80)), f_q))
            mstore(
                0x2cc0,
                mulmod(mload(0x7e0), 1426404432721484388505361748317961535523355871255605456897797744433766488507, f_q)
            )
            mstore(0x2ce0, addmod(mload(0xba0), sub(f_q, mload(0x2cc0)), f_q))
            mstore(
                0x2d00,
                mulmod(mload(0x7e0), 12619617507853212586156872920672483948819476989779550311307282715684870266992, f_q)
            )
            mstore(0x2d20, addmod(mload(0xba0), sub(f_q, mload(0x2d00)), f_q))
            mstore(
                0x2d40,
                mulmod(3544324119167359571073009690693121464267965232733679586767649244433889388945, mload(0x2bc0), f_q)
            )
            mstore(0x2d60, mulmod(mload(0x2d40), 1, f_q))
            {
                let result := mulmod(mload(0xba0), mload(0x2d40), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x2d60)), f_q), result, f_q)
                mstore(11648, result)
            }
            mstore(
                0x2da0,
                mulmod(3860370625838117017501327045244227871206764201116468958063324100051382735289, mload(0x2bc0), f_q)
            )
            mstore(
                0x2dc0,
                mulmod(
                    mload(0x2da0), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q
                )
            )
            {
                let result := mulmod(mload(0xba0), mload(0x2da0), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x2dc0)), f_q), result, f_q)
                mstore(11744, result)
            }
            mstore(
                0x2e00,
                mulmod(
                    21616901807277407275624036604424346159916096890712898844034238973395610537327, mload(0x2bc0), f_q
                )
            )
            mstore(
                0x2e20,
                mulmod(mload(0x2e00), 1426404432721484388505361748317961535523355871255605456897797744433766488507, f_q)
            )
            {
                let result := mulmod(mload(0xba0), mload(0x2e00), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x2e20)), f_q), result, f_q)
                mstore(11840, result)
            }
            mstore(
                0x2e60,
                mulmod(3209408481237076479025468386201293941554240476766691830436732310949352383503, mload(0x2bc0), f_q)
            )
            mstore(
                0x2e80,
                mulmod(
                    mload(0x2e60), 12619617507853212586156872920672483948819476989779550311307282715684870266992, f_q
                )
            )
            {
                let result := mulmod(mload(0xba0), mload(0x2e60), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x2e80)), f_q), result, f_q)
                mstore(11936, result)
            }
            mstore(0x2ec0, mulmod(1, mload(0x2c60), f_q))
            mstore(0x2ee0, mulmod(mload(0x2ec0), mload(0x2ca0), f_q))
            mstore(0x2f00, mulmod(mload(0x2ee0), mload(0x2ce0), f_q))
            mstore(0x2f20, mulmod(mload(0x2f00), mload(0x2d20), f_q))
            mstore(
                0x2f40,
                mulmod(10676941854703594198666993839846402519342119846958189386823924046696287912228, mload(0x7e0), f_q)
            )
            mstore(0x2f60, mulmod(mload(0x2f40), 1, f_q))
            {
                let result := mulmod(mload(0xba0), mload(0x2f40), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x2f60)), f_q), result, f_q)
                mstore(12160, result)
            }
            mstore(
                0x2fa0,
                mulmod(11211301017135681023579411905410872569206244553457844956874280139879520583389, mload(0x7e0), f_q)
            )
            mstore(
                0x2fc0,
                mulmod(
                    mload(0x2fa0), 11211301017135681023579411905410872569206244553457844956874280139879520583390, f_q
                )
            )
            {
                let result := mulmod(mload(0xba0), mload(0x2fa0), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x2fc0)), f_q), result, f_q)
                mstore(12256, result)
            }
            mstore(
                0x3000,
                mulmod(13154116519010929542673167886091370382741775939114889923107781597533678454430, mload(0x7e0), f_q)
            )
            mstore(0x3020, mulmod(mload(0x3000), 1, f_q))
            {
                let result := mulmod(mload(0xba0), mload(0x3000), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x3020)), f_q), result, f_q)
                mstore(12352, result)
            }
            mstore(
                0x3060,
                mulmod(8734126352828345679573237859165904705806588461301144420590422589042130041187, mload(0x7e0), f_q)
            )
            mstore(
                0x3080,
                mulmod(mload(0x3060), 8734126352828345679573237859165904705806588461301144420590422589042130041188, f_q)
            )
            {
                let result := mulmod(mload(0xba0), mload(0x3060), f_q)
                result := addmod(mulmod(mload(0x7e0), sub(f_q, mload(0x3080)), f_q), result, f_q)
                mstore(12448, result)
            }
            mstore(0x30c0, mulmod(mload(0x2ec0), mload(0x2c20), f_q))
            {
                let result := mulmod(mload(0xba0), 1, f_q)
                result :=
                    addmod(
                        mulmod(
                            mload(0x7e0), 21888242871839275222246405745257275088548364400416034343698204186575808495616, f_q
                        ),
                        result,
                        f_q
                    )
                mstore(12512, result)
            }
            {
                let prod := mload(0x2d80)

                prod := mulmod(mload(0x2de0), prod, f_q)
                mstore(0x3100, prod)

                prod := mulmod(mload(0x2e40), prod, f_q)
                mstore(0x3120, prod)

                prod := mulmod(mload(0x2ea0), prod, f_q)
                mstore(0x3140, prod)

                prod := mulmod(mload(0x2f80), prod, f_q)
                mstore(0x3160, prod)

                prod := mulmod(mload(0x2fe0), prod, f_q)
                mstore(0x3180, prod)

                prod := mulmod(mload(0x2ee0), prod, f_q)
                mstore(0x31a0, prod)

                prod := mulmod(mload(0x3040), prod, f_q)
                mstore(0x31c0, prod)

                prod := mulmod(mload(0x30a0), prod, f_q)
                mstore(0x31e0, prod)

                prod := mulmod(mload(0x30c0), prod, f_q)
                mstore(0x3200, prod)

                prod := mulmod(mload(0x30e0), prod, f_q)
                mstore(0x3220, prod)

                prod := mulmod(mload(0x2ec0), prod, f_q)
                mstore(0x3240, prod)
            }
            mstore(0x3280, 32)
            mstore(0x32a0, 32)
            mstore(0x32c0, 32)
            mstore(0x32e0, mload(0x3240))
            mstore(0x3300, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x3320, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x3280, 0xc0, 0x3260, 0x20), 1), success)
            {
                let inv := mload(0x3260)
                let v

                v := mload(0x2ec0)
                mstore(11968, mulmod(mload(0x3220), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x30e0)
                mstore(12512, mulmod(mload(0x3200), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x30c0)
                mstore(12480, mulmod(mload(0x31e0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x30a0)
                mstore(12448, mulmod(mload(0x31c0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x3040)
                mstore(12352, mulmod(mload(0x31a0), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2ee0)
                mstore(12000, mulmod(mload(0x3180), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2fe0)
                mstore(12256, mulmod(mload(0x3160), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2f80)
                mstore(12160, mulmod(mload(0x3140), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2ea0)
                mstore(11936, mulmod(mload(0x3120), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2e40)
                mstore(11840, mulmod(mload(0x3100), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x2de0)
                mstore(11744, mulmod(mload(0x2d80), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0x2d80, inv)
            }
            {
                let result := mload(0x2d80)
                result := addmod(mload(0x2de0), result, f_q)
                result := addmod(mload(0x2e40), result, f_q)
                result := addmod(mload(0x2ea0), result, f_q)
                mstore(13120, result)
            }
            mstore(0x3360, mulmod(mload(0x2f20), mload(0x2ee0), f_q))
            {
                let result := mload(0x2f80)
                result := addmod(mload(0x2fe0), result, f_q)
                mstore(13184, result)
            }
            mstore(0x33a0, mulmod(mload(0x2f20), mload(0x30c0), f_q))
            {
                let result := mload(0x3040)
                result := addmod(mload(0x30a0), result, f_q)
                mstore(13248, result)
            }
            mstore(0x33e0, mulmod(mload(0x2f20), mload(0x2ec0), f_q))
            {
                let result := mload(0x30e0)
                mstore(13312, result)
            }
            {
                let prod := mload(0x3340)

                prod := mulmod(mload(0x3380), prod, f_q)
                mstore(0x3420, prod)

                prod := mulmod(mload(0x33c0), prod, f_q)
                mstore(0x3440, prod)

                prod := mulmod(mload(0x3400), prod, f_q)
                mstore(0x3460, prod)
            }
            mstore(0x34a0, 32)
            mstore(0x34c0, 32)
            mstore(0x34e0, 32)
            mstore(0x3500, mload(0x3460))
            mstore(0x3520, 21888242871839275222246405745257275088548364400416034343698204186575808495615)
            mstore(0x3540, 21888242871839275222246405745257275088548364400416034343698204186575808495617)
            success := and(eq(staticcall(gas(), 0x5, 0x34a0, 0xc0, 0x3480, 0x20), 1), success)
            {
                let inv := mload(0x3480)
                let v

                v := mload(0x3400)
                mstore(13312, mulmod(mload(0x3440), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x33c0)
                mstore(13248, mulmod(mload(0x3420), inv, f_q))
                inv := mulmod(v, inv, f_q)

                v := mload(0x3380)
                mstore(13184, mulmod(mload(0x3340), inv, f_q))
                inv := mulmod(v, inv, f_q)
                mstore(0x3340, inv)
            }
            mstore(0x3560, mulmod(mload(0x3360), mload(0x3380), f_q))
            mstore(0x3580, mulmod(mload(0x33a0), mload(0x33c0), f_q))
            mstore(0x35a0, mulmod(mload(0x33e0), mload(0x3400), f_q))
            mstore(0x35c0, mulmod(mload(0xaa0), mload(0xaa0), f_q))
            mstore(0x35e0, mulmod(mload(0x35c0), mload(0xaa0), f_q))
            mstore(0x3600, mulmod(mload(0x35e0), mload(0xaa0), f_q))
            mstore(0x3620, mulmod(mload(0x3600), mload(0xaa0), f_q))
            mstore(0x3640, mulmod(mload(0x3620), mload(0xaa0), f_q))
            mstore(0x3660, mulmod(mload(0x3640), mload(0xaa0), f_q))
            mstore(0x3680, mulmod(mload(0x3660), mload(0xaa0), f_q))
            mstore(0x36a0, mulmod(mload(0x3680), mload(0xaa0), f_q))
            mstore(0x36c0, mulmod(mload(0x36a0), mload(0xaa0), f_q))
            mstore(0x36e0, mulmod(mload(0xb00), mload(0xb00), f_q))
            mstore(0x3700, mulmod(mload(0x36e0), mload(0xb00), f_q))
            mstore(0x3720, mulmod(mload(0x3700), mload(0xb00), f_q))
            {
                let result := mulmod(mload(0x820), mload(0x2d80), f_q)
                result := addmod(mulmod(mload(0x840), mload(0x2de0), f_q), result, f_q)
                result := addmod(mulmod(mload(0x860), mload(0x2e40), f_q), result, f_q)
                result := addmod(mulmod(mload(0x880), mload(0x2ea0), f_q), result, f_q)
                mstore(14144, result)
            }
            mstore(0x3760, mulmod(mload(0x3740), mload(0x3340), f_q))
            mstore(0x3780, mulmod(sub(f_q, mload(0x3760)), 1, f_q))
            mstore(0x37a0, mulmod(mload(0x3780), 1, f_q))
            mstore(0x37c0, mulmod(1, mload(0x3360), f_q))
            {
                let result := mulmod(mload(0x9a0), mload(0x2f80), f_q)
                result := addmod(mulmod(mload(0x9c0), mload(0x2fe0), f_q), result, f_q)
                mstore(14304, result)
            }
            mstore(0x3800, mulmod(mload(0x37e0), mload(0x3560), f_q))
            mstore(0x3820, mulmod(sub(f_q, mload(0x3800)), 1, f_q))
            mstore(0x3840, mulmod(mload(0x37c0), 1, f_q))
            {
                let result := mulmod(mload(0x9e0), mload(0x2f80), f_q)
                result := addmod(mulmod(mload(0xa00), mload(0x2fe0), f_q), result, f_q)
                mstore(14432, result)
            }
            mstore(0x3880, mulmod(mload(0x3860), mload(0x3560), f_q))
            mstore(0x38a0, mulmod(sub(f_q, mload(0x3880)), mload(0xaa0), f_q))
            mstore(0x38c0, mulmod(mload(0x37c0), mload(0xaa0), f_q))
            mstore(0x38e0, addmod(mload(0x3820), mload(0x38a0), f_q))
            mstore(0x3900, mulmod(mload(0x38e0), mload(0xb00), f_q))
            mstore(0x3920, mulmod(mload(0x3840), mload(0xb00), f_q))
            mstore(0x3940, mulmod(mload(0x38c0), mload(0xb00), f_q))
            mstore(0x3960, addmod(mload(0x37a0), mload(0x3900), f_q))
            mstore(0x3980, mulmod(1, mload(0x33a0), f_q))
            {
                let result := mulmod(mload(0xa20), mload(0x3040), f_q)
                result := addmod(mulmod(mload(0xa40), mload(0x30a0), f_q), result, f_q)
                mstore(14752, result)
            }
            mstore(0x39c0, mulmod(mload(0x39a0), mload(0x3580), f_q))
            mstore(0x39e0, mulmod(sub(f_q, mload(0x39c0)), 1, f_q))
            mstore(0x3a00, mulmod(mload(0x3980), 1, f_q))
            mstore(0x3a20, mulmod(mload(0x39e0), mload(0x36e0), f_q))
            mstore(0x3a40, mulmod(mload(0x3a00), mload(0x36e0), f_q))
            mstore(0x3a60, addmod(mload(0x3960), mload(0x3a20), f_q))
            mstore(0x3a80, mulmod(1, mload(0x33e0), f_q))
            {
                let result := mulmod(mload(0xa60), mload(0x30e0), f_q)
                mstore(15008, result)
            }
            mstore(0x3ac0, mulmod(mload(0x3aa0), mload(0x35a0), f_q))
            mstore(0x3ae0, mulmod(sub(f_q, mload(0x3ac0)), 1, f_q))
            mstore(0x3b00, mulmod(mload(0x3a80), 1, f_q))
            {
                let result := mulmod(mload(0x8a0), mload(0x30e0), f_q)
                mstore(15136, result)
            }
            mstore(0x3b40, mulmod(mload(0x3b20), mload(0x35a0), f_q))
            mstore(0x3b60, mulmod(sub(f_q, mload(0x3b40)), mload(0xaa0), f_q))
            mstore(0x3b80, mulmod(mload(0x3a80), mload(0xaa0), f_q))
            mstore(0x3ba0, addmod(mload(0x3ae0), mload(0x3b60), f_q))
            {
                let result := mulmod(mload(0x8c0), mload(0x30e0), f_q)
                mstore(15296, result)
            }
            mstore(0x3be0, mulmod(mload(0x3bc0), mload(0x35a0), f_q))
            mstore(0x3c00, mulmod(sub(f_q, mload(0x3be0)), mload(0x35c0), f_q))
            mstore(0x3c20, mulmod(mload(0x3a80), mload(0x35c0), f_q))
            mstore(0x3c40, addmod(mload(0x3ba0), mload(0x3c00), f_q))
            {
                let result := mulmod(mload(0x8e0), mload(0x30e0), f_q)
                mstore(15456, result)
            }
            mstore(0x3c80, mulmod(mload(0x3c60), mload(0x35a0), f_q))
            mstore(0x3ca0, mulmod(sub(f_q, mload(0x3c80)), mload(0x35e0), f_q))
            mstore(0x3cc0, mulmod(mload(0x3a80), mload(0x35e0), f_q))
            mstore(0x3ce0, addmod(mload(0x3c40), mload(0x3ca0), f_q))
            {
                let result := mulmod(mload(0x900), mload(0x30e0), f_q)
                mstore(15616, result)
            }
            mstore(0x3d20, mulmod(mload(0x3d00), mload(0x35a0), f_q))
            mstore(0x3d40, mulmod(sub(f_q, mload(0x3d20)), mload(0x3600), f_q))
            mstore(0x3d60, mulmod(mload(0x3a80), mload(0x3600), f_q))
            mstore(0x3d80, addmod(mload(0x3ce0), mload(0x3d40), f_q))
            {
                let result := mulmod(mload(0x940), mload(0x30e0), f_q)
                mstore(15776, result)
            }
            mstore(0x3dc0, mulmod(mload(0x3da0), mload(0x35a0), f_q))
            mstore(0x3de0, mulmod(sub(f_q, mload(0x3dc0)), mload(0x3620), f_q))
            mstore(0x3e00, mulmod(mload(0x3a80), mload(0x3620), f_q))
            mstore(0x3e20, addmod(mload(0x3d80), mload(0x3de0), f_q))
            {
                let result := mulmod(mload(0x960), mload(0x30e0), f_q)
                mstore(15936, result)
            }
            mstore(0x3e60, mulmod(mload(0x3e40), mload(0x35a0), f_q))
            mstore(0x3e80, mulmod(sub(f_q, mload(0x3e60)), mload(0x3640), f_q))
            mstore(0x3ea0, mulmod(mload(0x3a80), mload(0x3640), f_q))
            mstore(0x3ec0, addmod(mload(0x3e20), mload(0x3e80), f_q))
            {
                let result := mulmod(mload(0x980), mload(0x30e0), f_q)
                mstore(16096, result)
            }
            mstore(0x3f00, mulmod(mload(0x3ee0), mload(0x35a0), f_q))
            mstore(0x3f20, mulmod(sub(f_q, mload(0x3f00)), mload(0x3660), f_q))
            mstore(0x3f40, mulmod(mload(0x3a80), mload(0x3660), f_q))
            mstore(0x3f60, addmod(mload(0x3ec0), mload(0x3f20), f_q))
            mstore(0x3f80, mulmod(mload(0x2b40), mload(0x33e0), f_q))
            mstore(0x3fa0, mulmod(mload(0x2b60), mload(0x33e0), f_q))
            mstore(0x3fc0, mulmod(mload(0x2b80), mload(0x33e0), f_q))
            {
                let result := mulmod(mload(0x2ba0), mload(0x30e0), f_q)
                mstore(16352, result)
            }
            mstore(0x4000, mulmod(mload(0x3fe0), mload(0x35a0), f_q))
            mstore(0x4020, mulmod(sub(f_q, mload(0x4000)), mload(0x3680), f_q))
            mstore(0x4040, mulmod(mload(0x3a80), mload(0x3680), f_q))
            mstore(0x4060, mulmod(mload(0x3f80), mload(0x3680), f_q))
            mstore(0x4080, mulmod(mload(0x3fa0), mload(0x3680), f_q))
            mstore(0x40a0, mulmod(mload(0x3fc0), mload(0x3680), f_q))
            mstore(0x40c0, addmod(mload(0x3f60), mload(0x4020), f_q))
            {
                let result := mulmod(mload(0x920), mload(0x30e0), f_q)
                mstore(16608, result)
            }
            mstore(0x4100, mulmod(mload(0x40e0), mload(0x35a0), f_q))
            mstore(0x4120, mulmod(sub(f_q, mload(0x4100)), mload(0x36a0), f_q))
            mstore(0x4140, mulmod(mload(0x3a80), mload(0x36a0), f_q))
            mstore(0x4160, addmod(mload(0x40c0), mload(0x4120), f_q))
            mstore(0x4180, mulmod(mload(0x4160), mload(0x3700), f_q))
            mstore(0x41a0, mulmod(mload(0x3b00), mload(0x3700), f_q))
            mstore(0x41c0, mulmod(mload(0x3b80), mload(0x3700), f_q))
            mstore(0x41e0, mulmod(mload(0x3c20), mload(0x3700), f_q))
            mstore(0x4200, mulmod(mload(0x3cc0), mload(0x3700), f_q))
            mstore(0x4220, mulmod(mload(0x3d60), mload(0x3700), f_q))
            mstore(0x4240, mulmod(mload(0x3e00), mload(0x3700), f_q))
            mstore(0x4260, mulmod(mload(0x3ea0), mload(0x3700), f_q))
            mstore(0x4280, mulmod(mload(0x3f40), mload(0x3700), f_q))
            mstore(0x42a0, mulmod(mload(0x4040), mload(0x3700), f_q))
            mstore(0x42c0, mulmod(mload(0x4060), mload(0x3700), f_q))
            mstore(0x42e0, mulmod(mload(0x4080), mload(0x3700), f_q))
            mstore(0x4300, mulmod(mload(0x40a0), mload(0x3700), f_q))
            mstore(0x4320, mulmod(mload(0x4140), mload(0x3700), f_q))
            mstore(0x4340, addmod(mload(0x3a60), mload(0x4180), f_q))
            mstore(0x4360, mulmod(1, mload(0x2f20), f_q))
            mstore(0x4380, mulmod(1, mload(0xba0), f_q))
            mstore(0x43a0, 0x0000000000000000000000000000000000000000000000000000000000000001)
            mstore(0x43c0, 0x0000000000000000000000000000000000000000000000000000000000000002)
            mstore(0x43e0, mload(0x4340))
            success := and(eq(staticcall(gas(), 0x7, 0x43a0, 0x60, 0x43a0, 0x40), 1), success)
            mstore(0x4400, mload(0x43a0))
            mstore(0x4420, mload(0x43c0))
            mstore(0x4440, mload(0x3c0))
            mstore(0x4460, mload(0x3e0))
            success := and(eq(staticcall(gas(), 0x6, 0x4400, 0x80, 0x4400, 0x40), 1), success)
            mstore(0x4480, mload(0x5a0))
            mstore(0x44a0, mload(0x5c0))
            mstore(0x44c0, mload(0x3920))
            success := and(eq(staticcall(gas(), 0x7, 0x4480, 0x60, 0x4480, 0x40), 1), success)
            mstore(0x44e0, mload(0x4400))
            mstore(0x4500, mload(0x4420))
            mstore(0x4520, mload(0x4480))
            mstore(0x4540, mload(0x44a0))
            success := and(eq(staticcall(gas(), 0x6, 0x44e0, 0x80, 0x44e0, 0x40), 1), success)
            mstore(0x4560, mload(0x5e0))
            mstore(0x4580, mload(0x600))
            mstore(0x45a0, mload(0x3940))
            success := and(eq(staticcall(gas(), 0x7, 0x4560, 0x60, 0x4560, 0x40), 1), success)
            mstore(0x45c0, mload(0x44e0))
            mstore(0x45e0, mload(0x4500))
            mstore(0x4600, mload(0x4560))
            mstore(0x4620, mload(0x4580))
            success := and(eq(staticcall(gas(), 0x6, 0x45c0, 0x80, 0x45c0, 0x40), 1), success)
            mstore(0x4640, mload(0x460))
            mstore(0x4660, mload(0x480))
            mstore(0x4680, mload(0x3a40))
            success := and(eq(staticcall(gas(), 0x7, 0x4640, 0x60, 0x4640, 0x40), 1), success)
            mstore(0x46a0, mload(0x45c0))
            mstore(0x46c0, mload(0x45e0))
            mstore(0x46e0, mload(0x4640))
            mstore(0x4700, mload(0x4660))
            success := and(eq(staticcall(gas(), 0x6, 0x46a0, 0x80, 0x46a0, 0x40), 1), success)
            mstore(0x4720, mload(0x4a0))
            mstore(0x4740, mload(0x4c0))
            mstore(0x4760, mload(0x41a0))
            success := and(eq(staticcall(gas(), 0x7, 0x4720, 0x60, 0x4720, 0x40), 1), success)
            mstore(0x4780, mload(0x46a0))
            mstore(0x47a0, mload(0x46c0))
            mstore(0x47c0, mload(0x4720))
            mstore(0x47e0, mload(0x4740))
            success := and(eq(staticcall(gas(), 0x6, 0x4780, 0x80, 0x4780, 0x40), 1), success)
            mstore(0x4800, 0x2ce5fd9c93e8a5d55b7dc10413e162738c467be77c3dfe23d9930b99827f5d71)
            mstore(0x4820, 0x2dad81b9a61c4d459797db55796668c4aa6372fafdfd507e4fc9a2988b36bf1c)
            mstore(0x4840, mload(0x41c0))
            success := and(eq(staticcall(gas(), 0x7, 0x4800, 0x60, 0x4800, 0x40), 1), success)
            mstore(0x4860, mload(0x4780))
            mstore(0x4880, mload(0x47a0))
            mstore(0x48a0, mload(0x4800))
            mstore(0x48c0, mload(0x4820))
            success := and(eq(staticcall(gas(), 0x6, 0x4860, 0x80, 0x4860, 0x40), 1), success)
            mstore(0x48e0, 0x21c6ea7d6dbcd767ffb9d9beeb4f9c2f8243bc65290f2d75a59aea4f65ba8f3d)
            mstore(0x4900, 0x24d0a0acb031c9a5687da08cdaf96650aae5c60435739bda8bbd574eb962622c)
            mstore(0x4920, mload(0x41e0))
            success := and(eq(staticcall(gas(), 0x7, 0x48e0, 0x60, 0x48e0, 0x40), 1), success)
            mstore(0x4940, mload(0x4860))
            mstore(0x4960, mload(0x4880))
            mstore(0x4980, mload(0x48e0))
            mstore(0x49a0, mload(0x4900))
            success := and(eq(staticcall(gas(), 0x6, 0x4940, 0x80, 0x4940, 0x40), 1), success)
            mstore(0x49c0, 0x2f80f3ad2ed145aab89c020d99e0eed9130e1e52ec58ac8b8a41ab60b46df5ae)
            mstore(0x49e0, 0x2d984dcc2141190dc18ea99472f5694788370813c275a1a4335c0392bad107a2)
            mstore(0x4a00, mload(0x4200))
            success := and(eq(staticcall(gas(), 0x7, 0x49c0, 0x60, 0x49c0, 0x40), 1), success)
            mstore(0x4a20, mload(0x4940))
            mstore(0x4a40, mload(0x4960))
            mstore(0x4a60, mload(0x49c0))
            mstore(0x4a80, mload(0x49e0))
            success := and(eq(staticcall(gas(), 0x6, 0x4a20, 0x80, 0x4a20, 0x40), 1), success)
            mstore(0x4aa0, 0x07c96ecdd0675edbac20107d2f2d87edca051edcc6aa148d3c3619504d6c7456)
            mstore(0x4ac0, 0x23acd906a48f68b4dd2c17db642847c4ddb194e39e30625d29def568cefecf8f)
            mstore(0x4ae0, mload(0x4220))
            success := and(eq(staticcall(gas(), 0x7, 0x4aa0, 0x60, 0x4aa0, 0x40), 1), success)
            mstore(0x4b00, mload(0x4a20))
            mstore(0x4b20, mload(0x4a40))
            mstore(0x4b40, mload(0x4aa0))
            mstore(0x4b60, mload(0x4ac0))
            success := and(eq(staticcall(gas(), 0x6, 0x4b00, 0x80, 0x4b00, 0x40), 1), success)
            mstore(0x4b80, 0x0b86e2e23da96bd5fa76bff96444b23aabd8cea83385b7bea4e69864ee1b921c)
            mstore(0x4ba0, 0x2273a5b2cfea695d8a7ea745109a627e6efc4fcb987963fe0b50ff029474000f)
            mstore(0x4bc0, mload(0x4240))
            success := and(eq(staticcall(gas(), 0x7, 0x4b80, 0x60, 0x4b80, 0x40), 1), success)
            mstore(0x4be0, mload(0x4b00))
            mstore(0x4c00, mload(0x4b20))
            mstore(0x4c20, mload(0x4b80))
            mstore(0x4c40, mload(0x4ba0))
            success := and(eq(staticcall(gas(), 0x6, 0x4be0, 0x80, 0x4be0, 0x40), 1), success)
            mstore(0x4c60, 0x09aa1c4746690e3eb20dbec6fd792084b29896b67efdcbb4f3e22be0c7b3b5bd)
            mstore(0x4c80, 0x0ae5df18072bfd20ea6511e6d2ec5e025e4a6ff1e41b5f92a477341b89e8f010)
            mstore(0x4ca0, mload(0x4260))
            success := and(eq(staticcall(gas(), 0x7, 0x4c60, 0x60, 0x4c60, 0x40), 1), success)
            mstore(0x4cc0, mload(0x4be0))
            mstore(0x4ce0, mload(0x4c00))
            mstore(0x4d00, mload(0x4c60))
            mstore(0x4d20, mload(0x4c80))
            success := and(eq(staticcall(gas(), 0x6, 0x4cc0, 0x80, 0x4cc0, 0x40), 1), success)
            mstore(0x4d40, 0x04de57b1bd653ed879a1d81af2e77cf99d434f24203d9e6279b4cc727de08514)
            mstore(0x4d60, 0x03043e530f03b4a2f9d5182cd6b08d27737b9d544f291df53d6dcdc0a6194bbc)
            mstore(0x4d80, mload(0x4280))
            success := and(eq(staticcall(gas(), 0x7, 0x4d40, 0x60, 0x4d40, 0x40), 1), success)
            mstore(0x4da0, mload(0x4cc0))
            mstore(0x4dc0, mload(0x4ce0))
            mstore(0x4de0, mload(0x4d40))
            mstore(0x4e00, mload(0x4d60))
            success := and(eq(staticcall(gas(), 0x6, 0x4da0, 0x80, 0x4da0, 0x40), 1), success)
            mstore(0x4e20, mload(0x6c0))
            mstore(0x4e40, mload(0x6e0))
            mstore(0x4e60, mload(0x42a0))
            success := and(eq(staticcall(gas(), 0x7, 0x4e20, 0x60, 0x4e20, 0x40), 1), success)
            mstore(0x4e80, mload(0x4da0))
            mstore(0x4ea0, mload(0x4dc0))
            mstore(0x4ec0, mload(0x4e20))
            mstore(0x4ee0, mload(0x4e40))
            success := and(eq(staticcall(gas(), 0x6, 0x4e80, 0x80, 0x4e80, 0x40), 1), success)
            mstore(0x4f00, mload(0x700))
            mstore(0x4f20, mload(0x720))
            mstore(0x4f40, mload(0x42c0))
            success := and(eq(staticcall(gas(), 0x7, 0x4f00, 0x60, 0x4f00, 0x40), 1), success)
            mstore(0x4f60, mload(0x4e80))
            mstore(0x4f80, mload(0x4ea0))
            mstore(0x4fa0, mload(0x4f00))
            mstore(0x4fc0, mload(0x4f20))
            success := and(eq(staticcall(gas(), 0x6, 0x4f60, 0x80, 0x4f60, 0x40), 1), success)
            mstore(0x4fe0, mload(0x740))
            mstore(0x5000, mload(0x760))
            mstore(0x5020, mload(0x42e0))
            success := and(eq(staticcall(gas(), 0x7, 0x4fe0, 0x60, 0x4fe0, 0x40), 1), success)
            mstore(0x5040, mload(0x4f60))
            mstore(0x5060, mload(0x4f80))
            mstore(0x5080, mload(0x4fe0))
            mstore(0x50a0, mload(0x5000))
            success := and(eq(staticcall(gas(), 0x6, 0x5040, 0x80, 0x5040, 0x40), 1), success)
            mstore(0x50c0, mload(0x780))
            mstore(0x50e0, mload(0x7a0))
            mstore(0x5100, mload(0x4300))
            success := and(eq(staticcall(gas(), 0x7, 0x50c0, 0x60, 0x50c0, 0x40), 1), success)
            mstore(0x5120, mload(0x5040))
            mstore(0x5140, mload(0x5060))
            mstore(0x5160, mload(0x50c0))
            mstore(0x5180, mload(0x50e0))
            success := and(eq(staticcall(gas(), 0x6, 0x5120, 0x80, 0x5120, 0x40), 1), success)
            mstore(0x51a0, mload(0x620))
            mstore(0x51c0, mload(0x640))
            mstore(0x51e0, mload(0x4320))
            success := and(eq(staticcall(gas(), 0x7, 0x51a0, 0x60, 0x51a0, 0x40), 1), success)
            mstore(0x5200, mload(0x5120))
            mstore(0x5220, mload(0x5140))
            mstore(0x5240, mload(0x51a0))
            mstore(0x5260, mload(0x51c0))
            success := and(eq(staticcall(gas(), 0x6, 0x5200, 0x80, 0x5200, 0x40), 1), success)
            mstore(0x5280, mload(0xb40))
            mstore(0x52a0, mload(0xb60))
            mstore(0x52c0, sub(f_q, mload(0x4360)))
            success := and(eq(staticcall(gas(), 0x7, 0x5280, 0x60, 0x5280, 0x40), 1), success)
            mstore(0x52e0, mload(0x5200))
            mstore(0x5300, mload(0x5220))
            mstore(0x5320, mload(0x5280))
            mstore(0x5340, mload(0x52a0))
            success := and(eq(staticcall(gas(), 0x6, 0x52e0, 0x80, 0x52e0, 0x40), 1), success)
            mstore(0x5360, mload(0xbe0))
            mstore(0x5380, mload(0xc00))
            mstore(0x53a0, mload(0x4380))
            success := and(eq(staticcall(gas(), 0x7, 0x5360, 0x60, 0x5360, 0x40), 1), success)
            mstore(0x53c0, mload(0x52e0))
            mstore(0x53e0, mload(0x5300))
            mstore(0x5400, mload(0x5360))
            mstore(0x5420, mload(0x5380))
            success := and(eq(staticcall(gas(), 0x6, 0x53c0, 0x80, 0x53c0, 0x40), 1), success)
            mstore(0x5440, mload(0x53c0))
            mstore(0x5460, mload(0x53e0))
            mstore(0x5480, mload(0xbe0))
            mstore(0x54a0, mload(0xc00))
            mstore(0x54c0, mload(0xc20))
            mstore(0x54e0, mload(0xc40))
            mstore(0x5500, mload(0xc60))
            mstore(0x5520, mload(0xc80))
            mstore(0x5540, keccak256(0x5440, 256))
            mstore(21856, mod(mload(21824), f_q))
            mstore(0x5580, mulmod(mload(0x5560), mload(0x5560), f_q))
            mstore(0x55a0, mulmod(1, mload(0x5560), f_q))
            mstore(0x55c0, mload(0x54c0))
            mstore(0x55e0, mload(0x54e0))
            mstore(0x5600, mload(0x55a0))
            success := and(eq(staticcall(gas(), 0x7, 0x55c0, 0x60, 0x55c0, 0x40), 1), success)
            mstore(0x5620, mload(0x5440))
            mstore(0x5640, mload(0x5460))
            mstore(0x5660, mload(0x55c0))
            mstore(0x5680, mload(0x55e0))
            success := and(eq(staticcall(gas(), 0x6, 0x5620, 0x80, 0x5620, 0x40), 1), success)
            mstore(0x56a0, mload(0x5500))
            mstore(0x56c0, mload(0x5520))
            mstore(0x56e0, mload(0x55a0))
            success := and(eq(staticcall(gas(), 0x7, 0x56a0, 0x60, 0x56a0, 0x40), 1), success)
            mstore(0x5700, mload(0x5480))
            mstore(0x5720, mload(0x54a0))
            mstore(0x5740, mload(0x56a0))
            mstore(0x5760, mload(0x56c0))
            success := and(eq(staticcall(gas(), 0x6, 0x5700, 0x80, 0x5700, 0x40), 1), success)
            mstore(0x5780, mload(0x5620))
            mstore(0x57a0, mload(0x5640))
            mstore(0x57c0, 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2)
            mstore(0x57e0, 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed)
            mstore(0x5800, 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b)
            mstore(0x5820, 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa)
            mstore(0x5840, mload(0x5700))
            mstore(0x5860, mload(0x5720))
            mstore(0x5880, 0x172aa93c41f16e1e04d62ac976a5d945f4be0acab990c6dc19ac4a7cf68bf77b)
            mstore(0x58a0, 0x2ae0c8c3a090f7200ff398ee9845bbae8f8c1445ae7b632212775f60a0e21600)
            mstore(0x58c0, 0x190fa476a5b352809ed41d7a0d7fe12b8f685e3c12a6d83855dba27aaf469643)
            mstore(0x58e0, 0x1c0a500618907df9e4273d5181e31088deb1f05132de037cbfe73888f97f77c9)
            success := and(eq(staticcall(gas(), 0x8, 0x5780, 0x180, 0x5780, 0x20), 1), success)
            success := and(eq(mload(0x5780), 1), success)

            // Revert if anything fails
            if iszero(success) { revert(0, 0) }

            // Return empty bytes on success
            return(0, 0)
        }
    }
}

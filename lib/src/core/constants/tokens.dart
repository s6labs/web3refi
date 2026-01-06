import 'package:web3refi/src/core/types.dart';

/// Predefined token addresses and metadata for supported chains.
///
/// Provides quick access to popular tokens without manual address lookup.
///
/// Example:
/// ```dart
/// // Get USDC on Polygon
/// final usdcAddress = Tokens.usdcPolygon;
///
/// // Get full token info
/// final usdcInfo = Tokens.getInfo(Tokens.usdcPolygon, chainId: 137);
///
/// // Use with ERC20 class
/// final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);
/// ```
abstract class Tokens {
  Tokens._();

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ ETHEREUM MAINNET (Chain ID: 1)                                           ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on Ethereum
  static const usdcEthereum = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';

  /// USDT (Tether) on Ethereum
  static const usdtEthereum = '0xdAC17F958D2ee523a2206206994597C13D831ec7';

  /// DAI on Ethereum
  static const daiEthereum = '0x6B175474E89094C44Da98b954EedeAC495271d0F';

  /// FRAX on Ethereum
  static const fraxEthereum = '0x853d955aCEf822Db058eb8505911ED77F175b99e';

  /// LUSD (Liquity USD) on Ethereum
  static const lusdEthereum = '0x5f98805A4E8be255a32880FDeC7F6728C6568bA0';

  /// TUSD (TrueUSD) on Ethereum
  static const tusdEthereum = '0x0000000000085d4780B73119b644AE5ecd22b376';

  /// BUSD on Ethereum
  static const busdEthereum = '0x4Fabb145d64652a948d72533023f6E7A623C7C53';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WETH (Wrapped Ether) on Ethereum
  static const wethEthereum = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// LINK (Chainlink) on Ethereum
  static const linkEthereum = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

  /// UNI (Uniswap) on Ethereum
  static const uniEthereum = '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984';

  /// AAVE on Ethereum
  static const aaveEthereum = '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9';

  /// CRV (Curve) on Ethereum
  static const crvEthereum = '0xD533a949740bb3306d119CC777fa900bA034cd52';

  /// LDO (Lido) on Ethereum
  static const ldoEthereum = '0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32';

  /// MKR (Maker) on Ethereum
  static const mkrEthereum = '0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2';

  /// SNX (Synthetix) on Ethereum
  static const snxEthereum = '0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F';

  /// COMP (Compound) on Ethereum
  static const compEthereum = '0xc00e94Cb662C3520282E6f5717214004A7f26888';

  // ─────────────────────────────────────────────────────────────────────────────
  // Liquid Staking
  // ─────────────────────────────────────────────────────────────────────────────

  /// stETH (Lido Staked ETH) on Ethereum
  static const stethEthereum = '0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84';

  /// wstETH (Wrapped stETH) on Ethereum
  static const wstethEthereum = '0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0';

  /// rETH (Rocket Pool ETH) on Ethereum
  static const rethEthereum = '0xae78736Cd615f374D3085123A210448E74Fc6393';

  /// cbETH (Coinbase Staked ETH) on Ethereum
  static const cbethEthereum = '0xBe9895146f7AF43049ca1c1AE358B0541Ea49704';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ POLYGON (Chain ID: 137)                                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on Polygon (Native)
  static const usdcPolygon = '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359';

  /// USDC.e on Polygon (Bridged)
  static const usdcePolygon = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';

  /// USDT on Polygon
  static const usdtPolygon = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';

  /// DAI on Polygon
  static const daiPolygon = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063';

  /// FRAX on Polygon
  static const fraxPolygon = '0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WMATIC (Wrapped MATIC) on Polygon
  static const wmaticPolygon = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270';

  /// WPOL (Wrapped POL) on Polygon - new native token
  static const wpolPolygon = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270';

  /// WETH on Polygon
  static const wethPolygon = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// LINK on Polygon
  static const linkPolygon = '0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39';

  /// AAVE on Polygon
  static const aavePolygon = '0xD6DF932A45C0f255f85145f286eA0b292B21C90B';

  /// CRV on Polygon
  static const crvPolygon = '0x172370d5Cd63279eFa6d502DAB29171933a610AF';

  /// QUICK (QuickSwap) on Polygon
  static const quickPolygon = '0xB5C064F955D8e7F38fE0460C556a72987494eE17';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ ARBITRUM ONE (Chain ID: 42161)                                           ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on Arbitrum (Native)
  static const usdcArbitrum = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';

  /// USDC.e on Arbitrum (Bridged)
  static const usdceArbitrum = '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8';

  /// USDT on Arbitrum
  static const usdtArbitrum = '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9';

  /// DAI on Arbitrum
  static const daiArbitrum = '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1';

  /// FRAX on Arbitrum
  static const fraxArbitrum = '0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WETH on Arbitrum
  static const wethArbitrum = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi & Native Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// ARB (Arbitrum Token) on Arbitrum
  static const arbArbitrum = '0x912CE59144191C1204E64559FE8253a0e49E6548';

  /// GMX on Arbitrum
  static const gmxArbitrum = '0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a';

  /// LINK on Arbitrum
  static const linkArbitrum = '0xf97f4df75117a78c1A5a0DBb814Af92458539FB4';

  /// UNI on Arbitrum
  static const uniArbitrum = '0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ OPTIMISM (Chain ID: 10)                                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on Optimism (Native)
  static const usdcOptimism = '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85';

  /// USDC.e on Optimism (Bridged)
  static const usdceOptimism = '0x7F5c764cBc14f9669B88837ca1490cCa17c31607';

  /// USDT on Optimism
  static const usdtOptimism = '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58';

  /// DAI on Optimism
  static const daiOptimism = '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WETH on Optimism
  static const wethOptimism = '0x4200000000000000000000000000000000000006';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi & Native Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// OP (Optimism Token) on Optimism
  static const opOptimism = '0x4200000000000000000000000000000000000042';

  /// LINK on Optimism
  static const linkOptimism = '0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6';

  /// SNX on Optimism
  static const snxOptimism = '0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4';

  /// VELO (Velodrome) on Optimism
  static const veloOptimism = '0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ BASE (Chain ID: 8453)                                                     ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on Base
  static const usdcBase = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';

  /// USDbC on Base (Bridged USDC)
  static const usdbcBase = '0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA';

  /// DAI on Base
  static const daiBase = '0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WETH on Base
  static const wethBase = '0x4200000000000000000000000000000000000006';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// cbETH on Base
  static const cbethBase = '0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22';

  /// AERO (Aerodrome) on Base
  static const aeroBase = '0x940181a94A35A4569E4529A3CDfB74e38FD98631';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ XDC NETWORK (Chain ID: 50)                                                ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WXDC (Wrapped XDC) on XDC Network
  static const wxdcXdc = '0x951857744785E80e2De051c32EE7b25f9c458C42';

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on XDC (USDC Official)
  static const usdcXdc = '0xfA2958CB79b0491CC627c1557F441eF849Ca8eb1';

  /// xUSDT on XDC
  static const xusdtXdc = '0x1Cc0eb29b6E8d44d5d2C266e75c8Ea04B6C48F17';

  // ─────────────────────────────────────────────────────────────────────────────
  // XDC Ecosystem Tokens
  // ─────────────────────────────────────────────────────────────────────────────


  /// CIFI (Circularity Finance) on XDC
  static const cifiXdc = '0x1932192f2D3145083a37ebBf1065f457621F0647';

  /// REFI (Regenerative Finance) on XDC
  static const refiXdc = '0x2D010d707da973E194e41D7eA52617f8F969BD23';
  
  /// SRX (StorX) on XDC
  static const srxXdc = '0x5d5f074837f5d4618B3916ba74De1Bf9662a3fEd';

  /// PLI (Plugin) on XDC - Oracle network
  static const pliXdc = '0xff7412Ea7C8445C46a8254dFB557aC1E48094391';

  /// CGO (Comtech Gold) on XDC
  static const cgoXdc = '0xE98e1f92F3D81e8f8E6E8B7A9a4Bf7F5a1F5a1f5';

  /// XSP (XSwap Protocol) on XDC
  static const xspXdc = '0x36726235dAdbdb4658D33E62a249dCA7c4B2bC68';

  /// LMT (Lumenswap Token) on XDC
  static const lmtXdc = '0x3a4e4e3e2d2c2b2a2928272625242322212019';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ XDC APOTHEM TESTNET (Chain ID: 51)                                        ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  /// WXDC on Apothem Testnet
  static const wxdcApothem = '0x2a5fC52d8A563B2F181c6A527D422e1592C9ecFa';

  /// Test USDT on Apothem
  static const usdtApothem = '0xD4B5f10D61916Bd6E0860144a91Ac658dE8a1437';



  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ AVALANCHE C-CHAIN (Chain ID: 43114)                                       ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDC on Avalanche
  static const usdcAvalanche = '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E';

  /// USDC.e on Avalanche (Bridged)
  static const usdceAvalanche = '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664';

  /// USDT on Avalanche
  static const usdtAvalanche = '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7';

  /// USDT.e on Avalanche (Bridged)
  static const usdteAvalanche = '0xc7198437980c041c805A1EDcbA50c1Ce5db95118';

  /// DAI on Avalanche
  static const daiAvalanche = '0xd586E7F844cEa2F87f50152665BCbc2C279D8d70';

  /// FRAX on Avalanche
  static const fraxAvalanche = '0xD24C2Ad096400B6FBcd2ad8B24E7acBc21A1da64';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WAVAX (Wrapped AVAX) on Avalanche
  static const wavaxAvalanche = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7';

  /// WETH.e on Avalanche
  static const wethAvalanche = '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// JOE (Trader Joe) on Avalanche
  static const joeAvalanche = '0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd';

  /// PNG (Pangolin) on Avalanche
  static const pngAvalanche = '0x60781C2586D68229fde47564546784ab3fACA982';

  /// QI (BENQI) on Avalanche
  static const qiAvalanche = '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5';

  /// LINK on Avalanche
  static const linkAvalanche = '0x5947BB275c521040051D82396192181b413227A3';

  /// AAVE on Avalanche
  static const aaveAvalanche = '0x63a72806098Bd3D9520cC43356dD78afe5D386D9';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ BNB SMART CHAIN (Chain ID: 56)                                            ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ─────────────────────────────────────────────────────────────────────────────
  // Stablecoins
  // ─────────────────────────────────────────────────────────────────────────────

  /// USDT on BSC
  static const usdtBsc = '0x55d398326f99059fF775485246999027B3197955';

  /// USDC on BSC
  static const usdcBsc = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';

  /// BUSD on BSC
  static const busdBsc = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';

  /// DAI on BSC
  static const daiBsc = '0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3';

  // ─────────────────────────────────────────────────────────────────────────────
  // Wrapped Native
  // ─────────────────────────────────────────────────────────────────────────────

  /// WBNB (Wrapped BNB) on BSC
  static const wbnbBsc = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c';

  /// ETH on BSC
  static const ethBsc = '0x2170Ed0880ac9A755fd29B2688956BD959F933F8';

  // ─────────────────────────────────────────────────────────────────────────────
  // DeFi Tokens
  // ─────────────────────────────────────────────────────────────────────────────

  /// CAKE (PancakeSwap) on BSC
  static const cakeBsc = '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82';

  /// XVS (Venus) on BSC
  static const xvsBsc = '0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63';

  /// LINK on BSC
  static const linkBsc = '0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD';

  /// UNI on BSC
  static const uniBsc = '0xBf5140A22578168FD562DCcF235E5D43A02ce9B1';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ HEDERA (Non-EVM Token IDs)                                                ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  /// USDC on Hedera
  static const usdcHedera = '0.0.456858';

  /// HBARX (Staked HBAR) on Hedera
  static const hbarxHedera = '0.0.834116';

  /// SAUCE (SaucerSwap) on Hedera
  static const sauceHedera = '0.0.731861';

  /// HST (HeadStarter) on Hedera
  static const hstHedera = '0.0.1460003';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ SOLANA (Non-EVM - SPL Token Addresses)                                    ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  /// USDC on Solana
  static const usdcSolana = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  /// USDT on Solana
  static const usdtSolana = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';

  /// Wrapped SOL
  static const wsolSolana = 'So11111111111111111111111111111111111111112';

  /// RAY (Raydium) on Solana
  static const raySolana = '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R';

  /// SRM (Serum) on Solana
  static const srmSolana = 'SRMuApVNdxXokk5GT7XD5cUUgXMBCoAz2LHeuAoKWRt';

  /// ORCA on Solana
  static const orcaSolana = 'orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE';

  /// BONK on Solana
  static const bonkSolana = 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263';

  /// JUP (Jupiter) on Solana
  static const jupSolana = 'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN';

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ TOKEN INFO REGISTRY                                                       ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  /// Complete token information registry.
  /// Maps (chainId, address) to TokenInfo.
  static final Map<int, Map<String, TokenInfo>> _registry = {
    // Ethereum (1)
    1: {
      usdcEthereum: const TokenInfo(
        address: usdcEthereum,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      usdtEthereum: const TokenInfo(
        address: usdtEthereum,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      ),
      daiEthereum: const TokenInfo(
        address: daiEthereum,
        symbol: 'DAI',
        name: 'Dai Stablecoin',
        decimals: 18,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/9956/small/4943.png',
      ),
      wethEthereum: const TokenInfo(
        address: wethEthereum,
        symbol: 'WETH',
        name: 'Wrapped Ether',
        decimals: 18,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/2518/small/weth.png',
      ),
      linkEthereum: const TokenInfo(
        address: linkEthereum,
        symbol: 'LINK',
        name: 'Chainlink',
        decimals: 18,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/877/small/chainlink-new-logo.png',
      ),
      uniEthereum: const TokenInfo(
        address: uniEthereum,
        symbol: 'UNI',
        name: 'Uniswap',
        decimals: 18,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/12504/small/uni.jpg',
      ),
      aaveEthereum: const TokenInfo(
        address: aaveEthereum,
        symbol: 'AAVE',
        name: 'Aave',
        decimals: 18,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/12645/small/AAVE.png',
      ),
      stethEthereum: const TokenInfo(
        address: stethEthereum,
        symbol: 'stETH',
        name: 'Lido Staked ETH',
        decimals: 18,
        chainId: 1,
        logoUrl: 'https://assets.coingecko.com/coins/images/13442/small/steth_logo.png',
      ),
    },

    // Polygon (137)
    137: {
      usdcPolygon: const TokenInfo(
        address: usdcPolygon,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: 137,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      usdtPolygon: const TokenInfo(
        address: usdtPolygon,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        chainId: 137,
        logoUrl: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      ),
      daiPolygon: const TokenInfo(
        address: daiPolygon,
        symbol: 'DAI',
        name: 'Dai Stablecoin',
        decimals: 18,
        chainId: 137,
        logoUrl: 'https://assets.coingecko.com/coins/images/9956/small/4943.png',
      ),
      wmaticPolygon: const TokenInfo(
        address: wmaticPolygon,
        symbol: 'WMATIC',
        name: 'Wrapped Matic',
        decimals: 18,
        chainId: 137,
        logoUrl: 'https://assets.coingecko.com/coins/images/4713/small/polygon.png',
      ),
      wethPolygon: const TokenInfo(
        address: wethPolygon,
        symbol: 'WETH',
        name: 'Wrapped Ether',
        decimals: 18,
        chainId: 137,
        logoUrl: 'https://assets.coingecko.com/coins/images/2518/small/weth.png',
      ),
    },

    // Arbitrum (42161)
    42161: {
      usdcArbitrum: const TokenInfo(
        address: usdcArbitrum,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: 42161,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      usdtArbitrum: const TokenInfo(
        address: usdtArbitrum,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        chainId: 42161,
        logoUrl: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      ),
      wethArbitrum: const TokenInfo(
        address: wethArbitrum,
        symbol: 'WETH',
        name: 'Wrapped Ether',
        decimals: 18,
        chainId: 42161,
        logoUrl: 'https://assets.coingecko.com/coins/images/2518/small/weth.png',
      ),
      arbArbitrum: const TokenInfo(
        address: arbArbitrum,
        symbol: 'ARB',
        name: 'Arbitrum',
        decimals: 18,
        chainId: 42161,
        logoUrl: 'https://assets.coingecko.com/coins/images/16547/small/photo_2023-03-29_21.47.00.jpeg',
      ),
    },

    // Optimism (10)
    10: {
      usdcOptimism: const TokenInfo(
        address: usdcOptimism,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: 10,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      usdtOptimism: const TokenInfo(
        address: usdtOptimism,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        chainId: 10,
        logoUrl: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      ),
      wethOptimism: const TokenInfo(
        address: wethOptimism,
        symbol: 'WETH',
        name: 'Wrapped Ether',
        decimals: 18,
        chainId: 10,
        logoUrl: 'https://assets.coingecko.com/coins/images/2518/small/weth.png',
      ),
      opOptimism: const TokenInfo(
        address: opOptimism,
        symbol: 'OP',
        name: 'Optimism',
        decimals: 18,
        chainId: 10,
        logoUrl: 'https://assets.coingecko.com/coins/images/25244/small/Optimism.png',
      ),
    },

    // Base (8453)
    8453: {
      usdcBase: const TokenInfo(
        address: usdcBase,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: 8453,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      wethBase: const TokenInfo(
        address: wethBase,
        symbol: 'WETH',
        name: 'Wrapped Ether',
        decimals: 18,
        chainId: 8453,
        logoUrl: 'https://assets.coingecko.com/coins/images/2518/small/weth.png',
      ),
    },

    // XDC (50)
    50: {
      wxdcXdc: const TokenInfo(
        address: wxdcXdc,
        symbol: 'WXDC',
        name: 'Wrapped XDC',
        decimals: 18,
        chainId: 50,
        logoUrl: 'https://assets.coingecko.com/coins/images/2912/small/xdc-icon.png',
      ),
      pliXdc: const TokenInfo(
        address: pliXdc,
        symbol: 'PLI',
        name: 'Plugin',
        decimals: 18,
        chainId: 50,
        logoUrl: 'https://assets.coingecko.com/coins/images/20899/small/plugin.png',
      ),
      srxXdc: const TokenInfo(
        address: srxXdc,
        symbol: 'SRX',
        name: 'StorX',
        decimals: 18,
        chainId: 50,
        logoUrl: 'https://assets.coingecko.com/coins/images/14727/small/storx.png',
      ),
    },

    // Avalanche (43114)
    43114: {
      usdcAvalanche: const TokenInfo(
        address: usdcAvalanche,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: 43114,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      usdtAvalanche: const TokenInfo(
        address: usdtAvalanche,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        chainId: 43114,
        logoUrl: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      ),
      wavaxAvalanche: const TokenInfo(
        address: wavaxAvalanche,
        symbol: 'WAVAX',
        name: 'Wrapped AVAX',
        decimals: 18,
        chainId: 43114,
        logoUrl: 'https://assets.coingecko.com/coins/images/12559/small/Avalanche_Circle_RedWhite_Trans.png',
      ),
      joeAvalanche: const TokenInfo(
        address: joeAvalanche,
        symbol: 'JOE',
        name: 'Trader Joe',
        decimals: 18,
        chainId: 43114,
        logoUrl: 'https://assets.coingecko.com/coins/images/17569/small/JoesLogo.png',
      ),
    },

    // BSC (56)
    56: {
      usdtBsc: const TokenInfo(
        address: usdtBsc,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 18,
        chainId: 56,
        logoUrl: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      ),
      usdcBsc: const TokenInfo(
        address: usdcBsc,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 18,
        chainId: 56,
        logoUrl: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      ),
      busdBsc: const TokenInfo(
        address: busdBsc,
        symbol: 'BUSD',
        name: 'Binance USD',
        decimals: 18,
        chainId: 56,
        logoUrl: 'https://assets.coingecko.com/coins/images/9576/small/BUSD.png',
      ),
      wbnbBsc: const TokenInfo(
        address: wbnbBsc,
        symbol: 'WBNB',
        name: 'Wrapped BNB',
        decimals: 18,
        chainId: 56,
        logoUrl: 'https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png',
      ),
      cakeBsc: const TokenInfo(
        address: cakeBsc,
        symbol: 'CAKE',
        name: 'PancakeSwap',
        decimals: 18,
        chainId: 56,
        logoUrl: 'https://assets.coingecko.com/coins/images/12632/small/pancakeswap-cake-logo.png',
      ),
    },
  };

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║ TOKEN LOOKUP UTILITIES                                                    ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  /// Get token info by address and chain ID.
  static TokenInfo? getInfo(String address, {required int chainId}) {
    final chainTokens = _registry[chainId];
    if (chainTokens == null) return null;
    return chainTokens[address.toLowerCase()] ?? chainTokens[address];
  }

  /// Get all registered tokens for a chain.
  static List<TokenInfo> getTokensForChain(int chainId) {
    final chainTokens = _registry[chainId];
    if (chainTokens == null) return [];
    return chainTokens.values.toList();
  }

  /// Get all stablecoins for a chain.
  static List<TokenInfo> getStablecoins(int chainId) {
    return getTokensForChain(chainId)
        .where((t) => ['USDC', 'USDT', 'DAI', 'BUSD', 'FRAX', 'LUSD'].contains(t.symbol))
        .toList();
  }

  /// Get wrapped native token for a chain.
  static TokenInfo? getWrappedNative(int chainId) {
    final wrappedSymbols = ['WETH', 'WMATIC', 'WPOL', 'WBNB', 'WAVAX', 'WXDC', 'WSOL'];
    final tokens = getTokensForChain(chainId);
    try {
      return tokens.firstWhere((t) => wrappedSymbols.contains(t.symbol));
    } catch (_) {
      return null;
    }
  }

  /// Search tokens by symbol across all chains.
  static List<TokenInfo> searchBySymbol(String symbol) {
    final results = <TokenInfo>[];
    for (final chainTokens in _registry.values) {
      results.addAll(
        chainTokens.values.where(
          (t) => t.symbol.toLowerCase() == symbol.toLowerCase(),
        ),
      );
    }
    return results;
  }

  /// Get USDC address for a specific chain.
  static String? getUsdc(int chainId) {
    switch (chainId) {
      case 1:
        return usdcEthereum;
      case 137:
        return usdcPolygon;
      case 42161:
        return usdcArbitrum;
      case 10:
        return usdcOptimism;
      case 8453:
        return usdcBase;
      case 43114:
        return usdcAvalanche;
      case 56:
        return usdcBsc;
      default:
        return null;
    }
  }

  /// Get USDT address for a specific chain.
  static String? getUsdt(int chainId) {
    switch (chainId) {
      case 1:
        return usdtEthereum;
      case 137:
        return usdtPolygon;
      case 42161:
        return usdtArbitrum;
      case 10:
        return usdtOptimism;
      case 43114:
        return usdtAvalanche;
      case 56:
        return usdtBsc;
      case 50:
        return usdtXdc;
      default:
        return null;
    }
  }

  /// Get wrapped native token address for a chain.
  static String? getWrappedNativeAddress(int chainId) {
    switch (chainId) {
      case 1:
        return wethEthereum;
      case 137:
        return wmaticPolygon;
      case 42161:
        return wethArbitrum;
      case 10:
        return wethOptimism;
      case 8453:
        return wethBase;
      case 43114:
        return wavaxAvalanche;
      case 56:
        return wbnbBsc;
      case 50:
        return wxdcXdc;
      default:
        return null;
    }
  }
}

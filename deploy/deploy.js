let fs = require("fs");
let path = require("path");
const ethers = require("ethers")
const ERC20 = require("../build/ERC20.json")
const MockERC20 = require("../build/MockERC20.json")
const MockUniswapPair = require("../build/MockUniswapPair.json")
const BminingToken = require("../build/BminingToken.json")
const BTCParam = require("../build/BTCParam.json")
const BTCParamV2 = require("../build/BTCParamV2.json")
const POWLpStaking = require("../build/POWLpStaking.json")
const POWToken = require("../build/POWToken.json")
const POWStaking = require("../build/POWStaking.json")
const StakingPool = require("../build/StakingPool.json")
const TokenTreasury = require("../build/TokenTreasury.json")
const TokenExchange = require("../build/TokenExchange.json")
const Query = require("../build/Query.json")
const UniswapV2Factory = require("../thirdabis/UniswapV2Factory.json")
const UniswapV2Router02 = require("../thirdabis/UniswapV2Router02.json")

let tokens = {
  USDT: '',
  WBTC: '',
}

let Contracts = {
    BminingToken: BminingToken,
    BTCParam: BTCParam,
    BTCParamV2: BTCParamV2,
    POWToken: POWToken,
    POWStaking: POWStaking,
    POWLpStaking: POWLpStaking,
    POWLpStaking2: POWLpStaking,
    StakingPool: StakingPool,
    TokenTreasury: TokenTreasury,
    TokenExchange: TokenExchange,
    Query: Query,
}

let ContractAddress = {}

let lps = {
    BMT_USDT_LP: '',
    BBTC50_USDT_LP: '',
    WBTC_USDT_LP: '',
}

let config = {
    "url": "",
    "pk": "",
    "gasPrice": "10",
    "lpFactoryAddr": "",
    "lpRouterAddr": "",
    "tokens": {},
    "users":[]
}

if(fs.existsSync(path.join(__dirname, ".config.json"))) {
    let _config = JSON.parse(fs.readFileSync(path.join(__dirname, ".config.json")).toString());
    for(let k in config) {
        config[k] = _config[k];
    }
}

let ETHER_SEND_CONFIG = {
    gasPrice: ethers.utils.parseUnits(config.gasPrice, "gwei")
}
  

console.log("current endpoint ", config.url)
let provider = new ethers.providers.JsonRpcProvider(config.url)
let walletWithProvider = new ethers.Wallet(config.pk, provider)
let owner = walletWithProvider.address;
console.log('owner:', owner);


function getWallet(key = config.pk) {
  return new ethers.Wallet(key, provider)
}

const sleep = ms =>
  new Promise(resolve =>
    setTimeout(() => {
      resolve()
    }, ms)
  )

async function waitForMint(tx) {
//   console.log('tx:', tx)
  let result = null
  do {
    result = await provider.getTransactionReceipt(tx)
    await sleep(100)
  } while (result === null)
  await sleep(200)
}

async function getBlockNumber() {
  return await provider.getBlockNumber()
}

async function deployTokens() {
  let factory = new ethers.ContractFactory(
    MockERC20.abi,
    MockERC20.bytecode,
    walletWithProvider
  )
  for (let k in tokens) {
      if(k in config.tokens) {
          tokens[k] = config.tokens[k];
          continue;
      }
    let decimals = '18'
    if(k =='USDT') {
        decimals = '6'
    } else if(k == 'WBTC') {
        decimals = '8'
    }
    let ins = await factory.deploy(k,k,decimals,'1000000000000000000',ETHER_SEND_CONFIG)
    await waitForMint(ins.deployTransaction.hash)
    tokens[k] = ins.address
    console.log(k, ":", tokens[k])
  }

}

async function deployContracts() {
  for (let k in Contracts) {
    let factory = new ethers.ContractFactory(
      Contracts[k].abi,
      Contracts[k].bytecode,
      walletWithProvider
    )
    ins = await factory.deploy(ETHER_SEND_CONFIG)
    await waitForMint(ins.deployTransaction.hash)
    ContractAddress[k] = ins.address
    console.log(k, ':', ContractAddress[k])
  }
}

async function deploy() {
  
  // erc 20 Token
  console.log('deloy tokens...')
  await deployTokens()
  
  // business contract
  console.log('deloy contract...')
  await deployContracts()

}

async function initLP() {
  let _tokens = {}
  Object.assign(_tokens, tokens);
  _tokens['BminingToken'] = ContractAddress['BminingToken']
  _tokens['POWToken'] = ContractAddress['POWToken']
  for (let k in _tokens) {
    ins = new ethers.Contract(
      _tokens[k],
      MockERC20.abi,
      getWallet()
    )
      
      let allowance = await ins.allowance(owner, config.lpRouterAddr)
      console.log('allowance:', k, allowance.toString())
      if(allowance == '0'){
        console.log('approve', config.lpRouterAddr, k)
        tx = await ins.approve(config.lpRouterAddr, '10000000000000000000000000000', ETHER_SEND_CONFIG)
        await waitForMint(tx.hash)
      }
  }

    let deadline = parseInt(new Date().getTime()/1000) + 3600;
    let routerIns = new ethers.Contract(
      config.lpRouterAddr,
      UniswapV2Router02.abi,
      getWallet()
    )
    let factoryIns = new ethers.Contract(
      config.lpFactoryAddr,
      UniswapV2Factory.abi,
      getWallet()
    )
    console.log('init BMT_USDT_LP...', ContractAddress['BminingToken'], tokens['USDT'])
    tx = await routerIns.addLiquidity(
      ContractAddress['BminingToken'],
      tokens['USDT'],
      '1000000000000000000',
      '1000000',
      '1',
      '1',
      owner,
      deadline,
      ETHER_SEND_CONFIG
    )
    await waitForMint(tx.hash)

    lps.BMT_USDT_LP = await factoryIns.getPair(ContractAddress['BminingToken'], tokens['USDT'])

    console.log('init WBTC_USDT_LP...', tokens['WBTC'], tokens['USDT'])
    tx = await routerIns.addLiquidity(
      tokens['WBTC'],
      tokens['USDT'],
      '100000000',
      '40000000000',
      '1',
      '1',
      owner,
      deadline,
      ETHER_SEND_CONFIG
    )
    await waitForMint(tx.hash)

    lps.WBTC_USDT_LP = await factoryIns.getPair(tokens['WBTC'], tokens['USDT'])
    console.log('WBTC_USDT_LP:', lps.WBTC_USDT_LP)

    console.log('init BBTC50_USDT_LP...', ContractAddress['POWToken'], tokens['USDT'])
    tx = await routerIns.addLiquidity(
      ContractAddress['POWToken'],
      tokens['USDT'],
      '1000000000000000000',
      '100000000',
      '1',
      '1',
      owner,
      deadline,
      ETHER_SEND_CONFIG
    )
    await waitForMint(tx.hash)

    lps.BBTC50_USDT_LP = await factoryIns.getPair(ContractAddress['POWToken'], tokens['USDT'])
}

async function initExchange() {
                  
  console.log('TokenExchange init...')
  ins = new ethers.Contract(
      ContractAddress['TokenExchange'],
      TokenExchange.abi,
      getWallet()
    )

  tx = await ins.initialize(
      ContractAddress['POWToken'],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  tx = await ins.setExchangeRate(
      tokens['USDT'],
      100000,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  console.log('TokenExchange ownerMint...')
  tx = await ins.ownerMint(
      '10000000000000000000',
      owner,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

}

async function initLpStaking() {
  console.log('POWLpStaking init...')
  ins = new ethers.Contract(
      ContractAddress['POWLpStaking'],
      POWLpStaking.abi,
      getWallet()
    )

  tx = await ins.initialize(
      ContractAddress['POWToken'],
      lps.BBTC50_USDT_LP,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
   
  console.log('POWLpStaking2 init...')
  ins = new ethers.Contract(
      ContractAddress['POWLpStaking2'],
      POWLpStaking.abi,
      getWallet()
    )

  tx = await ins.initialize(
      ContractAddress['POWToken'],
      lps.BMT_USDT_LP,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
            
  console.log('StakingPool init...')
  ins = new ethers.Contract(
      ContractAddress['StakingPool'],
      StakingPool.abi,
      getWallet()
    )

  tx = await ins.initialize(
      ContractAddress['BminingToken'],
      lps.WBTC_USDT_LP,
      ContractAddress['TokenTreasury'],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  tx = await ins.setRewardRate(
      '10000000000000000000',
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
}

async function initBTCParamV2() {
  console.log('BTCParamV2 init...')
  ins = new ethers.Contract(
      ContractAddress['BTCParamV2'],
      BTCParamV2.abi,
      getWallet()
    )

  tx = await ins.initialize(
      '20607418304385',
      '6250000000000000000',
      lps.WBTC_USDT_LP,
      true,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  tx = await ins.addListener(
      ContractAddress['POWToken'],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
      
}

async function setStakingParam() {
  console.log('setStakingParam init...')
    ins = new ethers.Contract(
      ContractAddress['POWToken'],
      POWToken.abi,
      getWallet()
    )
  console.log('POWToken setStakingRewardWeights...')
  tx = await ins.setStakingRewardWeights(
      [ContractAddress['POWStaking'],
      ContractAddress['POWLpStaking'],
      ContractAddress['POWLpStaking2']],
      [20,30,50],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
  
  tx = await ins.setLpStakingIncomeWeights(
    [
      ContractAddress['POWLpStaking'],
      ContractAddress['POWLpStaking2']
    ],
      [80,20],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  console.log('POWToken setRewardRate...')
  tx = await ins.setRewardRate(
      '1000000000000000000',
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
  
}

async function initBminingToken() {
  console.log('BminingToken init...')
  ins = new ethers.Contract(
      ContractAddress['BminingToken'],
      BminingToken.abi,
      getWallet()
    )

  tx = await ins.initialize(
    ContractAddress['TokenTreasury'],
    owner,
    owner,
    ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
}

async function initBTCParam() {
  console.log('BTCParam init...')
  ins = new ethers.Contract(
      ContractAddress['BTCParam'],
      BTCParam.abi,
      getWallet()
    )

  tx = await ins.initialize(
      '20607418304385',
      '6250000000000000000',
      '38496',
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  tx = await ins.addListener(
      ContractAddress['POWToken'],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
}

async  function initPOWStaking() {
  console.log('POWStaking init...')
  ins = new ethers.Contract(
      ContractAddress['POWStaking'],
      POWStaking.abi,
      getWallet()
    )

  tx = await ins.initialize(
      ContractAddress['POWToken'],
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
}

async function initPOWToken() {          
  console.log('POWToken init...')
  ins = new ethers.Contract(
    ContractAddress['POWToken'],
    POWToken.abi,
    getWallet()
  )

  // ContractAddress['POWLpStaking'],
  // ContractAddress['POWLpStaking2'],
  tx = await ins.initialize(
      'BMining POW BTC-50W',
      'BBTC50',
      ContractAddress['POWStaking'],
      ContractAddress['POWLpStaking'],
      ContractAddress['POWLpStaking2'],
      ContractAddress['TokenExchange'],
      ContractAddress['BTCParam'],
      tokens['WBTC'],
      ContractAddress['BminingToken'],
      ContractAddress['TokenTreasury'],
      35000,
      58300,
      25000,
      100000,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)
}

async function initTokenTreasury() {
  console.log('TokenTreasury init...')
  ins = new ethers.Contract(
      ContractAddress['TokenTreasury'],
      TokenTreasury.abi,
      getWallet()
    )

  tx = await ins.setWhiteList(
      ContractAddress['POWToken'],
      true,
      ETHER_SEND_CONFIG
  )
  await waitForMint(tx.hash)

  ins = new ethers.Contract(
    tokens['WBTC'],
    MockERC20.abi,
    getWallet()
  )
  tx = await ins.transfer(ContractAddress['TokenTreasury'], '50000000000', ETHER_SEND_CONFIG)
  await waitForMint(tx.hash)
}

async function initialize() {
    await initBminingToken()
    await initBTCParam()
    await initPOWStaking()
    await initPOWToken()
    await initExchange();
    await initLP();
    await initBTCParamV2();
    await initLpStaking();
    await setStakingParam();
}

async function transfer() {

    tokens['BminingToken'] = ContractAddress['BminingToken'];
    for (let k in tokens) {
        if(k in config.tokens) continue;
        let value = '5000000000000000000000';
        if(k == 'USDT') {
            value = '5000000000';
        } else if(k === 'WBTC') {
            value = '500000000000';
        }
        ins = new ethers.Contract(
            tokens[k],
            MockERC20.abi,
            getWallet()
          )
        for(let user of config.users) {
          // console.log('transfer ',k,value, user)
            tx = await ins.transfer(user, value, ETHER_SEND_CONFIG)
            await waitForMint(tx.hash)
        }

        // console.log('transfer TokenTreasury ',k,value)
        tx = await ins.transfer(ContractAddress['TokenTreasury'], value, ETHER_SEND_CONFIG)
        await waitForMint(tx.hash)
    }

}

function writeDeployInfo() {
    let abis = {}
    abis['ERC20'] = MockERC20.abi;
    abis['BminingToken'] = BminingToken.abi;
    abis['POWLpStaking'] = POWLpStaking.abi;
    abis['POWToken'] = POWToken.abi;
    abis['StakingPool'] = StakingPool.abi;
    abis['TokenTreasury'] = TokenTreasury.abi;
    abis['TokenExchange'] = TokenExchange.abi;
    abis['UniswapPair'] = MockUniswapPair.abi;
    abis['BTCParam'] = BTCParam.abi;
    abis['BTCParamV2'] = BTCParamV2.abi;
    abis['Query'] = Query.abi;


  const abisPath = path.resolve(__dirname, `../build/abis.json`);
  fs.writeFileSync(abisPath, JSON.stringify(abis, null, 2));

  console.log(`Exported abisPath into ${abisPath}`);
}

async function run() {
    console.log('deploy...')
    await deploy()
    console.log('initialize...')
    await initialize()

    console.log('=====Contracts=====')
    for(let k in ContractAddress) {
      console.log(k, ContractAddress[k])
    }

    console.log('=====TOKENS=====')
    for(let k in tokens) {
      console.log(k, tokens[k])
    }
    for(let k in lps) {
        console.log(k, lps[k])
    }

    console.log('==========')
    console.log('transfer...')
    await transfer()

    writeDeployInfo()
}

if(process.argv[2] == 'abi') {
    writeDeployInfo()
} else {
    run()
}



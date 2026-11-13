const ganache=require('ganache'),{ethers}=require('ethers'),b=require('./build.json');
const log=[];const L=(...a)=>{const s=a.join(' ');log.push(s);console.log(s)};
const C=ethers.AbiCoder.defaultAbiCoder();
(async()=>{
 const provider=new ethers.BrowserProvider(ganache.provider({logging:{quiet:true},chain:{hardfork:'shanghai'},wallet:{totalAccounts:1}}));
 const deployer=await provider.getSigner();
 const vals=[1,2,3].map(()=>ethers.Wallet.createRandom()); // 3 local test validators, power 100 each
 const outsider=ethers.Wallet.createRandom();
 const validatorSet=vals.map(w=>({addr:w.address,power:100n}));
 const threshold=200n; // 2/3 of 300
 const domain=ethers.keccak256(C.encode(['string','string'],['checkpoint','layertest-4']));
 const latest=async()=>BigInt((await provider.getBlock('latest')).timestamp);
 const nowS=await latest(); const valTsMs=nowS*1000n;
 const Bridge=new ethers.ContractFactory(b.bridge.abi,b.bridge.evm.bytecode.object,deployer);
 const bridge=await Bridge.deploy(await deployer.getAddress(),domain); await bridge.waitForDeployment();
 const vsHash=ethers.keccak256(C.encode(['tuple(address addr,uint256 power)[]'],[validatorSet]));
 const checkpoint=ethers.keccak256(C.encode(['bytes32','uint256','uint256','bytes32'],[domain,threshold,valTsMs,vsHash]));
 await (await bridge.init(threshold,valTsMs,21n*24n*3600n,checkpoint)).wait();
 const queryId=ethers.keccak256(C.encode(['string','bytes'],['SpotPrice',C.encode(['string','string'],['eth','usd'])]));
 const Cons=new ethers.ContractFactory(b.consumer.abi,b.consumer.evm.bytecode.object,deployer);
 const consumer=await Cons.deploy(await bridge.getAddress(),queryId); await consumer.waitForDeployment();
 const ALL=new ethers.Interface([...b.consumer.abi,...b.bridge.abi].filter(x=>x.type==='error'));
 const SEP='0x74656c6c6f7243757272656e744174746573746174696f6e0000000000000000';
 const make=({qid=queryId,price=3000n*10n**18n,reportMs,attestMs,power=300n,signers=[0,1,2],badKey=false})=>{
  const report={value:C.encode(['uint256'],[price]),timestamp:reportMs,aggregatePower:power,previousTimestamp:0n,nextTimestamp:0n,lastConsensusTimestamp:reportMs};
  const att={queryId:qid,report,attestationTimestamp:attestMs};
  const digest=ethers.keccak256(C.encode(['bytes32','bytes32','bytes','uint256','uint256','uint256','uint256','bytes32','uint256','uint256'],[SEP,qid,report.value,report.timestamp,report.aggregatePower,report.previousTimestamp,report.nextTimestamp,checkpoint,attestMs,report.lastConsensusTimestamp]));
  const h=ethers.sha256(digest);
  const sigs=vals.map((w,i)=>{if(!signers.includes(i))return {v:0,r:ethers.ZeroHash,s:ethers.ZeroHash};const k=(badKey&&i===0)?outsider:w;const s=k.signingKey.sign(h);return {v:s.v,r:s.r,s:s.s}});
  return [att,validatorSet,sigs];
 };
 const H=3600n*1000n;
 const check=async(label,args,send=false)=>{try{if(send){await (await consumer.updatePrice(...args)).wait();L('PASS',label,'-> stored price',ethers.formatUnits(await consumer.price(),18))}else{await consumer.updatePrice.staticCall(...args);L('PASS',label,'(would be accepted)')}}catch(e){let n;try{n=ALL.parseError(e.data).name}catch{n=(e.shortMessage||e.message).slice(0,90)}L('REVERT',label,'->',n)}};
 const t=(await latest())*1000n;
 await check('1 valid: report 13h old, attested now, 3 of 3 signed',make({reportMs:t-13n*H,attestMs:t}),true);
 await check('2 replay the same attestation',make({reportMs:t-13n*H,attestMs:t}));
 await check('3 one signature from a key outside the validator set',make({reportMs:t-12n*H-60000n,attestMs:t,badKey:true}));
 await check('4 only 1 of 3 validators signed (100 < 200 power)',make({reportMs:t-12n*H-60000n,attestMs:t,signers:[0]}));
 await check('5 2 of 3 validators signed (200 power)',make({reportMs:t-12n*H-60000n,attestMs:t,signers:[0,1]}));
 await check('6 attestation 11 minutes old',make({reportMs:t-13n*H,attestMs:t-11n*60000n}));
 await check('7 report only 1 hour old (inside dispute window)',make({reportMs:t-1n*H,attestMs:t}));
 await check('8 wrong query id (BTC/USD)',make({qid:ethers.keccak256(C.encode(['string','bytes'],['SpotPrice',C.encode(['string','string'],['btc','usd'])])),reportMs:t-12n*H-60000n,attestMs:t}));
 await check('9 timestamps in SECONDS by mistake',make({reportMs:(t-13n*H)/1000n,attestMs:t/1000n}));
 await check('10 low reporter power (aggregatePower 50)',make({reportMs:t-12n*H-60000n,attestMs:t,power:50n}));
 require('fs').writeFileSync('test-log.txt',log.join('\n')+'\n');
})().catch(e=>{console.error(e);process.exit(1)});

const ganache=require('ganache'),{ethers}=require('ethers'),b=require('./build.json');
const log=[];const L=(...a)=>{const s=a.join(' ');log.push(s);console.log(s)};
(async()=>{
 const g=ganache.provider({logging:{quiet:true},chain:{hardfork:'shanghai'},wallet:{totalAccounts:1}});
 const provider=new ethers.BrowserProvider(g); const signer=await provider.getSigner();
 const Mock=new ethers.ContractFactory(b.mock.abi,b.mock.evm.bytecode.object,signer);
 const mock=await Mock.deploy(60,1); await mock.waitForDeployment();
 const id=ethers.id('ETH/USD');
 const Reader=new ethers.ContractFactory(b.reader.abi,b.reader.evm.bytecode.object,signer);
 const reader=await Reader.deploy(await mock.getAddress(),id); await reader.waitForDeployment();
 const ALL=new ethers.Interface([...b.reader.abi.filter(x=>x.type==='error'),...b.mock.abi.filter(x=>x.type==='error'),'error StalePrice()','error PriceFeedNotFound()']);
 const now=async()=>Number((await provider.getBlock('latest')).timestamp);
 const upd=async(price,conf,t)=>mock.createPriceFeedUpdateData(id,price,conf,-8,price,conf,t,t-1);
 const tryRead=async(label,ud=[])=>{try{const [p,e]=await reader.updateAndRead.staticCall(ud,{value:ud.length});L('PASS-read',label,'price',p.toString(),'expo',e.toString())}catch(err){let d; try{d=ALL.parseError(err.data).name}catch{d=(err.shortMessage||err.message).slice(0,80)}L('REVERT',label,'->',d)}};
 const decodeMock=(err)=>{try{return mock.interface.parseError(err.data).name}catch{return (err.shortMessage||'').slice(0,60)}};
 // 1 fresh price: $3,000.00000000, conf $1.5 (0.05%)
 let t=await now(); let data=await upd(300000000000n,150000000n,t);
 await (await reader.updateAndRead([data],{value:1})).wait(); await tryRead('1 fresh price (age 0s)');
 // 2 age 61s
 await provider.send('evm_increaseTime',[59]); await provider.send('evm_mine',[]); await tryRead('2a same price ~59s later');
 await provider.send('evm_increaseTime',[3]); await provider.send('evm_mine',[]); await tryRead('2b same price ~62s later');
 // 3 older update than stored is ignored silently
 data=await upd(310000000000n,150000000n,t-10); await (await mock.updatePriceFeeds([data],{value:1})).wait();
 L('INFO','3 posting an OLDER update succeeded (tx ok); stored price now', (await mock.getPriceUnsafe(id)).price.toString()); await tryRead('3 after older update');
 // 4 wide confidence 2%
 t=await now(); data=await upd(300000000000n,6000000000n,t); await (await mock.updatePriceFeeds([data],{value:1})).wait(); await tryRead('4 conf 2% of price');
 // 5 negative price
 t=await now()+1; await provider.send('evm_mine',[t]); data=await upd(-5n,0n,t); await (await mock.updatePriceFeeds([data],{value:1})).wait(); await tryRead('5 negative price');
 // 6 publish time in the future (+120s)
 t=await now(); data=await upd(300000000000n,150000000n,t+120); await (await mock.updatePriceFeeds([data],{value:1})).wait(); await tryRead('6 publishTime 120s in the future');
 // 7 no fee
 t=await now()+300; await provider.send('evm_mine',[t]); data=await upd(300000000000n,150000000n,t);
 try{await mock.updatePriceFeeds.staticCall([data],{value:0});L('UNEXPECTED no-fee ok')}catch(err){L('REVERT','7 update with 0 fee ->',decodeMock(err))}
 // 8 exact fee via getUpdateFee
 L('INFO','8 getUpdateFee for 1 update =',(await mock.getUpdateFee([data])).toString(),'wei');
 require('fs').writeFileSync('test-log.txt',log.join('\n')+'\n');
})().catch(e=>{console.error(e);process.exit(1)});

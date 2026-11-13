const ganache=require('ganache'),{ethers}=require('ethers'),b=require('./build.json');
const {WrapperBuilder}=require('@redstone-finance/evm-connector');
const tu=require('./node_modules/@redstone-finance/evm-connector/dist/src/helpers/test-utils.js');
const log=[];const L=(...a)=>{const s=a.join(' ');log.push(s);console.log(s)};
(async()=>{
 const provider=new ethers.providers.Web3Provider(ganache.provider({logging:{quiet:true},chain:{hardfork:'shanghai'},wallet:{totalAccounts:1}}));
 const signer=provider.getSigner();
 const authorised=[0,1,2,3,4].map(i=>tu.getMockSignerAddress(i));
 const f=new ethers.ContractFactory(b.abi,b.evm.bytecode.object,signer);
 const c=await f.deploy(authorised); await c.deployed();
 const iface=new ethers.utils.Interface([...b.abi.filter(x=>x.type==='error')]);
 const blockTs=async()=>(await provider.getBlock('latest')).timestamp;
 const pkg=(i,value,tsMs)=>tu.getMockPackageWithOneNumericDataPoint({mockSignerIndex:i,dataFeedId:'ETH',value,timestampMilliseconds:tsMs});
 const run=async(label,pkgs)=>{const w=WrapperBuilder.wrap(c).usingMockDataPackages(pkgs);let tx;try{tx=await w.populateTransaction.getEthPrice()}catch(e){L('POPULATE-FAIL',label,(e.message||'').slice(0,100));return}
 try{const raw=await provider.send('eth_call',[{to:c.address,data:tx.data},'latest']);L('PASS',label,'->',ethers.utils.formatUnits(ethers.BigNumber.from(raw),8))}catch(e){const d=e.data||(e.error&&e.error.data);let n;try{const p=iface.parseError(typeof d==='string'?d:(d.data||d.result));n=p.name+'('+p.args.map(String).join(', ')+')'}catch{n='raw:'+JSON.stringify(d).slice(0,120)}L('REVERT',label,'->',n)}};
 const runOld=async(label,pkgs)=>{try{const v=await WrapperBuilder.wrap(c).usingMockDataPackages(pkgs).getEthPrice();L('PASS',label,'->',ethers.utils.formatUnits(v,8))}catch(e){let n;const data=e.data||(e.error&&e.error.data)||(e.error&&e.error.error&&e.error.error.data);try{const p=iface.parseError(typeof data==='string'?data:data.data||data.result);n=p.name+'('+p.args.map(String).join(', ')+')'}catch{n=(e.reason||e.message).slice(0,120)}L('REVERT',label,'->',n)}};
 const now=(await blockTs())*1000;
 await run('1 three authorised signers, fresh, 3000/3001/3002',[pkg(0,3000,now),pkg(1,3001,now),pkg(2,3002,now)]);
 await run('2 only two signers',[pkg(0,3000,now),pkg(1,3001,now)]);
 await run('3 two authorised + one unknown signer (index 7)',[pkg(0,3000,now),pkg(1,3001,now),pkg(7,3002,now)]);
 await run('4 same signer three times',[pkg(0,3000,now),pkg(0,3000,now),pkg(0,3000,now)]);
 await run('5 data 4 minutes old',[pkg(0,3000,now-240000),pkg(1,3001,now-240000),pkg(2,3002,now-240000)]);
 await run('6 data 2 minutes in the future',[pkg(0,3000,now+120000),pkg(1,3001,now+120000),pkg(2,3002,now+120000)]);
 await run('7 one signer reports 9999 (manipulated)',[pkg(0,3000,now),pkg(1,3001,now),pkg(2,9999,now)]);
 await run('8 different timestamps between packages',[pkg(0,3000,now),pkg(1,3001,now-1000),pkg(2,3002,now)]);
 try{await c.getEthPrice();L('UNEXPECTED plain call ok')}catch(e){let n;const d=(e.error&&e.error.data&&(e.error.data.data||e.error.data))||e.data;try{n=iface.parseError(typeof d==='string'?d:d.result).name}catch{n=(e.reason||e.message).slice(0,100)}L('REVERT','9 plain call without a RedStone payload ->',n)}
 require('fs').writeFileSync('test-log.txt',log.join('\n')+'\n');
})().catch(e=>{console.error(e);process.exit(1)});

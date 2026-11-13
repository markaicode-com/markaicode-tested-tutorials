const ganache=require('ganache'),{ethers}=require('ethers'),b=require('./build.json');
const log=[];const L=(...a)=>{const s=a.join(' ');log.push(s);console.log(s)};
const B32=s=>ethers.encodeBytes32String(s); const E=x=>ethers.parseEther(String(x)); const F=x=>ethers.formatEther(x);
(async()=>{
 const provider=new ethers.BrowserProvider(ganache.provider({logging:{quiet:true},chain:{hardfork:'london'},wallet:{totalAccounts:3}}));
 const [admin,asserter,disputer]=await Promise.all([0,1,2].map(i=>provider.getSigner(i)));
 const D=async(k,...args)=>{const c=await (await new ethers.ContractFactory(b[k].abi,b[k].evm.bytecode.object,admin).deploy(...args)).waitForDeployment();return c};
 const token=await D('erc20','Bond Token','BOND',18);
 const finder=await D('finder');
 const store=await D('store',{rawValue:0},{rawValue:0},ethers.ZeroAddress);
 const idw=await D('idw'); const aw=await D('aw');
 const mock=await D('mock',await finder.getAddress(),ethers.ZeroAddress);
 await (await store.setFinalFee(await token.getAddress(),{rawValue:E(50)})).wait();
 await (await idw.addSupportedIdentifier(B32('ASSERT_TRUTH'))).wait();
 await (await aw.addToWhitelist(await token.getAddress())).wait();
 for (const [n,c] of [['Store',store],['IdentifierWhitelist',idw],['CollateralWhitelist',aw],['Oracle',mock]]) await (await finder.changeImplementationAddress(B32(n),await c.getAddress())).wait();
 const oo=await D('oo',await finder.getAddress(),await token.getAddress(),7200);
 const claim=await D('claim',await oo.getAddress(),await token.getAddress());
 for (const s of [asserter,disputer]) await (await token.allocateTo(await s.getAddress(),E(1000))).wait();
 const bond=await oo.getMinimumBond(await token.getAddress());
 L('INFO','final fee 50 BOND, burnedBondPercentage',F(await oo.burnedBondPercentage()),'-> minimum bond',F(bond),'BOND; default liveness',(await oo.defaultLiveness()).toString(),'s');
 const ALL=new ethers.Interface([...b.oo.abi,...b.claim.abi].filter(x=>x.type==='error'));
 const why=e=>e.reason||e.shortMessage||String(e.message).slice(0,80);
 const bal=async s=>F(await token.balanceOf(await s.getAddress()));
 const ac=claim.connect(asserter);
 const assert=async(text)=>{await (await token.connect(asserter).approve(await claim.getAddress(),bond)).wait();const rc=await (await ac.assertClaim(text)).wait();for(const lg of rc.logs){try{const ev=oo.interface.parseLog(lg);if(ev&&ev.name==='AssertionMade')return ev.args.assertionId}catch{}}throw new Error('no AssertionMade event')};
 const adv=async s=>{await provider.send('evm_increaseTime',[s]);await provider.send('evm_mine',[])};
 // A: undisputed
 L('INFO','A asserter balance before',await bal(asserter));
 const idA=await assert('ETH/USD closed above 3000 on 2026-11-13');
 try{await claim.isTrue(idA);L('UNEXPECTED read before settle')}catch(e){L('REVERT','A read result right away ->',why(e))}
 try{await oo.settleAssertion.staticCall(idA);L('UNEXPECTED settle early')}catch(e){L('REVERT','A settle after 0s ->',why(e))}
 await adv(7201);
 await (await oo.settleAssertion(idA)).wait();
 L('PASS','A no dispute, settled after 2h ->',await claim.isTrue(idA),'| asserter balance',await bal(asserter));
 // B: disputed, DVM says false
 const idB=await assert('ETH/USD closed above 9000 on 2026-11-13');
 await (await token.connect(disputer).approve(await oo.getAddress(),bond)).wait();
 await (await oo.connect(disputer).disputeAssertion(idB,await disputer.getAddress())).wait();
 let q=(await mock.getPendingQueries()); L('INFO','B after dispute, pending DVM requests:',q.length);
 try{await oo.settleAssertion.staticCall(idB);L('UNEXPECTED settle before DVM')}catch(e){L('REVERT','B settle before the DVM answers ->',why(e))}
 await (await mock.pushPrice(q[0].identifier,q[0].time,q[0].ancillaryData,0)).wait();
 await (await oo.settleAssertion(idB)).wait();
 L('PASS','B disputed, DVM says false ->',await claim.isTrue(idB),'| asserter',await bal(asserter),'| disputer',await bal(disputer),'| store got',F(await token.balanceOf(await store.getAddress())));
 // C: disputed, DVM says true
 const idC=await assert('ETH/USD closed above 2000 on 2026-11-13');
 await (await token.connect(disputer).approve(await oo.getAddress(),bond)).wait();
 await (await oo.connect(disputer).disputeAssertion(idC,await disputer.getAddress())).wait();
 q=await mock.getPendingQueries();
 await (await mock.pushPrice(q[0].identifier,q[0].time,q[0].ancillaryData,ethers.parseEther('1'))).wait();
 await (await oo.settleAssertion(idC)).wait();
 L('PASS','C disputed, DVM says true ->',await claim.isTrue(idC),'| asserter',await bal(asserter),'| disputer',await bal(disputer));
 // D: dispute after liveness
 const idD=await assert('late dispute test');
 await adv(7201);
 await (await token.connect(disputer).approve(await oo.getAddress(),bond)).wait();
 try{await oo.connect(disputer).disputeAssertion.staticCall(idD,await disputer.getAddress());L('UNEXPECTED late dispute ok')}catch(e){L('REVERT','D dispute after 2h ->',why(e))}
 require('fs').writeFileSync('test-log.txt',log.join('\n')+'\n');
})().catch(e=>{console.error(e);process.exit(1)});

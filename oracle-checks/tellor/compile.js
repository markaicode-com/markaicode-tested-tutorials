const solc=require('solc'),fs=require('fs'),path=require('path');
const S=f=>({content:fs.readFileSync(f,'utf8')});
const input={language:'Solidity',sources:{'contracts/SafeTellorPriceConsumer.sol':S('contracts/SafeTellorPriceConsumer.sol'),'usingtellorlayer/contracts/bridge/TellorDataBridge.sol':S('node_modules/usingtellorlayer/contracts/bridge/TellorDataBridge.sol')},settings:{evmVersion:'paris',optimizer:{enabled:true,runs:200},outputSelection:{'*':{'*':['abi','evm.bytecode.object']}}}};
const imp=p=>{const f=path.join('node_modules',p);return fs.existsSync(f)?{contents:fs.readFileSync(f,'utf8')}:{error:'nf '+p}};
const out=JSON.parse(solc.compile(JSON.stringify(input),{import:imp}));
const errs=(out.errors||[]).filter(e=>e.severity==='error'); if(errs.length){console.log(errs.map(e=>e.formattedMessage).join('\n'));process.exit(1)}
console.log('solc',solc.version());
fs.writeFileSync('build.json',JSON.stringify({consumer:out.contracts['contracts/SafeTellorPriceConsumer.sol'].SafeTellorPriceConsumer,bridge:out.contracts['usingtellorlayer/contracts/bridge/TellorDataBridge.sol'].TellorDataBridge}));

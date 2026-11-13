const solc=require('solc'),fs=require('fs'),path=require('path');
const input={language:'Solidity',sources:{'contracts/AuditedRedstoneConsumer.sol':{content:fs.readFileSync('contracts/AuditedRedstoneConsumer.sol','utf8')}},settings:{evmVersion:'shanghai',optimizer:{enabled:true,runs:200},outputSelection:{'*':{'*':['abi','evm.bytecode.object']}}}};
const imp=p=>{const f=path.join('node_modules',p);return fs.existsSync(f)?{contents:fs.readFileSync(f,'utf8')}:{error:'nf '+p}};
const out=JSON.parse(solc.compile(JSON.stringify(input),{import:imp}));
const errs=(out.errors||[]).filter(e=>e.severity==='error'); if(errs.length){console.log(errs.map(e=>e.formattedMessage).join('\n'));process.exit(1)}
console.log('solc',solc.version()); fs.writeFileSync('build.json',JSON.stringify(out.contracts['contracts/AuditedRedstoneConsumer.sol'].AuditedRedstoneConsumer));

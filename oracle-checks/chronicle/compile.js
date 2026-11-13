const solc=require('solc'),fs=require('fs'),path=require('path');
const S=f=>({content:fs.readFileSync(f,'utf8')});
const input={language:'Solidity',sources:{'contracts/ChronicleReader.sol':S('contracts/ChronicleReader.sol'),'contracts/test/MockChronicle.sol':S('contracts/test/MockChronicle.sol')},settings:{evmVersion:'shanghai',optimizer:{enabled:true,runs:200},outputSelection:{'*':{'*':['abi','evm.bytecode.object']}}}};
const imp=p=>{const f=p.startsWith('chronicle-std/')?p:path.join('node_modules',p);return fs.existsSync(f)?{contents:fs.readFileSync(f,'utf8')}:{error:'nf '+p}};
const out=JSON.parse(solc.compile(JSON.stringify(input),{import:imp}));
const errs=(out.errors||[]).filter(e=>e.severity==='error'); if(errs.length){console.log(errs.map(e=>e.formattedMessage).join('\n'));process.exit(1)}
console.log('solc',solc.version());
fs.writeFileSync('build.json',JSON.stringify({reader:out.contracts['contracts/ChronicleReader.sol'].ChronicleReader,mock:out.contracts['contracts/test/MockChronicle.sol'].MockChronicle}));

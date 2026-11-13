const solc=require('solc'),fs=require('fs'),path=require('path');
const src={'contracts/SafePriceReader.sol':{content:fs.readFileSync('contracts/SafePriceReader.sol','utf8')},
 '@pythnetwork/pyth-sdk-solidity/MockPyth.sol':{content:fs.readFileSync('node_modules/@pythnetwork/pyth-sdk-solidity/MockPyth.sol','utf8')}};
const input={language:'Solidity',sources:src,settings:{optimizer:{enabled:true,runs:200},evmVersion:'shanghai',outputSelection:{'*':{'*':['abi','evm.bytecode.object']}}}};
const imp=p=>{const f=path.join('node_modules',p);return fs.existsSync(f)?{contents:fs.readFileSync(f,'utf8')}:{error:'nf '+p}};
const out=JSON.parse(solc.compile(JSON.stringify(input),{import:imp}));
const errs=(out.errors||[]).filter(e=>e.severity==='error'); if(errs.length){console.log(errs.map(e=>e.formattedMessage).join('\n'));process.exit(1)}
console.log('solc',solc.version(),'warnings',(out.errors||[]).length);
fs.writeFileSync('build.json',JSON.stringify({reader:out.contracts['contracts/SafePriceReader.sol'].SafePriceReader,mock:out.contracts['@pythnetwork/pyth-sdk-solidity/MockPyth.sol'].MockPyth}));

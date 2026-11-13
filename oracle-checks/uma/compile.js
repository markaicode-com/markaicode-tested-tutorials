const solc=require('solc'),fs=require('fs'),path=require('path');
const U='src/package/contracts/';
const files={'contracts/OptimisticClaim.sol':'contracts/OptimisticClaim.sol',
 'uma/OptimisticOracleV3.sol':U+'optimistic-oracle-v3/implementation/OptimisticOracleV3.sol',
 'uma/Finder.sol':U+'data-verification-mechanism/implementation/Finder.sol',
 'uma/Store.sol':U+'data-verification-mechanism/implementation/Store.sol',
 'uma/IdentifierWhitelist.sol':U+'data-verification-mechanism/implementation/IdentifierWhitelist.sol',
 'uma/AddressWhitelist.sol':U+'common/implementation/AddressWhitelist.sol',
 'uma/MockOracleAncillary.sol':U+'data-verification-mechanism/test/MockOracleAncillary.sol',
 'uma/TestnetERC20.sol':U+'common/implementation/TestnetERC20.sol'};
// use real file paths as source keys so relative imports resolve
const sources={};for(const [k,f] of Object.entries(files))sources[f]={content:fs.readFileSync(f,'utf8')};
const imp=p=>{let f=p;if(p.startsWith('@uma/core/'))f='src/package/'+p.slice('@uma/core/'.length);else if(p.startsWith('@openzeppelin/'))f='node_modules/'+p;return fs.existsSync(f)?{contents:fs.readFileSync(f,'utf8')}:{error:'nf '+p}};
const input={language:'Solidity',sources,settings:{evmVersion:'london',optimizer:{enabled:true,runs:200},outputSelection:{'*':{'*':['abi','evm.bytecode.object']}}}};
const out=JSON.parse(solc.compile(JSON.stringify(input),{import:imp}));
const errs=(out.errors||[]).filter(e=>e.severity==='error'); if(errs.length){console.log(errs.map(e=>e.formattedMessage).join('\n').slice(0,3000));process.exit(1)}
const pick=(f,n)=>out.contracts[f][n];
fs.writeFileSync('build.json',JSON.stringify({claim:pick(files['contracts/OptimisticClaim.sol'],'OptimisticClaim'),oo:pick(files['uma/OptimisticOracleV3.sol'],'OptimisticOracleV3'),finder:pick(files['uma/Finder.sol'],'Finder'),store:pick(files['uma/Store.sol'],'Store'),idw:pick(files['uma/IdentifierWhitelist.sol'],'IdentifierWhitelist'),aw:pick(files['uma/AddressWhitelist.sol'],'AddressWhitelist'),mock:pick(files['uma/MockOracleAncillary.sol'],'MockOracleAncillary'),erc20:pick(files['uma/TestnetERC20.sol'],'TestnetERC20')}));
console.log('solc',solc.version());

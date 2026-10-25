'use strict';
// Read ASAR without extracting or modifying the signed application.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function inspect(archive){
 const fd=fs.openSync(archive,'r');
 try{
  const h=Buffer.alloc(16);if(fs.readSync(fd,h,0,16,0)!==16)throw Error('Short ASAR header');
  const headerSize=h.readUInt32LE(4),jsonSize=h.readUInt32LE(12);
  if(jsonSize>64*1024*1024||headerSize<jsonSize+8)throw Error('Invalid ASAR header');
  const json=Buffer.alloc(jsonSize);fs.readSync(fd,json,0,jsonSize,16);const tree=JSON.parse(json),base=8+headerSize;
  let languageFile=null,endpointFile=null,updaterIdentity=false,files=0;
  function walk(node,prefix=''){
   for(const [name,e] of Object.entries(node.files||{})){
    const rel=prefix+name;if(e.files){walk(e,rel+'/');continue}
    if(!/\.(?:js|cjs|mjs)$/.test(rel)||!e.size||e.size>32*1024*1024||e.link)continue;
    let text;if(e.unpacked)text=fs.readFileSync(path.join(archive+'.unpacked',rel),'utf8');
    else{const b=Buffer.alloc(e.size);const n=fs.readSync(fd,b,0,b.length,base+Number(e.offset));if(n!==b.length)throw Error('Truncated ASAR entry');text=b.toString('utf8')}
    files++;
    // Require neighboring layer/field evidence, not merely a coincidental numeric string.
    if(/72216192[\s\S]{0,300}enable_i18n[\s\S]{0,300}locale_source/.test(text))languageFile=rel;
    if(text.includes('https://ab.chatgpt.com/v1'))endpointFile=rel;
    if(text.includes('getCurrentPackageFamily')&&text.includes('missing current windows package family'))updaterIdentity=true;
   }
  }
  walk(tree);
  const structureMatched=!!(languageFile&&endpointFile&&updaterIdentity);
  return {adapter:'statsig-language-72216192-v1',structureMatched,languageFile,endpointFile,updaterIdentity,filesScanned:files,headerSha256:crypto.createHash('sha256').update(json).digest('hex'),runtimeVerified:false};
 }finally{fs.closeSync(fd)}
}
module.exports={inspect};
if(require.main===module){try{const r=inspect(process.argv[2]);console.log(JSON.stringify(r));if(!r.structureMatched)process.exitCode=2}catch(e){console.error(e.message);process.exitCode=1}}

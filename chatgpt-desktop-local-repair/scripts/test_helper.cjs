'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http'),tls=require('node:tls'),vm=require('node:vm'),assert=require('node:assert/strict'),zlib=require('node:zlib');
const assets=path.join(__dirname,'../assets/windows'),{generate}=require(path.join(assets,'certificate.cjs')),{createProxy}=require(path.join(assets,'proxy.cjs'));
async function connect(host,body,cert){return new Promise((resolve,reject)=>{const req=http.request({host:'127.0.0.1',port:18769,method:'CONNECT',path:host});req.on('error',reject);req.on('connect',(r,s)=>{if(r.statusCode!==200){s.destroy();resolve({status:r.statusCode});return}const secure=tls.connect({socket:s,servername:'ab.chatgpt.com',ca:cert},()=>secure.write(Buffer.concat([Buffer.from(`POST /v1/initialize HTTP/1.1\r\nHost: ab.chatgpt.com\r\nContent-Type: application/json\r\nContent-Length: ${body.length}\r\nConnection: close\r\n\r\n`),body])));let data='';secure.on('data',b=>data+=b);secure.on('end',()=>resolve({status:r.statusCode,data}));secure.on('error',reject)});req.end()})}
(async()=>{const dir=fs.mkdtempSync(path.join(os.tmpdir(),'chatgpt-repair-test-'));let proxy;
try{const a=generate(dir),b=generate(dir);assert.notEqual(a.spki,b.spki,'Every installation needs a distinct private key');const cert=fs.readFileSync(path.join(dir,'proxy-cert.pem'));proxy=createProxy({directory:dir});await proxy.start();
const context={};vm.createContext(context);vm.runInContext(await(await fetch('http://127.0.0.1:18769/proxy.pac')).text(),context);
assert.match(context.FindProxyForURL('https://ab.chatgpt.com/v1/initialize','AB.CHATGPT.COM'),/^PROXY 127\.0\.0\.1:18769$/);
for(const host of ['api.example.com','persistent.oaistatic.com','chatgpt.com','ab.chatgpt.com.evil.example'])assert.equal(context.FindProxyForURL('https://'+host,host),'DIRECT');
assert.equal((await connect('api.example.com:443',Buffer.alloc(0),cert)).status,403);
for(const body of [Buffer.from(JSON.stringify({user:{locale:'zh-CN'}})),zlib.gzipSync(Buffer.from(JSON.stringify({user:{locale:'zh-CN'}}))),Buffer.from(Buffer.from(JSON.stringify({user:{locale:'zh-CN'}})).toString('base64').split('').reverse().join(''))]){
const result=await connect('ab.chatgpt.com:443',body,cert);assert.match(result.data,/HTTP\/1\.1 200/);const json=JSON.parse(result.data.split('\r\n\r\n')[1]);assert.equal(json.layer_configs['72216192'].value.enable_i18n,true);assert.equal(json.user.locale,'zh-CN');}
console.log(JSON.stringify({passed:true,uniqueLocalKeys:true,verifiedTLS:true,thirdPartyApiAndUpdaterDirect:true,otherConnectRejected:true,compressedAndEncodedRequests:true}));
}finally{if(proxy)await proxy.close();fs.rmSync(dir,{recursive:true,force:true})}})().catch(e=>{console.error(e);process.exitCode=1});

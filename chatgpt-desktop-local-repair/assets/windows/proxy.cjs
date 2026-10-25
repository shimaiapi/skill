'use strict';
const http=require('node:http'),tls=require('node:tls'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),zlib=require('node:zlib');
const PORT=18769,HOST='127.0.0.1';
function payload(user={},stableID){return {has_updates:true,time:Date.now(),user,...(stableID?{stableID}:{}),feature_gates:{},dynamic_configs:{},layer_configs:{'72216192':{name:'72216192',value:{enable_i18n:true,locale_source:'SYSTEM'},rule_id:'app-local-language',secondary_exposures:[],explicit_parameters:['enable_i18n','locale_source'],undelegated_secondary_exposures:[]}},sdkParams:{}};}
function decode(raw){if(raw[0]===31&&raw[1]===139)raw=zlib.gunzipSync(raw,{maxOutputLength:2097152});const s=raw.toString('utf8');try{return JSON.parse(s)}catch{return JSON.parse(Buffer.from(s.split('').reverse().join(''),'base64').toString('utf8'))}}
function createProxy({directory=__dirname,onEvent=()=>{}}={}){
 const cert=fs.readFileSync(path.join(directory,'proxy-cert.pem')),key=fs.readFileSync(path.join(directory,'proxy-key.pem'));
 const spki=crypto.createHash('sha256').update(new crypto.X509Certificate(cert).publicKey.export({type:'spki',format:'der'})).digest('base64');
 const context=tls.createSecureContext({cert,key,minVersion:'TLSv1.2'}),sockets=new Set();
 const track=s=>{sockets.add(s);s.on('close',()=>sockets.delete(s));s.on('error',()=>{});return s};
 const local=new http.Server(async(req,res)=>{const start=Date.now();let url;try{url=new URL(req.url,'https://ab.chatgpt.com')}catch{res.writeHead(400).end();return}res.setHeader('Cache-Control','no-store');
  if(req.method==='POST'&&/^\/v1\/(initialize|download_config_specs)\/?$/.test(url.pathname)){
   let chunks=[],size=0;try{for await(const c of req){size+=c.length;if(size>2097152)throw Error('Body limit');chunks.push(c)}let input=decode(Buffer.concat(chunks));const response=payload(input.user??{},input.statsigMetadata?.stableID);res.setHeader('Content-Type','application/json');res.end(JSON.stringify(response));onEvent({event:'language-config',path:url.pathname,ms:Date.now()-start});}catch{res.writeHead(400).end('{}');onEvent({event:'invalid-request',path:url.pathname})}
  }else if(['/v1/sdk_exception','/v1/rgstr','/v1/log_event'].includes(url.pathname)){req.resume();res.writeHead(204).end();onEvent({event:'ack',path:url.pathname})}
  else {req.resume();res.writeHead(404).end('{}');onEvent({event:'unsupported',path:url.pathname})}
 });
 const server=http.createServer((req,res)=>{if(req.url==='/proxy.pac'){res.setHeader('Content-Type','application/x-ns-proxy-autoconfig');res.setHeader('Cache-Control','no-store');res.end(`function FindProxyForURL(url,host){return host.toLowerCase()==='ab.chatgpt.com'?'PROXY ${HOST}:${PORT}':'DIRECT';}`);onEvent({event:'pac'})}else if(req.url==='/health'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({service:'codex-app-local-language',spki,port:PORT}))}else res.writeHead(404).end()});
 server.on('connection',track);server.on('connect',(req,socket,head)=>{if(req.url.toLowerCase()!=='ab.chatgpt.com:443'){socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');return}socket.write('HTTP/1.1 200 Connection Established\r\n\r\n');if(head.length)socket.unshift(head);const secure=track(new tls.TLSSocket(socket,{isServer:true,secureContext:context,ALPNProtocols:['http/1.1']}));local.emit('connection',secure);onEvent({event:'connect',host:'ab.chatgpt.com'})});
 return {spki,port:PORT,events:onEvent,start:()=>new Promise((resolve,reject)=>{server.once('error',reject);server.listen(PORT,HOST,resolve)}),close:()=>new Promise(resolve=>{for(const s of sockets)s.destroy();server.close(resolve)})};
}
module.exports={createProxy,payload,decode};
if(require.main===module){const proxy=createProxy({onEvent:e=>{if(e.event==='language-config')console.log(JSON.stringify({at:new Date().toISOString(),...e}))}});proxy.start().then(()=>console.log(JSON.stringify({ready:true,port:PORT}))).catch(e=>{console.error(e.message);process.exitCode=1});for(const signal of ['SIGTERM','SIGINT'])process.on(signal,async()=>{await proxy.close();process.exit()})}

'use strict';
// Generate a fresh certificate entirely in-process; never touch a certificate store.
const c=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const cat=(...v)=>Buffer.concat(v.flat());
function der(tag,data){data=Buffer.from(data);let n=data.length,b=[];do{b.unshift(n&255);n>>>=8}while(n);return cat(Buffer.from([tag,...(data.length<128?[data.length]:[128|b.length,...b])]),data)}
const seq=(...v)=>der(0x30,cat(...v)),oid=h=>der(6,Buffer.from(h,'hex'));
const pem=(label,b)=>`-----BEGIN ${label}-----\n${b.toString('base64').match(/.{1,64}/g).join('\n')}\n-----END ${label}-----\n`;
function generate(directory){
 const {privateKey,publicKey}=c.generateKeyPairSync('rsa',{modulusLength:2048});
 const alg=seq(oid('2a864886f70d01010b'),der(5,Buffer.alloc(0)));
 const name=seq(der(0x31,seq(oid('550403'),der(12,Buffer.from('ab.chatgpt.com')))));
 const time=d=>der(0x18,Buffer.from(d.toISOString().replace(/[-:T]/g,'').replace(/\.\d{3}Z$/,'Z')));
 const now=new Date(),expiry=new Date(now.getTime()+365*86400000);
 const serial=c.randomBytes(16);serial[0]&=0x7f;serial[0]|=1;
 const san=seq(oid('551d11'),der(4,seq(der(0x82,Buffer.from('ab.chatgpt.com')))));
 const basic=seq(oid('551d13'),der(1,Buffer.from([255])),der(4,seq()));
 const tbs=seq(der(0xa0,der(2,Buffer.from([2]))),der(2,serial),alg,name,seq(time(new Date(now.getTime()-300000)),time(expiry)),name,publicKey.export({type:'spki',format:'der'}),der(0xa3,seq(san,basic)));
 const cert=seq(tbs,alg,der(3,cat(Buffer.from([0]),c.sign('sha256',tbs,privateKey))));
 fs.writeFileSync(path.join(directory,'proxy-key.pem'),privateKey.export({type:'pkcs8',format:'pem'}),{mode:0o600});
 fs.writeFileSync(path.join(directory,'proxy-cert.pem'),pem('CERTIFICATE',cert));
 const x=new c.X509Certificate(cert);if(!x.verify(publicKey)||!x.checkHost('ab.chatgpt.com'))throw Error('Generated certificate failed validation');
 return {expires:x.validTo,spki:c.createHash('sha256').update(x.publicKey.export({type:'spki',format:'der'})).digest('base64')};
}
module.exports={generate};
if(require.main===module)console.log(JSON.stringify(generate(process.argv[2]||__dirname)));

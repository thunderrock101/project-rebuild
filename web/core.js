'use strict';
(() => {
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  const b64 = bytes => { let s=''; for (const b of new Uint8Array(bytes)) s+=String.fromCharCode(b); return btoa(s); };
  const unb64 = value => Uint8Array.from(atob(value), c=>c.charCodeAt(0));
  async function deriveKey(password,salt){const material=await crypto.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveKey']);return crypto.subtle.deriveKey({name:'PBKDF2',salt,iterations:310000,hash:'SHA-256'},material,{name:'AES-GCM',length:256},false,['encrypt','decrypt']);}
  async function encryptEnvelope(data,key,salt){const iv=crypto.getRandomValues(new Uint8Array(12));const cipher=await crypto.subtle.encrypt({name:'AES-GCM',iv},key,enc.encode(JSON.stringify(data)));return {format:'project-rebuild-encrypted-backup',version:1,kdf:'PBKDF2-SHA256',iterations:310000,cipher:'AES-256-GCM',salt:b64(salt),iv:b64(iv),data:b64(cipher),updatedAt:new Date().toISOString()};}
  async function decryptEnvelope(envelope,key){if(!envelope||envelope.format!=='project-rebuild-encrypted-backup'||envelope.version!==1||envelope.kdf!=='PBKDF2-SHA256'||envelope.cipher!=='AES-256-GCM')throw Error('Unsupported encrypted backup.');const plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:unb64(envelope.iv)},key,unb64(envelope.data));return JSON.parse(dec.decode(plain));}
  async function openWithDeviceKey(envelope,record){if(!record?.key||!record?.salt)return null;const state=validateState(await decryptEnvelope(envelope,record.key));return {state,key:record.key,salt:unb64(record.salt)};}
  function levelInfo(totalXP){let xp=Math.max(0,totalXP),level=1,needed=250;while(xp>=needed&&level<100){xp-=needed;level++;needed=Math.round(250+((level-1)**1.22)*11);}return {level,into:xp,needed,progress:Math.min(1,xp/needed)};}
  function applyStatus(state,habitId,status,date){const habit=state.habits.find(h=>h.id===habitId);if(!habit||!['completed','rest','skipped','planned'].includes(status))return {xpAwarded:0,creditsAwarded:0};state.daily[date]??={statuses:{},notes:''};const key=`${date}:${habitId}`;state.daily[date].statuses[habitId]=status;let xpAwarded=0,creditsAwarded=0;if((status==='completed'||status==='rest')&&!state.awards[key]){state.awards[key]={status,at:new Date().toISOString()};if(status==='completed'){xpAwarded=habit.xp;creditsAwarded=Math.max(1,Math.floor(habit.xp/5));}else{xpAwarded=Math.max(3,Math.floor(habit.xp/2));creditsAwarded=1;}}state.totalXP+=xpAwarded;state.credits+=creditsAwarded;return {xpAwarded,creditsAwarded};}
  function sleepHours(start,end){let hours=(new Date(end)-new Date(start))/3600000;if(hours<0)hours+=24;return hours;}
  function validateState(s){if(!s||s.version!==1||!Array.isArray(s.habits)||!s.daily||typeof s.daily!=='object'||!s.awards||typeof s.awards!=='object'||!Array.isArray(s.sleep)||!Array.isArray(s.mood)||!Array.isArray(s.rewards)||!Number.isFinite(s.totalXP)||s.totalXP<0||!Number.isFinite(s.credits)||s.credits<0)throw Error('Encrypted app data is invalid or incomplete.');return s;}
  const api={deriveKey,encryptEnvelope,decryptEnvelope,openWithDeviceKey,levelInfo,applyStatus,sleepHours,validateState};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  if(typeof window!=='undefined')window.RebuildCore=api;
})();

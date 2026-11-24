'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { webcrypto } = require('node:crypto');
if (!globalThis.crypto) Object.defineProperty(globalThis,'crypto',{value:webcrypto});
const Core = require('../web/core.js');

function sampleState(){return {version:1,habits:[{id:'h1',title:'Walk',category:'Physical Health',xp:10}],daily:{},awards:{},totalXP:0,credits:0,recoveryMode:false,sleep:[],mood:[],rewards:[]};}

test('habit completion awards XP once even after status changes',()=>{
  const state=sampleState();
  assert.deepEqual(Core.applyStatus(state,'h1','completed','2026-11-24'),{xpAwarded:10,creditsAwarded:2});
  Core.applyStatus(state,'h1','planned','2026-11-24');
  assert.deepEqual(Core.applyStatus(state,'h1','completed','2026-11-24'),{xpAwarded:0,creditsAwarded:0});
  assert.equal(state.totalXP,10);assert.equal(state.credits,2);
});

test('intentional rest receives one partial award and never stacks with completion',()=>{
  const state=sampleState();
  assert.deepEqual(Core.applyStatus(state,'h1','rest','2026-11-24'),{xpAwarded:5,creditsAwarded:1});
  assert.deepEqual(Core.applyStatus(state,'h1','completed','2026-11-24'),{xpAwarded:0,creditsAwarded:0});
  assert.equal(state.totalXP,5);assert.equal(state.credits,1);
});

test('overnight sleep duration crosses midnight correctly',()=>{
  assert.equal(Core.sleepHours('2026-11-23T22:30:00+05:30','2026-11-24T06:00:00+05:30'),7.5);
});

test('level progress is cumulative and never negative',()=>{
  assert.deepEqual(Core.levelInfo(-3),{level:1,into:0,needed:250,progress:0});
  const info=Core.levelInfo(250);
  assert.equal(info.level,2);assert.equal(info.into,0);assert.ok(info.progress>=0&&info.progress<1);
});

test('password-derived AES-GCM encrypts data and rejects wrong keys',async()=>{
  const salt=webcrypto.getRandomValues(new Uint8Array(16));
  const key=await Core.deriveKey('correct horse battery staple',salt);
  const envelope=await Core.encryptEnvelope({privateNote:'only local'},key,salt);
  assert.equal(await Core.decryptEnvelope(envelope,key).then(v=>v.privateNote),'only local');
  const devicePersistedKey=structuredClone(key);
  assert.equal(await Core.decryptEnvelope(envelope,devicePersistedKey).then(v=>v.privateNote),'only local');
  const appState=sampleState();
  appState.totalXP=35;
  const appEnvelope=await Core.encryptEnvelope(appState,key,salt);
  const deviceOpen=await Core.openWithDeviceKey(appEnvelope,{key:devicePersistedKey,salt:appEnvelope.salt});
  assert.equal(deviceOpen.state.totalXP,35);
  assert.equal(await Core.openWithDeviceKey(appEnvelope,{}),null);
  const wrongKey=await Core.deriveKey('incorrect password',salt);
  await assert.rejects(Core.decryptEnvelope(envelope,wrongKey));
});

test('state validator rejects incomplete or invalid records',()=>{
  assert.throws(()=>Core.validateState({version:1}),/invalid or incomplete/);
  const state=sampleState();
  assert.equal(Core.validateState(state),state);
});

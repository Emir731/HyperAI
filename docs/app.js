import { Wllama } from "https://cdn.jsdelivr.net/npm/@wllama/wllama@3.13.0/esm/index.js";
import WasmFromCDN from "https://cdn.jsdelivr.net/npm/@wllama/wllama@3.13.0/esm/wasm-from-cdn.js";
const $=id=>document.getElementById(id);
const s={runtime:null,modelFiles:[],projector:null,image:null,busy:false,abort:null,threads:[],active:null};
const system="You are Hyper AI, a helpful offline study assistant. Help with mathematics, physics, chemistry, geometry, programming and languages. Explain clearly and accurately. Reply in the language the user uses.";
const maxFile=2*1024*1024*1024;
function status(t){$("status").textContent=t}
function progress(v,on=true){$("progress").style.display=on?"block":"none";$("progressFill").style.width=Math.max(0,Math.min(100,v))+"%"}
function busy(v){s.busy=v;$("send").textContent=v?"■":"↑";$("send").disabled=!v&&!s.runtime;$("prompt").disabled=!s.runtime||v;$("attachImage").disabled=!s.runtime||v}
function active(){return s.threads.find(t=>t.id===s.active)}
function save(){try{localStorage.setItem("hyperai.web.threads",JSON.stringify(s.threads))}catch{}}
function history(){const h=$("history");h.replaceChildren();s.threads.forEach(t=>{const b=document.createElement("button");b.className="thread"+(t.id===s.active?" active":"");const label=document.createElement("span");label.textContent=t.title;const del=document.createElement("span");del.textContent="×";del.title="Delete";del.onclick=e=>{e.stopPropagation();s.threads=s.threads.filter(x=>x.id!==t.id);if(s.active===t.id)s.active=null;save();history();render()};b.append(label,del);b.onclick=()=>{s.active=t.id;history();render();$("sidebar").classList.remove("open")};h.append(b)})}
function render(){const host=$("messages");host.replaceChildren();const t=active();$("welcome").style.display=t&&t.messages.length?"none":"block";if(!t)return;t.messages.forEach(m=>{const row=document.createElement("article");row.className="msg "+m.role;const av=document.createElement("div");av.className="avatar";av.textContent=m.role==="user"?"Y":"H";const body=document.createElement("div");body.className="msgbody";body.textContent=m.content||"";row.append(av,body);host.append(row)});$("chatArea").scrollTop=$("chatArea").scrollHeight}
function newChat(){s.active=null;history();render();$("prompt").focus()}
function settings(){$("settingsModal").classList.add("open")}
function closeSettings(){$("settingsModal").classList.remove("open")}
function choose(input,key){input.click();input.onchange=()=>{const picked=Array.from(input.files||[]);if(!picked.length)return;if(key==="model"){if(picked.some(f=>f.size>maxFile)){$("loadError").textContent="Each GGUF shard must be under 2 GB. Split large models into smaller GGUF shards first.";return}s.modelFiles=picked.sort((a,b)=>a.name.localeCompare(b.name));$("modelFileName").textContent=s.modelFiles.length===1?s.modelFiles[0].name:s.modelFiles.length+" GGUF shards selected";}else{const f=picked[0];if(f.size>maxFile){$("loadError").textContent="The projector file must be under 2 GB.";return}s.projector=f;$("projectorFileName").textContent=f.name;}$("loadError").textContent=""}}
function explainError(e){const m=String(e&&e.message||e);if(/memory|out of memory|allocation/i.test(m))return"Browser memory was exhausted. Try a smaller GGUF quantization or reduce context length.";if(/unsupported|architecture|model type/i.test(m))return"This GGUF architecture may not be supported by the browser llama.cpp runtime.";return m}
async function load(){
 if(!s.modelFiles.length){$("loadError").textContent="Choose a main GGUF model first.";return}
 $("loadModel").disabled=true;$("loadError").textContent="";status("Loading model…");progress(0);
 try{
  if(s.runtime){await s.runtime.exit();s.runtime=null}
  const w=new Wllama(WasmFromCDN,{suppressNativeLog:true});
  const files=[...s.modelFiles];if(s.projector)files.push(s.projector);
  await w.loadModel(files,{n_ctx:Number($("context").value),n_gpu_layers:Number($("gpuLayers").value),n_threads:Math.max(1,Math.floor((navigator.hardwareConcurrency||2)/2))});
  s.runtime=w;$("modelLamp").classList.add("on");$("modelLabel").textContent=s.modelFiles[0].name+(s.modelFiles.length>1?" (+"+(s.modelFiles.length-1)+" shards)":"");$("tokenHint").textContent=w.isSupportWebGPU()?"WebGPU available":"WASM inference";$("welcome").style.display="none";status("Model loaded");busy(false);closeSettings()
 }catch(e){status("Model load failed");$("loadError").textContent=explainError(e);if(s.runtime){try{await s.runtime.exit()}catch{}s.runtime=null}}
 finally{$("loadModel").disabled=false;progress(0,false)}
}
async function send(){
 if(s.busy){s.abort&&s.abort.abort();return}
 const prompt=$("prompt").value.trim(),image=s.image;if((!prompt&&!image)||!s.runtime)return;
 let t=active();if(!t){t={id:crypto.randomUUID(),title:(prompt||"Image question").slice(0,42),messages:[]};s.threads.unshift(t);s.active=t.id}
 const user={role:"user",content:prompt||"Please describe this image."};t.messages.push(user);const answer={role:"assistant",content:""};t.messages.push(answer);
 $("prompt").value="";s.image=null;$("imageFile").value="";$("attachmentName").textContent="";history();render();busy(true);status("Generating…");
 const messages=[{role:"system",content:system},...t.messages.slice(0,-1).map(m=>({role:m.role,content:m.content}))];
 if(image){const data=await image.arrayBuffer();messages[messages.length-1]={role:"user",content:[{type:"image",data},{type:"text",text:user.content}]}}
 const abort=new AbortController();s.abort=abort;
 try{
  const stream=await s.runtime.createChatCompletion({messages,max_tokens:Number($("maxTokens").value),temperature:Number($("temperature").value),top_p:.9,stream:true,abortSignal:abort.signal});
  for await(const chunk of stream){if(abort.signal.aborted)break;const delta=chunk.choices&&chunk.choices[0]&&chunk.choices[0].delta&&chunk.choices[0].delta.content||"";if(delta){answer.content+=delta;const body=$("messages").lastElementChild&&$("messages").lastElementChild.querySelector(".msgbody");if(body)body.textContent=answer.content;$("chatArea").scrollTop=$("chatArea").scrollHeight}}
  if(!answer.content&&abort.signal.aborted)answer.content="Generation stopped."
 }catch(e){answer.content=e.name==="AbortError"?"Generation stopped.":"Generation error: "+explainError(e)}
 finally{s.abort=null;busy(false);status("Model loaded");save();history();render()}
}
$("newChat").onclick=newChat;$("openSettings").onclick=settings;$("welcomeSetup").onclick=settings;$("closeSettings").onclick=closeSettings;
$("chooseModel").onclick=()=>choose($("modelFile"),"model");$("chooseProjector").onclick=()=>choose($("projectorFile"),"projector");$("loadModel").onclick=load;
$("temperature").oninput=()=>{$("tempValue").textContent=Number($("temperature").value).toFixed(1)};
$("attachImage").onclick=()=>$("imageFile").click();$("imageFile").onchange=()=>{s.image=$("imageFile").files&&$("imageFile").files[0]||null;$("attachmentName").textContent=s.image?"Image: "+s.image.name:""};
$("send").onclick=send;$("prompt").addEventListener("input",()=>{const e=$("prompt");e.style.height="auto";e.style.height=Math.min(e.scrollHeight,180)+"px"});
$("prompt").addEventListener("keydown",e=>{if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();send()}});
$("mobileMenu").onclick=()=>$("sidebar").classList.toggle("open");$("settingsModal").addEventListener("click",e=>{if(e.target===$("settingsModal"))closeSettings()});
try{s.threads=JSON.parse(localStorage.getItem("hyperai.web.threads")||"[]")}catch{s.threads=[]}history();render();busy(false);

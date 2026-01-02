const root=document.getElementById('root');
const list=document.getElementById('list');
const sub=document.getElementById('sub');
const sell=document.getElementById('sell');
const close=document.getElementById('close');
const x=document.getElementById('x');

function post(name,data={}){
  fetch(`https://${GetParentResourceName()}/${name}`,{
    method:'POST',
    headers:{'Content-Type':'application/json; charset=UTF-8'},
    body:JSON.stringify(data||{})
  }).catch(()=>{});
}

function render(kind,items,canSell){
  sub.textContent = kind === 'minerals' ? 'Minerals Bag' : (kind === 'produce' ? 'Produce Bag' : 'Bag');
  list.innerHTML='';
  const keys = Object.keys(items||{}).filter(k=>Number(items[k]||0)>0);
  if(keys.length===0){
    list.innerHTML='<div class="sub">Your bag is empty.</div>';
  } else {
    keys.forEach(k=>{
      const qty = Number(items[k]||0);
      const row=document.createElement('div');
      row.className='row';
      row.innerHTML=`<div class="name">${k.replace(/_/g,' ')}</div><div class="qty">x${qty}</div>`;
      list.appendChild(row);
    });
  }
  sell.style.display = canSell ? 'block' : 'none';
}

window.addEventListener('message',(e)=>{
  const d=e.data||{};
  if(d.type==='bag:open'){
    render(d.kind,d.items,d.canSell);
    root.classList.remove('hidden');
  }
  if(d.type==='bag:update'){
    render(d.kind,d.items,true);
  }
});

function doClose(){ root.classList.add('hidden'); post('close'); }
close.onclick=doClose;
x.onclick=doClose;
sell.onclick=()=>{ root.classList.add('hidden'); post('sell'); };

document.addEventListener('keydown',(ev)=>{
  if(ev.key==='Escape'){ doClose(); }
});

window.addEventListener('load',()=>{ post('ready'); });

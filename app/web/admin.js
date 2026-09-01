/* ===== SECTION =====
   STATE
===== SECTION ===== */
let acc = '#FFB84D', layout = 'Centered', cat = 'A';
let _mqttConnected = false;
let _mqttStatus = 'Connected';
let curBg = 'qrc:/app/res/image/ff_burger_pattern.jpg';
let muted = false, volStep = 3, ttsOn = true, bannerOn = true;
let gradOn = false, currentHue = 30, currentSat = 100, currentVal = 100;
let isDragging = false, pickerCanvas, pickerCtx;
let isBgUploaded = false; // Track if current background is custom uploaded
let _confirmT;
let logoVisible = false;
let categoryVisible = false;
let facilityVisible = true;
let liveCurrentNumber = "00";
let nowServingVisible = true;
let bgScale = 1.0, bgOffsetX = 0, bgOffsetY = 0;
let _curLs = 48;
let bgFitMode = 'crop'; // Track current fit mode
let _cadreType = 'glass';

const CADRE_TYPE_DEFAULTS = {
  glass:  { opacity: 34, blur: 31, radius: 42, border: 2, padding: 37 },
  dark:   { opacity: 34, blur: 31, radius: 42, border: 2, padding: 37 },
  custom: { opacity: 34, blur: 31, radius: 42, border: 2, padding: 37, color: '#FFB84D' }
};

// Background adjustment transform state
let bgTransform = { scale: 1, x: 0, y: 0, rotation: 0 };
let bgAdjustState = { isDragging: false, startX: 0, startY: 0, initialX: 0, initialY: 0 };
let bgPinchState = { isPinching: false, initialDist: 0, initialScale: 1 };
let bgRotateState = { isRotating: false, initialAngle: 0, initialRotation: 0 };

/* ===== SECTION =====
   CATALOG
===== SECTION ===== */
const BG = {
  food: [
    { id:'1F', label:'Food 1', ori:'portrait', fit:'crop', ext:'png' },
    { id:'2F', label:'Food 2', ori:'portrait', fit:'crop', ext:'png' },
    { id:'3F', label:'Food 3', ori:'portrait', fit:'crop', ext:'png' },
    { id:'4F', label:'Food 4', ori:'portrait', fit:'crop', ext:'png' },
    { id:'5F', label:'Food 5', ori:'portrait', fit:'crop', ext:'png' },
    { id:'6F', label:'Food 6', ori:'portrait', fit:'crop', ext:'png' },
  ],
  pro: [
    { id:'1P', label:'Pro 1', ori:'landscape', fit:'crop', ext:'png' },
    { id:'2P', label:'Pro 2', ori:'landscape', fit:'crop', ext:'png' },
    { id:'3P', label:'Pro 3', ori:'landscape', fit:'crop', ext:'png' },
    { id:'4P', label:'Pro 4', ori:'landscape', fit:'crop', ext:'png' },
    { id:'5P', label:'Pro 5', ori:'landscape', fit:'crop', ext:'png' },
  ],
  coffee: [
    { id:'1C', label:'Coffee 1', ori:'portrait', fit:'crop', ext:'png' },
    { id:'2C', label:'Coffee 2', ori:'portrait', fit:'crop', ext:'png' },
    { id:'3C', label:'Coffee 3', ori:'portrait', fit:'crop', ext:'png' },
    { id:'4C', label:'Coffee 4', ori:'portrait', fit:'crop', ext:'png' },
    { id:'5C', label:'Coffee 5', ori:'portrait', fit:'crop', ext:'png' },
  ],
};
const TPLS = [
  // Food - Static
  { id:'food_1f',      cat:'food', type:'static', label:'Food 1',         acc:'#FF6B35', bg:'1F',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'food_2f',      cat:'food', type:'static', label:'Food 2',         acc:'#E8372A', bg:'2F',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'food_3f',      cat:'food', type:'static', label:'Food 3',         acc:'#D84315', bg:'3F',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'food_4f',      cat:'food', type:'static', label:'Food 4',         acc:'#C0392B', bg:'4F',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'food_5f',      cat:'food', type:'static', label:'Food 5',         acc:'#27AE60', bg:'5F',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'food_6f',      cat:'food', type:'static', label:'Food 6',         acc:'#F39C12', bg:'6F',               ori:'portrait',  fit:'crop', ext:'png' },
  // Food - Animated
  { id:'food_1_animated_tpl', cat:'food', type:'animated', label:'Food 1 Animated', acc:'#FF6B35', bg:'', ori:'portrait', fit:'crop', video:'food_1_animated' },
  { id:'baguette_farcie_tpl', cat:'food', type:'animated', label:'Baguette Farcie', acc:'#E8372A', bg:'', ori:'portrait', fit:'crop', video:'baguette_farcie' },
  { id:'chapati_tpl', cat:'food', type:'animated', label:'Chapati', acc:'#D84315', bg:'', ori:'portrait', fit:'crop', video:'chapati' },
  { id:'fricassee_tpl', cat:'food', type:'animated', label:'Fricassee', acc:'#C0392B', bg:'', ori:'portrait', fit:'crop', video:'fricassee' },
  { id:'humberger_tpl', cat:'food', type:'animated', label:'Humberger', acc:'#27AE60', bg:'', ori:'portrait', fit:'crop', video:'humberger' },
  { id:'makloub_tpl', cat:'food', type:'animated', label:'Makloub', acc:'#F39C12', bg:'', ori:'portrait', fit:'crop', video:'makloub' },
  { id:'malfouf_tpl', cat:'food', type:'animated', label:'Malfouf', acc:'#8E44AD', bg:'', ori:'portrait', fit:'crop', video:'malfouf' },
  { id:'pizza_tpl', cat:'food', type:'animated', label:'Pizza', acc:'#16A085', bg:'', ori:'portrait', fit:'crop', video:'pizza' },
  { id:'tacos_tpl', cat:'food', type:'animated', label:'Tacos', acc:'#2ECC71', bg:'', ori:'portrait', fit:'crop', video:'tacos' },
  { id:'wood_tpl', cat:'food', type:'animated', label:'Wood', acc:'#E67E22', bg:'', ori:'portrait', fit:'crop', video:'wood' },
  // Pro - Static
  { id:'pro_1p',       cat:'pro',  type:'static', label:'Pro 1',          acc:'#1976D2', bg:'1P',               ori:'landscape', fit:'crop', ext:'png' },
  { id:'pro_2p',       cat:'pro',  type:'static', label:'Pro 2',          acc:'#1565C0', bg:'2P',               ori:'landscape', fit:'crop', ext:'png' },
  { id:'pro_3p',       cat:'pro',  type:'static', label:'Pro 3',          acc:'#0D47A1', bg:'3P',               ori:'landscape', fit:'crop', ext:'png' },
  { id:'pro_4p',       cat:'pro',  type:'static', label:'Pro 4',          acc:'#37474F', bg:'4P',               ori:'landscape', fit:'crop', ext:'png' },
  { id:'pro_5p',       cat:'pro',  type:'static', label:'Pro 5',          acc:'#455A64', bg:'5P',               ori:'landscape', fit:'crop', ext:'png' },
  // Coffee - Static
  { id:'coffee_1c',    cat:'coffee', type:'static', label:'Coffee 1',       acc:'#795548', bg:'1C',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'coffee_2c',    cat:'coffee', type:'static', label:'Coffee 2',       acc:'#5D4037', bg:'2C',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'coffee_3c',    cat:'coffee', type:'static', label:'Coffee 3',       acc:'#4E342E', bg:'3C',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'coffee_4c',    cat:'coffee', type:'static', label:'Coffee 4',       acc:'#3E2723', bg:'4C',               ori:'portrait',  fit:'crop', ext:'png' },
  { id:'coffee_5c',    cat:'coffee', type:'static', label:'Coffee 5',       acc:'#2D1B18', bg:'5C',               ori:'portrait',  fit:'crop', ext:'png' },
  // Coffee - Animated
  { id:'coffee_1_animated_tpl', cat:'coffee', type:'animated', label:'Coffee 1 Animated', acc:'#795548', bg:'', ori:'portrait', fit:'crop', video:'coffee_1_animated' },
  { id:'coffee_2_animated_tpl', cat:'coffee', type:'animated', label:'Coffee 2 Animated', acc:'#5D4037', bg:'', ori:'portrait', fit:'crop', video:'coffee_2_animated' },
  { id:'coffee_3_animated_tpl', cat:'coffee', type:'animated', label:'Coffee 3 Animated', acc:'#4E342E', bg:'', ori:'portrait', fit:'crop', video:'coffee_3_animated' },
  { id:'coffee_4_animated_tpl', cat:'coffee', type:'animated', label:'Coffee 4 Animated', acc:'#3E2723', bg:'', ori:'portrait', fit:'crop', video:'coffee_4_animated' },
  // Pro - Animated
  { id:'pro_1_animated_tpl', cat:'pro', type:'animated', label:'Pro 1 Animated', acc:'#1976D2', bg:'', ori:'landscape', fit:'crop', video:'pro_1_animated' },
  { id:'pro_2_animated_tpl', cat:'pro', type:'animated', label:'Pro 2 Animated', acc:'#1565C0', bg:'', ori:'landscape', fit:'crop', video:'pro_2_animated' },
  { id:'pro_3_animated_tpl', cat:'pro', type:'animated', label:'Pro 3 Animated', acc:'#0D47A1', bg:'', ori:'landscape', fit:'crop', video:'pro_3_animated' },
  { id:'pro_4_animated_tpl', cat:'pro', type:'animated', label:'Pro 4 Animated', acc:'#37474F', bg:'', ori:'landscape', fit:'crop', video:'pro_4_animated' },
];
function qrc(id, ext){ return `qrc:/app/res/image/${id}.${ext || 'jpg'}`; }
function thumb(id){ return `/api/bg_thumb/${id}`; }
function videoUrl(id){ return `/videos/${id}.mp4`; }


/* --- Font style catalog — used by the big-preview font picker --- */
const FONT_CATALOG = [
  { family:'DM Mono',                       label:'DM Mono', languages:['en','fr','ar'] },
  { family:'Barriecito',                    label:'Barriecito', languages:['en','fr','ar'] },
  { family:'Gluten',                        label:'Gluten', languages:['en','fr'] },
  { family:'LC Mogi',                       label:'LC Mogi', languages:['en','fr'] },
  { family:'Manosque',                      label:'Manosque', languages:['en','fr'] },
  { family:'monospace',                     label:'Monospace', languages:['en','fr'] },
  { family:'sans-serif',                    label:'Sans-serif', languages:['en','fr'] },
  { family:'serif',                         label:'Serif', languages:['en','fr'] },
];
let CUSTOM_FONTS = []; // populated from /api/fonts — {family, url}

const FONT_TARGET_LABEL = {
  numberFont:'Number', categoryFont:'Category', facilityFont:'Facility',
  bannerFont:'Banner', nowServingFont:'Serving'
};
const FONT_TARGET_SAMPLE = {
  numberFont:'042', categoryFont:'CATEGORY', facilityFont:'Facility',
  bannerFont:'Banner text', nowServingFont:'NOW SERVING'
};
let _fontTarget = 'numberFont';
let _fontValues = {
  numberFont:'DM Mono', categoryFont:'DM Mono', facilityFont:'DM Mono',
  bannerFont:'DM Mono', nowServingFont:'DM Mono'
};

/* ===== SECTION =====
   SLIDER LOGIC — live label update and instant push
===== SECTION ===== */
function onLsSlider(v) {
  _curLs = parseInt(v);
  document.getElementById('ls_val').textContent = v + 'px';
  debouncedPubLogoSize(_curLs);
  showConfirm();
}
function onTextSizeSlider(key, value, labelId, previewId, previewProp) {
  const v = Math.max(8, Math.min(240, parseInt(value) || 8));
  const label = document.getElementById(labelId);
  if (label) label.textContent = v + 'px';
  const el = document.getElementById(previewId);
  if (el) {
    if (previewProp === 'fontSize') el.style.fontSize = v + 'px';
    if (previewProp === 'fontFamily') el.style.fontFamily = v;
  }
  debouncedPubTextSize(key, v);
  updateSizeSummary(key, v);
  showConfirm();
}
function updateSizeSummary(key, v) {
  // Keep the accordion header showing the number size at a glance —
  // it's the element admins adjust most often.
  if (key !== 'numberFontSize') return;
  const s = document.getElementById('size_summary');
  if (s) s.textContent = 'Number ' + v + 'px';
}

/* ===== SECTION =====
   UNIFIED FONT SECTION
===== SECTION ===== */
// Element configuration mapping
const FONT_ELEMENT_CONFIG = {
  number: {
    fontKey: 'numberFont',
    sizeKey: 'numberFontSize',
    colorKey: 'numberColor',
    previewId: 'prev_num',
    defaultSize: 120,
    minSize: 120,
    maxSize: 700,
    defaultColor: '#FFB84D'
  },
  category: {
    fontKey: 'categoryFont',
    sizeKey: 'categoryFontSize',
    colorKey: 'categoryColor',
    previewId: 'prev_cat',
    defaultSize: 60,
    minSize: 20,
    maxSize: 130,
    defaultColor: '#FFB84D'
  },
  facility: {
    fontKey: 'facilityFont',
    sizeKey: 'facilityFontSize',
    colorKey: 'facilityColor',
    previewId: 'prev_fac',
    defaultSize: 60,
    minSize: 10,
    maxSize: 200,
    defaultColor: '#FFB84D'
  },
  banner: {
    fontKey: 'bannerFont',
    sizeKey: 'bannerFontSize',
    colorKey: 'bannerColor',
    previewId: 'prev_fac',
    defaultSize: 60,
    minSize: 32,
    maxSize: 100,
    defaultColor: '#FFFFFF'
  },
  serving: {
    fontKey: 'nowServingFont',
    sizeKey: 'nowServingFontSize',
    colorKey: 'nowServingColor',
    previewId: 'prev_label',
    defaultSize: 60,
    minSize: 20,
    maxSize: 130,
    defaultColor: '#FFFFFF'
  }
};

let _currentFontElement = 'number';

function buildFontTypeGrid() {
  const grid = document.getElementById('font_type_grid');
  if (!grid) return;
  const current = _fontValues[FONT_ELEMENT_CONFIG[_currentFontElement].fontKey] || 'DM Mono';

  const builtIn = FONT_CATALOG.filter(f =>
    !f.languages || f.languages.includes((_adminLang || 'en').toLowerCase()));
  const custom = CUSTOM_FONTS.filter(f =>
    !f.family || !FONT_CATALOG.some(b => b.family === f.family));

  grid.innerHTML = '';

  builtIn.forEach(f => grid.appendChild(makeFontCard(f.family, f.label, current, false)));
  custom.forEach(f => grid.appendChild(makeFontCard(f.family, f.family, current, true, f.filename)));
}

function makeFontCard(family, label, current, isCustom, filename) {
  const card = document.createElement('button');
  card.type = 'button';
  card.className = 'font-type-card' + (family === current ? ' on' : '') + (isCustom ? ' custom-font' : '');
  card.dataset.family = family;
  card.onclick = () => selectFontFamilyCard(family);

  const preview = document.createElement('div');
  preview.className = 'font-type-preview';
  preview.style.fontFamily = `'${family}'`;
  preview.textContent = 'Aa';

  const name = document.createElement('span');
  name.textContent = label + (isCustom ? ' (custom)' : '');

  card.appendChild(preview);
  card.appendChild(name);

  if (isCustom) {
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'font-type-delete';
    del.textContent = '×';
    del.title = 'Delete font';
    del.onclick = (e) => { e.stopPropagation(); deleteFont(filename); };
    card.appendChild(del);
  }

  return card;
}

function selectFontFamilyCard(family) {
  document.querySelectorAll('#font_type_grid .font-type-card').forEach(c =>
    c.classList.toggle('on', c.dataset.family === family));
  onFontFamilyChange(family);
}

function setFontElement(element) {
  _currentFontElement = element;
  const config = FONT_ELEMENT_CONFIG[element];

  // Update slider min/max/value
  const slider = document.getElementById('font_size_slider');
  if (slider) {
    slider.min = config.minSize;
    slider.max = config.maxSize;
    slider.value = _fontValues[config.sizeKey] || config.defaultSize;
  }

  // Update displayed value
  const sizeValDisplay = document.getElementById('font_size_val');
  if (sizeValDisplay) {
    sizeValDisplay.textContent = (slider ? slider.value : config.defaultSize) + 'px';
  }
  document.querySelectorAll('#font_target_grid .gi').forEach(b =>
    b.classList.toggle('on', b.dataset.target === element));

  // Update controls with current values
  const sizeSlider = document.getElementById('font_size_slider');
  const sizeVal = document.getElementById('font_size_val');
  const colorPicker = document.getElementById('font_color_picker');
  const colorVal = document.getElementById('font_color_val');

  buildFontTypeGrid();
  if (sizeSlider) sizeSlider.value = _fontValues[config.sizeKey] || config.defaultSize;
  if (sizeVal) sizeVal.textContent = (_fontValues[config.sizeKey] || config.defaultSize) + 'px';
  if (colorPicker) colorPicker.value = _fontValues[config.colorKey] || config.defaultColor;
  if (colorVal) colorVal.textContent = _fontValues[config.colorKey] || config.defaultColor;

  // Update summary
  const summary = document.getElementById('font_summary');
  if (summary) {
    const label = element.charAt(0).toUpperCase() + element.slice(1);
    const size = _fontValues[config.sizeKey] || config.defaultSize;
    const font = _fontValues[config.fontKey] || 'DM Mono';
    summary.textContent = `${label} · ${size}px · ${font}`;
  }
  buildSwatchRow();
}

function setFontFamily(family) {
  const config = FONT_ELEMENT_CONFIG[_currentFontElement];
  _fontValues[config.fontKey] = family;
  setFontFor(config.fontKey, family);
  setFontElement(_currentFontElement); // Update summary
}

function onFontSizeSlider(value) {
  const config = FONT_ELEMENT_CONFIG[_currentFontElement];
  const v = Math.max(config.minSize, Math.min(config.maxSize, parseInt(value) || config.defaultSize));

  _fontValues[config.sizeKey] = v;
  document.getElementById('font_size_val').textContent = v + 'px';

  // Update preview
  const el = document.getElementById(config.previewId);
  if (el) el.style.fontSize = v + 'px';

  debouncedPubTextSize(config.sizeKey, v);
  setFontElement(_currentFontElement); // Update summary
  showConfirm();
}

function onFontColorPicker(color) {
  const config = FONT_ELEMENT_CONFIG[_currentFontElement];
  _fontValues[config.colorKey] = color;
  document.getElementById('font_color_val').textContent = color;

  // Update preview
  const el = document.getElementById(config.previewId);
  if (el) el.style.color = color;

  pub(config.colorKey, color);
  setFontElement(_currentFontElement); // Update summary
  buildSwatchRow();
  showConfirm();
}

/* Quick-pick color swatches for the Font section */
const SWATCH_COLORS = [
  '#FFFFFF','#000000','#FFB84D','#FF6B35',
  '#EF4444','#F59E0B','#10B981','#3B82F6',
  '#8B5CF6','#EC4899','#14B8A6','#6B7280'
];

function buildSwatchRow() {
  const row = document.getElementById('font_swatch_row');
  if (!row) return;
  const config = FONT_ELEMENT_CONFIG[_currentFontElement];
  const current = (_fontValues[config.colorKey] || config.defaultColor || '').toUpperCase();
  row.innerHTML = '';
  SWATCH_COLORS.forEach(hex => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'swatch' + (hex === '#FFFFFF' ? ' white' : '') + (hex === current ? ' on' : '');
    b.style.background = hex;
    b.title = hex;
    b.onclick = () => selectPresetColor(hex);
    row.appendChild(b);
  });
}

function selectPresetColor(hex) {
  const picker = document.getElementById('font_color_picker');
  if (picker) picker.value = hex;
  onFontColorPicker(hex);
  buildSwatchRow();
}

function showConfirm() {
  const bar = document.getElementById('sticky-apply');
  const el = document.getElementById('apply-confirm');
  if (!el || !bar) return;
  bar.classList.remove('hide');
  el.classList.add('show');
  clearTimeout(_confirmT);
  _confirmT = setTimeout(() => {
    el.classList.remove('show');
    bar.classList.add('hide');
  }, 2000);
}

function toast(msg, type = 'success') {
  const bar = document.getElementById('sticky-apply');
  const el = document.getElementById('apply-confirm');
  if (!el || !bar) return;
  el.textContent = msg;
  el.style.color = type === 'error' ? 'var(--danger)' : 'var(--success)';
  bar.classList.remove('hide');
  el.classList.add('show');
  clearTimeout(_confirmT);
  _confirmT = setTimeout(() => {
    el.classList.remove('show');
    bar.classList.add('hide');
    el.style.color = '';
    el.textContent = 'Applied';
  }, 2500);
}

function showError(err) {
  console.error('[request failed]', err);
  toast('Action failed — please try again', 'error');
}

function updateLockState() {
  const app = document.getElementById('app');
  const banner = document.getElementById('disc_banner');
  // Controls lock only on browser<->server WebSocket loss. MQTT broker
  // state is NOT a gate here: server.py's _persist_and_publish() always
  // calls mqtt_client.direct_command() regardless of MQTT connectivity,
  // so admin actions still reach the Qt display via the local queue even
  // when the broker is unreachable. MQTT status is surfaced separately
  // via the connection dot in the header, not via this lock.
  const locked = !_wsReady;
  if (app) app.classList.toggle('controls-locked', locked);
  if (banner) banner.classList.toggle('show', locked);
}

/* ===== SECTION =====
   COLLAPSIBLE SECTIONS — keeps Settings/Theme scannable on a phone
===== SECTION ===== */
function toggleCard(headerEl) {
  const card = headerEl.closest('.card');
  if (card) card.classList.toggle('open');
}

/* ===== SECTION =====
   TAB SWITCHING
===== SECTION ===== */
function tab(name) {
  const wasHealth = _activeTab === 'health';
  _activeTab = name;
  ['home','remote','settings','theme','health'].forEach(n => {
    const pEl = document.getElementById('p_' + n);
    const tEl = document.getElementById('t_' + n);
    if (pEl) pEl.classList.toggle('hide', n !== name);
    if (tEl) tEl.classList.toggle('on', n === name);
  });
  if (wasHealth && name !== 'health') {
    setHealthPolling(false);
  }
  if (name === 'health') {
    setHealthPolling(true);
  }
  if (name === 'theme') setTimeout(initPicker, 80);
}

/* ===== SECTION =====
   REMOTE CONTROLS
===== SECTION ===== */
function updateAudioPlaybackUI() {
  const stepBtns = document.querySelectorAll('.step-btn-grid');
  const callNextBtn = document.getElementById('callNextBtn');
  const resetBtn = document.getElementById('resetBtn');
  const numInput = document.getElementById('num_input');

  if (window.audioPlaying) {
    stepBtns.forEach(btn => {
      btn.disabled = true;
      btn.classList.add('disabled');
    });
    if (callNextBtn) {
      callNextBtn.disabled = true;
      callNextBtn.classList.add('disabled');
    }
    if (resetBtn) {
      resetBtn.disabled = true;
      resetBtn.classList.add('disabled');
    }
    if (numInput) {
      numInput.disabled = true;
      numInput.style.opacity = '0.5';
      numInput.style.pointerEvents = 'none';
    }
  } else {
    stepBtns.forEach(btn => {
      btn.disabled = false;
      btn.classList.remove('disabled');
    });
    if (callNextBtn) {
      callNextBtn.disabled = false;
      callNextBtn.classList.remove('disabled');
    }
    if (resetBtn) {
      resetBtn.disabled = false;
      resetBtn.classList.remove('disabled');
    }
    if (numInput) {
      numInput.disabled = false;
      numInput.style.opacity = '';
      numInput.style.pointerEvents = '';
    }
  }
}

function adj(d) {
  // Check if audio is currently playing before allowing number change
  if (window.audioPlaying) {
    console.log('Number change blocked - audio still playing');
    return;
  }
  const el = document.getElementById('num_input');
  el.value = Math.max(0, Math.min(999, (parseInt(el.value)||0) + d));
  prevNum();
}
function validateAndSetNumber() {
  const el = document.getElementById('num_input');
  const errorEl = document.getElementById('num_error');
  const rawValue = el.value.trim();

  // Strict: only 1–3 plain digits allowed. Rejects empty, decimals, commas,
  // negatives, scientific notation (e.g. "1e5"), and any non-digit input.
  if (!/^\d{1,3}$/.test(rawValue)) {
    errorEl.style.display = 'block';
    el.style.borderColor = 'var(--danger)';
    el.value = parseInt(document.getElementById('prev_num').textContent) || 0;
    return;
  }

  const num = Math.max(0, Math.min(999, parseInt(rawValue, 10)));

  // Valid input
  errorEl.style.display = 'none';
  el.style.borderColor = '';
  el.value = num;
  prevNum();
}

function prevNum() {
  // Check if audio is currently playing
  if (window.audioPlaying) {
    console.log('Number call blocked - audio still playing');
    return;
  }
  // Set audioPlaying flag immediately to block further calls
  window.audioPlaying = true;
  updateAudioPlaybackUI();
  
  // Fail-safe: reset flag after 10 seconds (full announcement sequence: chime + category + number)
  // This prevents UI from getting stuck if audio fails or doesn't play
  if (window.audioPlayingTimeout) {
    clearTimeout(window.audioPlayingTimeout);
  }
  window.audioPlayingTimeout = setTimeout(() => {
    window.audioPlaying = false;
    updateAudioPlaybackUI();
    console.log('Audio playing flag reset by fail-safe timeout');
  }, 10000);
  
  const v = String(parseInt(document.getElementById('num_input').value)||0).padStart(2,'0');
  liveCurrentNumber = v;
  document.getElementById('prev_num').textContent = v;
  document.getElementById('queueNumberDisplay').textContent = v;
  const numSize = document.getElementById('num_fs_slider')?.value || 96;
  document.getElementById('prev_num').style.fontSize = numSize + 'px';
  // Skip the audio announcement when the number is 0 — same behavior as resetNumber()
  pub('currentNumber', v === '000' ? v + '|nosound' : v);
  showConfirm();
}
function callCurrentNumber() {
  if (window.audioPlaying) {
    console.log('Call blocked - audio still playing');
    return;
  }
  window.audioPlaying = true;
  updateAudioPlaybackUI();
  if (window.audioPlayingTimeout) {
    clearTimeout(window.audioPlayingTimeout);
  }
  window.audioPlayingTimeout = setTimeout(() => {
    window.audioPlaying = false;
    updateAudioPlaybackUI();
  }, 10000);
  pub('currentNumber', liveCurrentNumber === '000' ? liveCurrentNumber + '|nosound' : liveCurrentNumber);
  showConfirm();
}
let _resetLocked = false;
const RESET_COOLDOWN_MS = 1000;

let _restartLocked = false;
async function restartDisplay(cardEl) {
  if (_restartLocked) return;
  if (!confirm('Restart the display application?')) return;
  _restartLocked = true;
  if (cardEl) { cardEl.style.opacity = '0.5'; cardEl.style.pointerEvents = 'none'; }
  try {
    const r = await fetch('/api/restart', { method: 'POST' });
    if (!r.ok) throw new Error('restart failed');
    toast('Restart triggered');
  } catch (e) {
    toast('Restart failed — device may be offline', 'error');
  } finally {
    setTimeout(() => {
      _restartLocked = false;
      if (cardEl) { cardEl.style.opacity = ''; cardEl.style.pointerEvents = ''; }
    }, 5000);
  }
}

let _resetToDefaultLocked = false;
async function resetDisplayToDefault(cardEl) {
  if (_resetToDefaultLocked) return;
  if (!confirm('Reset display to default?')) return;
  _resetToDefaultLocked = true;
  if (cardEl) { cardEl.style.opacity = '0.5'; cardEl.style.pointerEvents = 'none'; }
  try {
    resetNumber();
    const r = await fetch('/api/reset_stats', { method: 'POST' });
    if (!r.ok) throw new Error('reset_stats failed');
    loadStats();
    toast('Reset complete');
  } catch (e) {
    toast('Reset failed — check connection', 'error');
  } finally {
    setTimeout(() => {
      _resetToDefaultLocked = false;
      if (cardEl) { cardEl.style.opacity = ''; cardEl.style.pointerEvents = ''; }
    }, 3000);
  }
}

function resetNumber() {
  if (_resetLocked) return;
  _resetLocked = true;
  const btn = document.getElementById('resetBtn');
  if (btn) { btn.disabled = true; btn.classList.add('disabled'); }

  const el = document.getElementById('num_input');
  el.value = 0;
  const v = '00';
  liveCurrentNumber = v;
  document.getElementById('prev_num').textContent = v;
  document.getElementById('queueNumberDisplay').textContent = v;
  const numSize = document.getElementById('num_fs_slider')?.value || 96;
  document.getElementById('prev_num').style.fontSize = numSize + 'px';
  // Publish with special flag to skip audio
  pub('currentNumber', v + '|nosound');
  showConfirm();

  setTimeout(() => {
    _resetLocked = false;
    if (btn && !window.audioPlaying) {
      btn.disabled = false;
      btn.classList.remove('disabled');
    }
  }, RESET_COOLDOWN_MS);
}

/* ===== SECTION =====
   VOLUME / MUTE
===== SECTION ===== */
function setVol(v) {
  // Backwards-compatible: accept discrete steps 0..4
  const pct = Math.round((parseInt(v) / 4) * 100);
  document.getElementById('vol_slider').value = pct;
  document.getElementById('vol_label').textContent = pct + '%';
  const step = Math.max(0, Math.min(4, parseInt(v)));
  pub('audioVolumeStep', String(step));
}
let _muteToggleLocked = false;
function toggleMute() {
  if (_muteToggleLocked) return;
  _muteToggleLocked = true;
  const btn = document.getElementById('mute_btn');
  if (btn) btn.style.pointerEvents = 'none';
  muted = !muted;
  btn.classList.toggle('on', muted);
  pub('audioMuted', muted ? 'true' : 'false');
  setTimeout(() => {
    _muteToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}

function onVolSlider(v) {
  const pct = Math.max(0, Math.min(100, parseInt(v)));
  document.getElementById('vol_label').textContent = pct + '%';
  const step = Math.round(pct / 25);
  
  // Auto-mute when volume is 0%
  if (pct === 0 && !muted) {
    toggleMute();
  } else if (pct > 0 && muted) {
    toggleMute();
  }
  
  debouncedPubVolStep(step);
}

/* ===== SECTION =====
   ADMIN PANEL LANGUAGE — translates this UI itself
===== SECTION ===== */
let _adminLang = 'en';

// Full translation dictionary for the admin panel UI strings.
// Keys match data-i18n attributes in the HTML.
const ADMIN_I18N = {
  en: {
    // header
    header_title: 'CandyBar',
    header_sub: 'Queue display control',
    // tabs
    tab_remote: 'Remote',
    tab_settings: 'Settings',
    tab_theme: 'Theme',
    // remote
    queue_number: 'QUEUE NUMBER',
    category_label: 'Category',
    audio_label: 'AUDIO',
    mute_label: 'Mute',
    volume_label: 'Volume',
    // settings
    cat_title: 'Category',
    cat_sub: 'Manage queue categories',
    cat_code_lbl: 'Short code',
    cat_name_lbl: 'Display name',
    cat_save: 'Save category',
    facility_title: 'Display view',
    facility_sub: 'Name, message & category',
    facility_name_lbl: 'Facility name',
    banner_msg_lbl: 'Banner message',
    save_btn: 'Save',
    tts_title: 'Text-to-speech',
    tts_sub: 'Enabled · English',
    speech_label: 'Speech announcements',
    tts_lang_lbl: 'Language',
    languages_title: 'Languages',
    languages_sub: 'Admin panel language',
    admin_lang_title: 'Admin panel language',
    admin_lang_sub: 'Language of this control panel',
    pin_title: 'Admin PIN',
    pin_sub: '4-digit code to unlock this panel',
    pin_placeholder: 'New 4-digit PIN',
    status_title: 'Device status',
    status_sub: 'Uptime, sessions & activity',
    uptime_lbl: 'Uptime',
    sessions_lbl: 'Sessions',
    changes_lbl: 'Number Changes',
    restart_lbl: 'Last Restart',
    // theme
    templates_title: 'Ready-made templates',
    templates_sub: 'One tap sets colors, background & font',
    layout_title: 'Layout',
    cadre_title: 'Cadre',
    cadre_sub: 'Frame style for display content',
    accent_title: 'Accent color',
    accent_sub: 'Highlights the number & category',
    gradient_label: 'Gradient on accent bar',
    bg_title: 'Background',
    bg_sub: 'Choose an image, then fit & position it',
    fit_mode_lbl: 'Fit mode',
    zoom_lbl: 'Zoom',
    move_x_lbl: 'Move X',
    move_y_lbl: 'Move Y',
    reset_pos: '↺ Reset position',
    bg_upload_hint: 'Upload custom background (JPG/PNG, max 5 MB)',
    remove_bg: 'Remove custom background',
    logo_title: 'Logo',
    logo_no_upload: 'Tap to upload logo (PNG/JPG/SVG, max 2 MB)',
    logo_pos_lbl: 'Position',
    logo_visibility: 'Visibility',
    typography_title: 'Typography & size',
    typography_sub: 'Font family and size for every element',
    global_size_lbl: 'Global number size',
    global_size_hint: 'Scales the queue number as a whole.',
    overrides_sep: 'Individual overrides',
    num_size_lbl: 'Number size',
    cat_size_lbl: 'Category size',
    fac_size_lbl: 'Facility size',
    banner_size_lbl: 'Banner size',
    serve_size_lbl: 'Now serving size',
    font_families_lbl: 'Font families',
    num_font_lbl: 'Number font',
    cat_font_lbl: 'Category font',
    fac_font_lbl: 'Facility font',
    banner_font_lbl: 'Banner font',
    serving_font_lbl: 'Now serving font',
    logo_size_lbl: 'Logo size',
    font_preset_lbl: 'Number font preset',
    font_upload_hint: 'Upload font (TTF/OTF, max 2 MB)',
    banner_footer_title: 'Footer banner',
    banner_footer_sub: 'Show the scrolling message on-screen',
    // apply
    apply_btn: 'Apply to Display',
    applied: 'Applied',
  },
  fr: {
    header_title: 'CandyBar',
    header_sub: 'Contrôle de l\'affichage',
    tab_remote: 'Télécommande',
    tab_settings: 'Paramètres',
    tab_theme: 'Thème',
    queue_number: 'NUMÉRO DE FILE',
    category_label: 'Catégorie',
    audio_label: 'AUDIO',
    mute_label: 'Muet',
    volume_label: 'Volume',
    cat_title: 'Catégorie',
    cat_sub: 'Gérer les catégories de file',
    cat_code_lbl: 'Code court',
    cat_name_lbl: 'Nom affiché',
    cat_save: 'Enregistrer la catégorie',
    facility_title: 'Affichage',
    facility_sub: 'Nom, message et catégorie',
    facility_name_lbl: 'Nom de l\'établissement',
    banner_msg_lbl: 'Message de la bannière',
    save_btn: 'Enregistrer',
    tts_title: 'Synthèse vocale',
    tts_sub: 'Activée · Français',
    speech_label: 'Annonces vocales',
    tts_lang_lbl: 'Langue',
    languages_title: 'Langues',
    languages_sub: 'Langue du panneau admin',
    admin_lang_title: 'Langue du panneau admin',
    admin_lang_sub: 'Langue de ce panneau de contrôle',
    pin_title: 'Code PIN admin',
    pin_sub: 'Code à 4 chiffres pour déverrouiller',
    pin_placeholder: 'Nouveau PIN à 4 chiffres',
    status_title: 'État de l\'appareil',
    status_sub: 'Disponibilité, sessions et activité',
    uptime_lbl: 'Disponibilité',
    sessions_lbl: 'Sessions',
    changes_lbl: 'Changements de numéro',
    restart_lbl: 'Dernier redémarrage',
    templates_title: 'Modèles prêts à l\'emploi',
    templates_sub: 'Un appui définit couleurs, fond et police',
    layout_title: 'Mise en page',
    cadre_title: 'Cadre',
    cadre_sub: 'Style de cadre pour le contenu de l\'affichage',
    accent_title: 'Couleur d\'accent',
    accent_sub: 'Met en valeur le numéro et la catégorie',
    gradient_label: 'Dégradé sur la barre d\'accent',
    bg_title: 'Arrière-plan',
    bg_sub: 'Choisissez une image, puis ajustez',
    fit_mode_lbl: 'Mode d\'ajustement',
    zoom_lbl: 'Zoom',
    move_x_lbl: 'Déplacer X',
    move_y_lbl: 'Déplacer Y',
    reset_pos: '↺ Réinitialiser la position',
    bg_upload_hint: 'Télécharger un fond personnalisé (JPG/PNG, max 5 Mo)',
    remove_bg: 'Supprimer le fond personnalisé',
    logo_title: 'Logo',
    logo_no_upload: 'Appuyer pour télécharger un logo (PNG/JPG/SVG, max 2 Mo)',
    logo_pos_lbl: 'Position',
    logo_visibility: 'Visibilité',
    typography_title: 'Typographie et taille',
    typography_sub: 'Famille et taille de police pour chaque élément',
    global_size_lbl: 'Taille globale du numéro',
    global_size_hint: 'Met à l\'échelle le numéro de file dans son ensemble.',
    overrides_sep: 'Remplacements individuels',
    num_size_lbl: 'Taille du numéro',
    cat_size_lbl: 'Taille de la catégorie',
    fac_size_lbl: 'Taille de l\'établissement',
    banner_size_lbl: 'Taille de la bannière',
    serve_size_lbl: 'Taille «En service»',
    font_families_lbl: 'Familles de polices',
    num_font_lbl: 'Police du numéro',
    cat_font_lbl: 'Police de la catégorie',
    fac_font_lbl: 'Police de l\'établissement',
    banner_font_lbl: 'Police de la bannière',
    serving_font_lbl: 'Police «En service»',
    logo_size_lbl: 'Taille du logo',
    font_preset_lbl: 'Préréglage de la police du numéro',
    font_upload_hint: 'Télécharger une police (TTF/OTF, max 2 Mo)',
    banner_footer_title: 'Bannière de pied de page',
    banner_footer_sub: 'Afficher le message défilant à l\'écran',
    apply_btn: 'Appliquer à l\'affichage',
    applied: 'Appliqué',
  },
  ar: {
    header_title: 'CandyBar',
    header_sub: 'التحكم في شاشة الانتظار',
    tab_remote: 'تحكم',
    tab_settings: 'إعدادات',
    tab_theme: 'مظهر',
    queue_number: 'رقم الانتظار',
    category_label: 'الفئة',
    audio_label: 'الصوت',
    mute_label: 'كتم',
    volume_label: 'مستوى الصوت',
    cat_title: 'الفئة',
    cat_sub: 'إدارة فئات الانتظار',
    cat_code_lbl: 'رمز قصير',
    cat_name_lbl: 'الاسم المعروض',
    cat_save: 'حفظ الفئة',
    facility_title: 'عرض الشاشة',
    facility_sub: 'الاسم والرسالة والفئة',
    facility_name_lbl: 'اسم المنشأة',
    banner_msg_lbl: 'رسالة الشريط',
    save_btn: 'حفظ',
    tts_title: 'تحويل النص إلى كلام',
    tts_sub: 'مفعّل · العربية',
    speech_label: 'الإعلانات الصوتية',
    tts_lang_lbl: 'اللغة',
    languages_title: 'اللغات',
    languages_sub: 'لغة لوحة الإدارة',
    admin_lang_title: 'لغة لوحة الإدارة',
    admin_lang_sub: 'لغة هذه اللوحة',
    pin_title: 'رمز PIN للمدير',
    pin_sub: 'رمز مكوّن من 4 أرقام للفتح',
    pin_placeholder: 'رمز PIN جديد مكوّن من 4 أرقام',
    status_title: 'حالة الجهاز',
    status_sub: 'وقت التشغيل والجلسات والنشاط',
    uptime_lbl: 'وقت التشغيل',
    sessions_lbl: 'الجلسات',
    changes_lbl: 'تغييرات الأرقام',
    restart_lbl: 'آخر إعادة تشغيل',
    templates_title: 'قوالب جاهزة',
    templates_sub: 'ضغطة واحدة تضبط الألوان والخلفية والخط',
    layout_title: 'التخطيط',
    cadre_title: 'الإطار',
    cadre_sub: 'نمط الإطار لمحتوى الشاشة',
    accent_title: 'لون التمييز',
    accent_sub: 'يبرز الرقم والفئة',
    gradient_label: 'تدرج على شريط التمييز',
    bg_title: 'خلفية الشاشة',
    bg_sub: 'اختر صورة ثم اضبط الاتساق والموضع',
    fit_mode_lbl: 'وضع الملاءمة',
    zoom_lbl: 'تكبير',
    move_x_lbl: 'تحريك X',
    move_y_lbl: 'تحريك Y',
    reset_pos: '↺ إعادة تعيين الموضع',
    bg_upload_hint: 'رفع خلفية مخصصة (JPG/PNG، الحد 5 ميجا)',
    remove_bg: 'إزالة الخلفية المخصصة',
    logo_title: 'الشعار',
    logo_no_upload: 'اضغط لرفع شعار (PNG/JPG/SVG، الحد 2 ميجا)',
    logo_pos_lbl: 'الموضع',
    logo_visibility: 'الظهور',
    typography_title: 'الطباعة والحجم',
    typography_sub: 'عائلة الخط وحجمه لكل عنصر',
    global_size_lbl: 'الحجم الإجمالي للرقم',
    global_size_hint: 'يضبط حجم رقم الانتظار بشكل عام.',
    overrides_sep: 'تجاوزات فردية',
    num_size_lbl: 'حجم الرقم',
    cat_size_lbl: 'حجم الفئة',
    fac_size_lbl: 'حجم اسم المنشأة',
    banner_size_lbl: 'حجم الشريط',
    serve_size_lbl: 'حجم «يُخدَم الآن»',
    font_families_lbl: 'عائلات الخطوط',
    num_font_lbl: 'خط الرقم',
    cat_font_lbl: 'خط الفئة',
    fac_font_lbl: 'خط المنشأة',
    banner_font_lbl: 'خط الشريط',
    serving_font_lbl: 'خط «يُخدَم الآن»',
    logo_size_lbl: 'حجم الشعار',
    font_preset_lbl: 'إعداد مسبق لخط الرقم',
    font_upload_hint: 'رفع خط (TTF/OTF، الحد 2 ميجا)',
    banner_footer_title: 'شريط التذييل',
    banner_footer_sub: 'عرض الرسالة المتحركة على الشاشة',
    apply_btn: 'تطبيق على الشاشة',
    applied: 'تم التطبيق',
  }
};

function t(key) {
  return (ADMIN_I18N[_adminLang] && ADMIN_I18N[_adminLang][key]) ||
         ADMIN_I18N['en'][key] || key;
}

function setAdminLang(lang) {
  _adminLang = lang;
  // Highlight the active button
  document.querySelectorAll('#admin_lang_grp .gi').forEach(b =>
    b.classList.toggle('on', b.dataset.lang === lang));
  // Apply RTL for Arabic
  document.documentElement.dir = (lang === 'ar') ? 'rtl' : 'ltr';
  document.documentElement.lang = lang;
  // Translate every element with a data-i18n attribute
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    const val = t(key);
    if (el.tagName === 'INPUT' && el.hasAttribute('placeholder')) {
      el.placeholder = val;
    } else {
      el.textContent = val;
    }
  });
  // Re-label dynamic buttons that were set programmatically
  const applyBtn = document.getElementById('apply_btn');
  if (applyBtn) applyBtn.textContent = t('apply_btn');
  const applyConf = document.getElementById('apply_confirm');
  if (applyConf) applyConf.textContent = t('applied');
  // Persist choice in localStorage (admin-only, doesn't affect the display)
  try { localStorage.setItem('cbAdminLang', lang); } catch(e) {}
}

/* ===== SECTION =====
   SETTINGS SAVES
===== SECTION ===== */
async function saveCategory() {
  const name = document.getElementById('cat_name').value.trim();
  if (name) {
    // Generate valid short code slug for MQTT topic
    const id = name.toLowerCase().replace(/[^a-z0-9]/g, '_').substring(0, 10) || 'a';
    document.getElementById('cat_id').value = id;

    await pub('category', id);
    await pub('categoryDisplayName', name);

    document.getElementById('rc_code').textContent = id;
    cat = id;
    document.getElementById('rc_name').textContent = name;
    document.getElementById('prev_cat').textContent = name;
  }
  const s = document.getElementById('cat_summary');
  if (s) s.textContent = name || 'Category A';
  showConfirm();
}
async function saveFacility() {
  const fac = document.getElementById('facility').value.trim();
  if (fac) { await pub('facilityName', fac); document.getElementById('prev_fac').textContent = fac; }
  showConfirm();
}
async function saveBanner() {
  const ban = document.getElementById('banner').value.trim();
  if (ban) await pub('bannerText', ban);
  showConfirm();
}
let _facilityVisToggleLocked = false;
function toggleFacilityVisibility() {
  if (_facilityVisToggleLocked) return;
  _facilityVisToggleLocked = true;
  const btn = document.getElementById('facility_visible_btn');
  if (btn) btn.style.pointerEvents = 'none';
  facilityVisible = !facilityVisible;
  if (btn) btn.classList.toggle('on', facilityVisible);
  pub('facilityVisible', facilityVisible ? 'true' : 'false');
  showConfirm();
  setTimeout(() => {
    _facilityVisToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
async function saveNowServingText() {
  const text = document.getElementById('now_serving_text').value.trim();
  if (text) { await pub('nowServingText', text); }
  showConfirm();
}
let _nowServingVisToggleLocked = false;
function toggleNowServingVisibility() {
  if (_nowServingVisToggleLocked) return;
  _nowServingVisToggleLocked = true;
  const btn = document.getElementById('now_serving_visible_btn');
  if (btn) btn.style.pointerEvents = 'none';
  nowServingVisible = !nowServingVisible;
  if (btn) btn.classList.toggle('on', nowServingVisible);
  pub('nowServingVisible', nowServingVisible ? 'true' : 'false');
  showConfirm();
  setTimeout(() => {
    _nowServingVisToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
let _ttsToggleLocked = false;
function toggleTts() {
  if (_ttsToggleLocked) return;
  _ttsToggleLocked = true;
  const btn = document.getElementById('tts_btn');
  if (btn) btn.style.pointerEvents = 'none';
  ttsOn = !ttsOn;
  btn.classList.toggle('on', ttsOn);
  pub('ttsEnabled', ttsOn ? 'true' : 'false');
  updateTtsSummary();
  setTimeout(() => {
    _ttsToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
function updateTtsSummary() {
  const s = document.getElementById('tts_summary');
  if (!s) return;
  const langNames = {en:'English', fr:'French', ar:'Arabic'};
  const lang = document.getElementById('tts_lang')?.value || 'en';
  s.textContent = (ttsOn ? 'Enabled' : 'Disabled') + ' · ' + (langNames[lang]||lang);
}
async function changePin() {
  const p = document.getElementById('new_pin').value.trim();
  if (!/^\d{4}$/.test(p)) {
    toast('PIN must be exactly 4 digits', 'error');
    return;
  }
  const pinStatus = document.getElementById('pin_reset_status');
  if (pinStatus) pinStatus.style.display = 'none';
  await pub('adminPin', p);
  // Save PIN to localStorage for auto-fill on next login
  try { localStorage.setItem('cbAdminPin', p); } catch(e) {}
  document.getElementById('new_pin').value = '';
  showConfirm();
}

async function removePin() {
  if (!confirm('Remove PIN protection? Anyone will be able to access the admin panel.')) return;
  await pub('adminPin', '1234'); // Reset to default
  try { localStorage.removeItem('cbAdminPin'); } catch(e) {}
  const pinStatus = document.getElementById('pin_reset_status');
  if (pinStatus) {
    pinStatus.textContent = 'PIN reset to default: 1234';
    pinStatus.style.display = 'block';
  }
  showConfirm();
}

async function verifyPin() {
  const pinInput = document.getElementById('pin_entry');
  const errorDiv = document.getElementById('pin_error');
  const entered = pinInput.value.trim();

  if (entered.length !== 4 || !/^\d{4}$/.test(entered)) {
    errorDiv.textContent = 'Please enter a 4-digit PIN';
    return;
  }

  try {
    const r = await fetch('/api/pin', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({pin: entered})
    });
    const d = await r.json();

    if (d.ok) {
      // PIN correct - hide modal and show app
      document.getElementById('pin-modal').classList.add('hide');
      document.getElementById('app').style.display = 'flex';
      // Save PIN to localStorage for convenience
      try { localStorage.setItem('cbAdminPin', entered); } catch(e) {}
    } else {
      errorDiv.textContent = 'Incorrect PIN';
      pinInput.value = '';
      pinInput.focus();
    }
  } catch(e) {
    errorDiv.textContent = 'Connection error';
    console.error('PIN verification error:', e);
  }
}

function showPinModal() {
  document.getElementById('pin-modal').classList.remove('hide');
  document.getElementById('app').style.display = 'none';
  const pinInput = document.getElementById('pin_entry');
  pinInput.value = '';
  pinInput.focus();
  document.getElementById('pin_error').textContent = '';
}

/* ===== SECTION =====
   THEME CONTROLS
===== SECTION ===== */
function setLayout(l) {
  layout = l;
  document.querySelectorAll('.lay-thumb').forEach(el =>
    el.classList.toggle('on', el.id === 'lay_' + l));
  pub('layoutType', l);
  const s = document.getElementById('layout_summary');
  if (s) s.textContent = l;
}
let _cadreEnabledToggleLocked = false;
function toggleCadreEnabled() {
  if (_cadreEnabledToggleLocked) return;
  _cadreEnabledToggleLocked = true;
  const btn = document.getElementById('cadre_enabled_btn');
  if (btn) btn.style.pointerEvents = 'none';
  btn.classList.toggle('on');
  const enabled = btn.classList.contains('on');
  pub('cadreEnabled', enabled ? 'true' : 'false');
  showConfirm();
  setTimeout(() => {
    _cadreEnabledToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
let _cadreColor = '#FFB84D';
function setCadreType(type) {
  if (type === 'color') type = 'custom';
  pub('cadreType', type);
  const row = document.getElementById('cadre_color_row');
  if (row) {
    row.style.display = (type === 'custom') ? 'flex' : 'none';
  }
  showConfirm();
}

function selectCadreType(type) {
  _cadreType = type;
  document.querySelectorAll('#cadre_type_grid .cadre-type-card').forEach(c =>
    c.classList.toggle('on', c.dataset.type === type));

  setCadreType(type);
  applyCadreDefaultsForType(type);

  const adjustBtn = document.getElementById('cadre_adjust_toggle_btn');
  if (adjustBtn) adjustBtn.style.display = 'block';

  showConfirm();
}

function applyCadreDefaultsForType(type) {
  const d = CADRE_TYPE_DEFAULTS[type] || CADRE_TYPE_DEFAULTS.glass;

  document.getElementById('cadre_opacity').value = d.opacity;
  document.getElementById('cadre_opacity_val').textContent = d.opacity + '%';
  document.getElementById('cadre_blur').value = d.blur;
  document.getElementById('cadre_blur_val').textContent = d.blur;
  document.getElementById('cadre_radius').value = d.radius;
  document.getElementById('cadre_radius_val').textContent = d.radius + 'px';
  document.getElementById('cadre_border').value = d.border;
  document.getElementById('cadre_border_val').textContent = d.border + 'px';
  document.getElementById('cadre_padding').value = d.padding;
  document.getElementById('cadre_padding_val').textContent = d.padding + 'px';

  const batch = [
    ['cadreOpacity', (d.opacity / 100).toFixed(2)],
    ['cadreBlur', String(d.blur)],
    ['cadrecornerRadius', String(d.radius)],
    ['cadreBorderWidth', String(d.border)],
    ['cadrePadding', String(d.padding)]
  ];

  if (type === 'custom' && d.color) {
    _cadreColor = d.color;
    const picker = document.getElementById('cadre_color_picker');
    if (picker) picker.value = d.color;
    const valEl = document.getElementById('cadre_color_val');
    if (valEl) valEl.textContent = d.color;
    buildCadreSwatchRow();
    batch.push(['cadreColor', d.color]);
  }

  pubBatch(batch);
}

function toggleCadreAdjust() {
  const panel = document.getElementById('cadre_adjust_panel');
  const btn = document.getElementById('cadre_adjust_toggle_btn');
  if (!panel) return;
  const isOpen = panel.style.display !== 'none';
  panel.style.display = isOpen ? 'none' : 'flex';
  if (btn) btn.textContent = isOpen ? 'Adjust' : 'Hide adjustments';
}

const debouncedPubCadreColor = debounce((v) => pub('cadreColor', v), 150);
function onCadreColorPicker(color) {
  _cadreColor = color;
  const valEl = document.getElementById('cadre_color_val');
  if (valEl) valEl.textContent = color;
  debouncedPubCadreColor(color);
  buildCadreSwatchRow();
  showConfirm();
}
function buildCadreSwatchRow() {
  const row = document.getElementById('cadre_swatch_row');
  if (!row) return;
  const current = (_cadreColor || '').toUpperCase();
  row.innerHTML = '';
  SWATCH_COLORS.forEach(hex => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'swatch' + (hex === '#FFFFFF' ? ' white' : '') + (hex === current ? ' on' : '');
    b.style.background = hex;
    b.title = hex;
    b.onclick = () => {
      const picker = document.getElementById('cadre_color_picker');
      if (picker) picker.value = hex;
      onCadreColorPicker(hex);
    };
    row.appendChild(b);
  });
}
const debouncedPubCadreOpacity = debounce((v) => pub('cadreOpacity', v), 150);
function setCadreOpacity(val) {
  const opacity = (parseInt(val) / 100).toFixed(2);
  document.getElementById('cadre_opacity_val').textContent = val + '%';
  debouncedPubCadreOpacity(opacity);
}
const debouncedPubCadreBlur = debounce((v) => pub('cadreBlur', v), 150);
function setCadreBlur(val) {
  document.getElementById('cadre_blur_val').textContent = val;
  debouncedPubCadreBlur(val);
}
const debouncedPubCadreRadius = debounce((v) => pub('cadrecornerRadius', v), 150);
function setCadreRadius(val) {
  document.getElementById('cadre_radius_val').textContent = val + 'px';
  debouncedPubCadreRadius(val);
}
const debouncedPubCadreBorder = debounce((v) => pub('cadreBorderWidth', v), 150);
function setCadreBorder(val) {
  document.getElementById('cadre_border_val').textContent = val + 'px';
  debouncedPubCadreBorder(val);
}
const debouncedPubCadrePadding = debounce((v) => pub('cadrePadding', v), 150);
function setCadrePadding(val) {
  document.getElementById('cadre_padding_val').textContent = val + 'px';
  debouncedPubCadrePadding(val);
}
function resetCadreDefaults() {
  applyCadreDefaultsForType(_cadreType);
  showConfirm();
}
let _bannerToggleLocked = false;
function toggleBanner() {
  if (_bannerToggleLocked) return;
  _bannerToggleLocked = true;
  const btn = document.getElementById('banner_btn');
  if (btn) btn.style.pointerEvents = 'none';
  bannerOn = !bannerOn;
  btn.classList.toggle('on', bannerOn);
  pub('bannerEnabled', bannerOn ? 'true' : 'false');
  setTimeout(() => {
    _bannerToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
let _catVisToggleLocked = false;
function toggleCategoryVisibility() {
  if (_catVisToggleLocked) return;
  _catVisToggleLocked = true;
  const btn = document.getElementById('cat_visible_btn');
  if (btn) btn.style.pointerEvents = 'none';
  categoryVisible = !categoryVisible;
  if (btn) btn.classList.toggle('on', categoryVisible);
  const catPreview = document.getElementById('prev_cat');
  if (catPreview) catPreview.style.display = categoryVisible ? '' : 'none';
  const rcCategoryRow = document.getElementById('rc_category_row');
  if (rcCategoryRow) rcCategoryRow.style.display = categoryVisible ? '' : 'none';
  pub('categoryVisible', categoryVisible ? 'true' : 'false');
  showConfirm();
  setTimeout(() => {
    _catVisToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
let _logoVisToggleLocked = false;
function toggleLogoVisibility() {
  if (_logoVisToggleLocked) return;
  _logoVisToggleLocked = true;
  const btn = document.getElementById('logo_visible_btn');
  if (btn) btn.style.pointerEvents = 'none';
  logoVisible = !logoVisible;
  btn.classList.toggle('on', logoVisible);
  pub('logoVisible', logoVisible ? 'true' : 'false');
  setTimeout(() => {
    _logoVisToggleLocked = false;
    if (btn) btn.style.pointerEvents = '';
  }, 300);
}
function toggleGrad() {
  gradOn = !gradOn;
  const btn = document.getElementById('grad_btn');
  btn.classList.toggle('on', gradOn);
  pub('accentGradientEnabled', gradOn ? 'true' : 'false');
}
function setFontFor(key, family) {
  if (!family) return;
  pub(key, family);
  const previewMap = {
    numberFont: ['prev_num', 'prev_cat'],
    categoryFont: ['prev_cat'],
    facilityFont: ['prev_fac'],
    bannerFont: ['prev_fac'],
    nowServingFont: ['prev_label']
  };
  (previewMap[key] || []).forEach(id => {
    try { document.getElementById(id).style.fontFamily = family; } catch(e) {}
  });
  showConfirm();
}

/* ===== SECTION =====
   FONT STYLE PICKER — big-preview tiles, same interaction
   pattern as the "Ready-made templates" grid above
===== SECTION ===== */
function allFonts() {
  const lang = (_adminLang || 'en').toLowerCase();
  return [
    ...FONT_CATALOG.filter(f => !f.languages || f.languages.includes(lang)),
    ...CUSTOM_FONTS
      .filter(f => !f.family || !FONT_CATALOG.some(b => b.family === f.family))
      .map(f => ({ family: f.family, label: f.family, custom: true, languages: ['en','fr','ar'] }))
  ];
}
function setFontTarget(target) {
  _fontTarget = target;
  document.querySelectorAll('#font_target_grid .gi').forEach(b =>
    b.classList.toggle('on', b.dataset.target === target));
  buildFontGrid();
}
function buildFontGrid() {
  const grid = document.getElementById('font_grid');
  if (!grid) return;
  const sample = FONT_TARGET_SAMPLE[_fontTarget] || 'Aa';
  const current = _fontValues[_fontTarget] || 'DM Mono';
  grid.innerHTML = '';
  allFonts().forEach(f => {
    const card = document.createElement('div');
    card.className = 'font-card' + (f.family === current ? ' on' : '');
    card.onclick = () => selectFontCard(f.family);
    card.innerHTML = `
      <div class="font-card-preview" style="font-family:'${f.family}'">${sample}</div>
      <div class="font-card-name">${f.label}${f.custom ? ' (custom)' : ''}</div>`;
    grid.appendChild(card);
  });
  const s = document.getElementById('font_summary');
  if (s) s.textContent = (FONT_TARGET_LABEL[_fontTarget] || _fontTarget) + ' · ' + current;
}
function selectFontCard(family) {
  _fontValues[_fontTarget] = family;
  setFontFor(_fontTarget, family);
  buildFontGrid();
}

/* ===== SECTION =====
   BACKGROUND
===== SECTION ===== */
// Template capsule selector state
let tplState = { category: 'food', type: 'static' };

function renderTplCapsules() {
  // Update category capsules
  document.querySelectorAll('#catCapsules .capsule').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.cat === tplState.category);
  });
  
  // Update type capsules
  document.querySelectorAll('#typeCapsules .capsule').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.type === tplState.type);
  });
  
  buildTplGrid();
}

function buildTplGrid() {
  const grid = document.getElementById('tplGrid');
  const emptyState = document.getElementById('tplEmptyState');
  
  if (!grid) return;
  
  grid.innerHTML = '';
  
  // Filter templates by category and type
  const filtered = TPLS.filter(t => t.cat === tplState.category && t.type === tplState.type);
  
  if (filtered.length === 0) {
    emptyState.style.display = 'block';
    return;
  }
  
  emptyState.style.display = 'none';
  
  filtered.forEach(t => {
    const d = document.createElement('div');
    d.className = 'tpl-card'; d.id = 'tpl_' + t.id;
    d.onclick = () => applyTpl(t);

    if (t.type === 'animated' && t.video) {
      d.innerHTML = `
      <div class="tpl-bg">
        <video src="${videoUrl(t.video)}" muted loop playsinline autoplay></video>
      </div>
      <div class="tpl-overlay"></div>
      <div class="tpl-body">
        <div class="tpl-num" style="color:${t.acc}">001</div>
        <div class="tpl-name">${t.label}</div>
      </div>`;
    } else {
      d.innerHTML = `
      <div class="tpl-bg" style="background-image:url('${thumb(t.bg)}')"></div>
      <div class="tpl-overlay"></div>
      <div class="tpl-body">
        <div class="tpl-num" style="color:${t.acc}">001</div>
        <div class="tpl-name">${t.label}</div>
      </div>`;
    }

    grid.appendChild(d);
  });
}

// Initialize capsule click handlers
document.addEventListener('DOMContentLoaded', () => {
  const catCapsules = document.getElementById('catCapsules');
  const typeCapsules = document.getElementById('typeCapsules');
  
  if (catCapsules) {
    catCapsules.addEventListener('click', (e) => {
      const btn = e.target.closest('.capsule');
      if (btn && btn.dataset.cat) {
        tplState.category = btn.dataset.cat;
        renderTplCapsules();
      }
    });
  }
  
  if (typeCapsules) {
    typeCapsules.addEventListener('click', (e) => {
      const btn = e.target.closest('.capsule');
      if (btn && btn.dataset.type) {
        tplState.type = btn.dataset.type;
        renderTplCapsules();
      }
    });
  }
  
  // Initial render
  renderTplCapsules();
});

// Legacy function for compatibility
function buildTpls() {
  renderTplCapsules();
}
function buildBgGrids() {
  console.log('[bg] GRID REBUILD CALLED (image), time=', Date.now(), 'locked=', _bgSelectionLocked);
  ['pro','food','coffee'].forEach(c => {
    const el = document.getElementById('bg_grid_' + c);
    el.innerHTML = '';
    BG[c].forEach(bg => {
      const b = document.createElement('button');
      b.className = 'bg-btn'; b.id = 'bgb_' + bg.id; b.title = bg.label;
      b.innerHTML = `<img src="${thumb(bg.id)}" alt="${bg.label}" loading="lazy"/>
                     <div class="bg-label">${bg.label}</div>`;
      b.onclick = () => selectBackground({...bg, type: 'image'});
      el.appendChild(b);
    });
  });
}
function bgTab(c) {
  document.getElementById('bg_grid_pro').classList.toggle('hide', c !== 'pro');
  document.getElementById('bg_grid_food').classList.toggle('hide', c !== 'food');
  document.getElementById('bg_grid_coffee').classList.toggle('hide', c !== 'coffee');
  document.getElementById('bg_t_pro').classList.toggle('on', c === 'pro');
  document.getElementById('bg_t_food').classList.toggle('on', c === 'food');
  document.getElementById('bg_t_coffee').classList.toggle('on', c === 'coffee');
}
function updateBgPreviewTransform() {
  const el = document.getElementById('prev_bg');
  if (!el) return;
  el.style.transform = `translate(${bgOffsetX}px, ${bgOffsetY}px) scale(${bgScale})`;
  el.style.transformOrigin = 'center center';
}
function onBgZoom(v) {
  // Only allow zoom adjustments for custom uploaded backgrounds
  if (!isBgUploaded) {
    showConfirm();
    // Reset slider to default
    document.getElementById('bg_zoom_slider').value = 100;
    return;
  }
  bgScale = Math.max(0.5, Math.min(2.0, parseFloat(v) / 100));
  document.getElementById('bg_zoom_val').textContent = Math.round(bgScale * 100) + '%';
  updateBgPreviewTransform();
  debouncedPubBgScale(bgScale);
}
function onBgMoveX(v) {
  // Only allow move adjustments for custom uploaded backgrounds
  if (!isBgUploaded) {
    showConfirm();
    // Reset slider to default
    document.getElementById('bg_move_x_slider').value = 0;
    return;
  }
  bgOffsetX = parseInt(v) || 0;
  document.getElementById('bg_move_x_val').textContent = bgOffsetX + 'px';
  updateBgPreviewTransform();
  debouncedPubBgOffsetX(bgOffsetX);
}
function onBgMoveY(v) {
  // Only allow move adjustments for custom uploaded backgrounds
  if (!isBgUploaded) {
    showConfirm();
    // Reset slider to default
    document.getElementById('bg_move_y_slider').value = 0;
    return;
  }
  bgOffsetY = parseInt(v) || 0;
  document.getElementById('bg_move_y_val').textContent = bgOffsetY + 'px';
  updateBgPreviewTransform();
  debouncedPubBgOffsetY(bgOffsetY);
}
function setBgFitMode(mode) {
  // Only allow fit mode changes for custom uploaded backgrounds
  if (!isBgUploaded) {
    showConfirm();
    // Reset select to current fit mode
    const bgFitModeSelect = document.getElementById('bg_fit_mode');
    if (bgFitModeSelect) bgFitModeSelect.value = bgFitMode;
    return;
  }
  bgFitMode = mode;
  pub('backgroundFitMode', mode);
}
function resetBgAdjust() {
  bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
  document.getElementById('bg_zoom_slider').value = 100;
  document.getElementById('bg_move_x_slider').value = 0;
  document.getElementById('bg_move_y_slider').value = 0;
  document.getElementById('bg_zoom_val').textContent = '100%';
  document.getElementById('bg_move_x_val').textContent = '0px';
  document.getElementById('bg_move_y_val').textContent = '0px';
  updateBgPreviewTransform();
  pubBatch([
    ['backgroundScale', '1.0'],
    ['backgroundOffsetX', '0'],
    ['backgroundOffsetY', '0']
  ]);
}
function highlightBg(qrcUrl) {
  // Do nothing since we removed the background selection grids
}
function setPrevBg(qrcUrl) {
  const el = document.getElementById('prev_bg');
  if (!el) return;
  // Check if it's a template qrc URL, get its thumbnail
  for (const c of ['pro','food','coffee']) {
    for (const bg of BG[c]) {
      if (qrc(bg.id, bg.ext) === qrcUrl) {
        el.style.backgroundImage = `url('${thumb(bg.id)}?t=${Date.now()}')`;
        el.style.background = '';
        return;
      }
    }
  }
  // Check if it's an uploaded or external URL
  if (qrcUrl && (qrcUrl.startsWith('/uploads/') || qrcUrl.startsWith('http'))) {
    el.style.backgroundImage = `url('${qrcUrl}?t=${Date.now()}')`;
    el.style.background = '';
    return;
  }
  // Default fallback
  el.style.backgroundImage = '';
  el.style.background = 'linear-gradient(135deg, #1e1e1e, #2d2d2d)';
}
let templateChangeInProgress = false;
const TEMPLATE_CHANGE_LOCK_MS = 1500;

function lockTemplatePicker(locked, activeId) {
  document.querySelectorAll('.tpl-card').forEach(el => {
    const isActive = activeId && el.id === 'tpl_' + activeId;
    el.classList.toggle('tpl-card-disabled', locked && !isActive);
    el.classList.toggle('applying', locked && isActive);
  });
}

async function applyTpl(t) {
  console.log('[tpl] click, locked=', templateChangeInProgress, 'time=', Date.now());
  // Prevent rapid consecutive template changes
  if (templateChangeInProgress) {
    console.log('[tpl] BLOCKED, time=', Date.now());
    return;
  }
  templateChangeInProgress = true;
  console.log('[tpl] LOCK SET, time=', Date.now());
  lockTemplatePicker(true, t.id);
  
  try {
    document.querySelectorAll('.tpl-card').forEach(c => c.classList.remove('on'));
    const card = document.getElementById('tpl_' + t.id);
    if (card) card.classList.add('on');
    setAccLocal(t.acc);

  // Reset adjustment state when applying template
  isBgUploaded = false; // Templates are not custom uploads
  bgFitMode = t.fit || 'crop'; // Use template's fit mode
  bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
  const zoomSlider = document.getElementById('bg_zoom_slider');
  const moveXSlider = document.getElementById('bg_move_x_slider');
  const moveYSlider = document.getElementById('bg_move_y_slider');
  const zoomVal = document.getElementById('bg_zoom_val');
  const moveXVal = document.getElementById('bg_move_x_val');
  const moveYVal = document.getElementById('bg_move_y_val');
  const bgFitModeSelect = document.getElementById('bg_fit_mode');
  if (zoomSlider) zoomSlider.value = 100;
  if (moveXSlider) moveXSlider.value = 0;
  if (moveYSlider) moveYSlider.value = 0;
  if (zoomVal) zoomVal.textContent = '100%';
  if (moveXVal) moveXVal.textContent = '0px';
  if (moveYVal) moveYVal.textContent = '0px';
  if (bgFitModeSelect) bgFitModeSelect.value = bgFitMode;
  if (typeof updateBgPreviewTransform === 'function') updateBgPreviewTransform();
  
  // Handle different template types
  if (t.id === 'custom') {
    // Custom/empty template - no background, ready for upload
    const previewEl = document.getElementById('prev_bg');
    if (previewEl) {
      previewEl.innerHTML = '';
      previewEl.style.backgroundImage = 'none';
      previewEl.style.background = 'linear-gradient(135deg, #1e1e1e, #2d2d2d)';
    }
    const bgSelLbl = document.getElementById('bg_sel_lbl');
    if (bgSelLbl) bgSelLbl.textContent = 'Ready for custom upload';
    const bgs = document.getElementById('bg_summary'); if (bgs) bgs.textContent = 'Custom - ready to upload';
    
    await pubBatch([
      ['backgroundType', 'image'],
      ['backgroundImage', ''],
      ['backgroundOrientation', t.ori],
      ['backgroundFitMode', t.fit || 'auto'],
      ['backgroundScale', '1.0'],
      ['backgroundOffsetX', '0'],
      ['backgroundOffsetY', '0'],
      ['accentColor', t.acc],
      // ['numberFont', 'DM Mono'],  ← removed
    ]);
  } else if (t.type === 'animated' && t.video) {
    // Animated video template
    const previewEl = document.getElementById('prev_bg');
    previewEl.innerHTML = '';
    const vidUrl = videoUrl(t.video);
    console.log('[applyTpl] Animated template - video:', t.video, 'url:', vidUrl);
    previewEl.innerHTML = `<video src="${vidUrl}" muted loop playsinline autoplay></video>`;
    bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
    const zoomSlider = document.getElementById('bg_zoom_slider');
    const moveXSlider = document.getElementById('bg_move_x_slider');
    const moveYSlider = document.getElementById('bg_move_y_slider');
    if (zoomSlider) zoomSlider.value = 100;
    if (moveXSlider) moveXSlider.value = 0;
    if (moveYSlider) moveYSlider.value = 0;

    await pubBatch([
      ['backgroundType', 'video'],
      ['backgroundVideoSource', vidUrl],
      ['backgroundOrientation', t.ori || ''],
      ['backgroundFitMode', t.fit || 'auto'],
      ['backgroundScale', '1.0'],
      ['backgroundOffsetX', '0'],
      ['backgroundOffsetY', '0'],
      ['accentColor', t.acc],
      // ['numberFont', 'DM Mono'],  ← removed
    ]);
  } else {
    // Image template
    const previewEl = document.getElementById('prev_bg');
    previewEl.innerHTML = '';
    const bgQrc = qrc(t.bg, t.ext);
    console.log('[applyTpl] Image template - bg:', t.bg, 'ext:', t.ext, 'qrc:', bgQrc);
    setPrevBg(bgQrc);
    bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
    const zoomSlider = document.getElementById('bg_zoom_slider');
    const moveXSlider = document.getElementById('bg_move_x_slider');
    const moveYSlider = document.getElementById('bg_move_y_slider');
    if (zoomSlider) zoomSlider.value = 100;
    if (moveXSlider) moveXSlider.value = 0;
    if (moveYSlider) moveYSlider.value = 0;

    await pubBatch([
      ['backgroundType', 'image'],
      ['backgroundImage', bgQrc],
      ['backgroundOrientation', t.ori || ''],
      ['backgroundFitMode', t.fit || 'auto'],
      ['backgroundScale', '1.0'],
      ['backgroundOffsetX', '0'],
      ['backgroundOffsetY', '0'],
      ['accentColor', t.acc],
      // ['numberFont', 'DM Mono'],  ← removed
    ]);
  }
  showConfirm();
  } catch (e) {
    console.error('Template change error:', e);
    toast('Template failed to apply', 'error');
  } finally {
    setTimeout(() => {
      templateChangeInProgress = false;
      console.log('[tpl] LOCK RELEASED, time=', Date.now());
      lockTemplatePicker(false);
    }, TEMPLATE_CHANGE_LOCK_MS);
  }
}
function removeBg() {
  // Only allow removal if current background is custom uploaded
  if (!isBgUploaded) {
    showConfirm();
    return;
  }

  const def = 'qrc:/app/res/image/ff_burger_pattern.jpg';
  curBg = def;
  isBgUploaded = false; // Reset to template background
  bgFitMode = 'crop'; // Reset to default template fit mode
  bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
  const zoomSlider = document.getElementById('bg_zoom_slider');
  const moveXSlider = document.getElementById('bg_move_x_slider');
  const moveYSlider = document.getElementById('bg_move_y_slider');
  const zoomVal = document.getElementById('bg_zoom_val');
  const moveXVal = document.getElementById('bg_move_x_val');
  const moveYVal = document.getElementById('bg_move_y_val');
  const bgFitModeSelect = document.getElementById('bg_fit_mode');
  if (zoomSlider) zoomSlider.value = 100;
  if (moveXSlider) moveXSlider.value = 0;
  if (moveYSlider) moveYSlider.value = 0;
  if (zoomVal) zoomVal.textContent = '100%';
  if (moveXVal) moveXVal.textContent = '0px';
  if (moveYVal) moveYVal.textContent = '0px';
  if (bgFitModeSelect) bgFitModeSelect.value = 'crop';
  if (typeof updateBgPreviewTransform === 'function') updateBgPreviewTransform();
  pubBatch([
    ['backgroundType', 'image'],
    ['backgroundImage', def],
    ['backgroundOrientation', 'portrait'],
    ['backgroundFitMode', 'crop'],
    ['backgroundScale', '1.0'],
    ['backgroundOffsetX', '0'],
    ['backgroundOffsetY', '0']
  ]).then(() => {
    setPrevBg(def);
    highlightBg(def);
    showConfirm();
  });
}

/* ===== SECTION =====
   COLOR PICKER
===== SECTION ===== */
function initPicker() {
  pickerCanvas = document.getElementById('color_canvas');
  if (!pickerCanvas || pickerCtx) return;
  pickerCtx = pickerCanvas.getContext('2d');
  pickerCanvas.addEventListener('mousedown', e => { isDragging = true; pickColor(e); });
  pickerCanvas.addEventListener('touchstart', e => { isDragging = true; pickColor(e.touches[0]); }, {passive:true});
  window.addEventListener('mousemove', e => { if (isDragging) pickColor(e); });
  window.addEventListener('touchmove', e => { if (isDragging) pickColor(e.touches[0]); }, {passive:true});
  window.addEventListener('mouseup',  () => isDragging = false);
  window.addEventListener('touchend', () => isDragging = false);
  drawSquare();
}
function drawSquare() {
  if (!pickerCtx) return;
  const w = pickerCanvas.width, h = pickerCanvas.height;
  const gW = pickerCtx.createLinearGradient(0,0,w,0);
  gW.addColorStop(0,'#fff'); gW.addColorStop(1,`hsl(${currentHue},100%,50%)`);
  pickerCtx.fillStyle = gW; pickerCtx.fillRect(0,0,w,h);
  const gB = pickerCtx.createLinearGradient(0,0,0,h);
  gB.addColorStop(0,'transparent'); gB.addColorStop(1,'#000');
  pickerCtx.fillStyle = gB; pickerCtx.fillRect(0,0,w,h);
}
function pickColor(e) {
  const r = pickerCanvas.getBoundingClientRect();
  const x = Math.max(0,Math.min(pickerCanvas.width,  (e.clientX-r.left)*(pickerCanvas.width/r.width)));
  const y = Math.max(0,Math.min(pickerCanvas.height, (e.clientY-r.top)*(pickerCanvas.height/r.height)));
  currentSat = (x/pickerCanvas.width)*100;
  currentVal = 100-(y/pickerCanvas.height)*100;
  const px = pickerCtx.getImageData(Math.floor(x),Math.floor(y),1,1).data;
  const hex = '#'+[px[0],px[1],px[2]].map(c=>c.toString(16).padStart(2,'0')).join('');
  document.getElementById('color_hex').value = hex;
  setAccLocal(hex); pub('accentColor', hex);
}
function updateHue(h) {
  currentHue = parseInt(h); drawSquare();
  const cw = pickerCanvas?pickerCanvas.width:300, ch = pickerCanvas?pickerCanvas.height:140;
  const x = (currentSat/100)*cw, y = (1-currentVal/100)*ch;
  if (pickerCtx) {
    const px = pickerCtx.getImageData(Math.max(0,Math.floor(x)),Math.max(0,Math.floor(y)),1,1).data;
    const hex = '#'+[px[0],px[1],px[2]].map(c=>c.toString(16).padStart(2,'0')).join('');
    setAccLocal(hex); pub('accentColor',hex);
    document.getElementById('color_hex').value = hex;
  }
}
function updateHex(hex) {
  if (/^#[0-9A-F]{6}$/i.test(hex)) { setAccLocal(hex); pub('accentColor',hex); }
}
function setAccLocal(hex) {
  acc = hex;
  document.documentElement.style.setProperty('--acc', hex);
  document.getElementById('prev_bar').style.background = hex;
  document.getElementById('prev_cat').style.color = hex;
  const colorHex = document.getElementById('color_hex');
  if (colorHex) colorHex.value = hex;
  const sw = document.getElementById('acc_swatch');
  if (sw) sw.style.background = hex;
  const r=parseInt(hex.slice(1,3),16),g=parseInt(hex.slice(3,5),16),b=parseInt(hex.slice(5,7),16);
  const max=Math.max(r,g,b)/255,min=Math.min(r,g,b)/255;
  let h=0;
  if (max!==min){const d=max-min,rm=r/255,gm=g/255,bm=b/255;
    if(max===rm)h=((gm-bm)/d+(gm<bm?6:0))*60;
    else if(max===gm)h=((bm-rm)/d+2)*60;
    else h=((rm-gm)/d+4)*60;}
  const hueSlider = document.getElementById('hue_slider');
  if (hueSlider) hueSlider.value = Math.round(h);
}

/* ===== SECTION =====
   UPLOADS
===== SECTION ===== */
async function uploadBg(input) {
  const file = input.files[0]; if (!file) return;
  if (file.size > 5*1024*1024) { toast('File too large — max 5 MB', 'error'); input.value = ''; return; }
  const uploadLabel = document.querySelector('label[for="bg_file"]');
  if (uploadLabel) uploadLabel.classList.add('loading-btn');
  input.disabled = true;
  const fd = new FormData(); fd.append('background', file);
  try {
    const r = await fetch('/api/background',{method:'POST',body:fd});
    const d = await r.json();
    if (!d.ok) { toast(d.error || 'Upload failed', 'error'); return; }
    if (d.ok) {
      curBg = d.url;
      isBgUploaded = true; // Mark as uploaded background
      bgFitMode = 'auto'; // Set default fit mode for uploads
      bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
      document.getElementById('prev_bg').style.backgroundImage=`url('${d.url}?${Date.now()}')`;
      const zoomSlider = document.getElementById('bg_zoom_slider');
      const moveXSlider = document.getElementById('bg_move_x_slider');
      const moveYSlider = document.getElementById('bg_move_y_slider');
      const zoomVal = document.getElementById('bg_zoom_val');
      const moveXVal = document.getElementById('bg_move_x_val');
      const moveYVal = document.getElementById('bg_move_y_val');
      const bgFitModeSelect = document.getElementById('bg_fit_mode');
      if (zoomSlider) zoomSlider.value = 100;
      if (moveXSlider) moveXSlider.value = 0;
      if (moveYSlider) moveYSlider.value = 0;
      if (zoomVal) zoomVal.textContent = '100%';
      if (moveXVal) moveXVal.textContent = '0px';
      if (moveYVal) moveYVal.textContent = '0px';
      if (bgFitModeSelect) bgFitModeSelect.value = 'auto';
      if (typeof updateBgPreviewTransform === 'function') updateBgPreviewTransform();
      pubBatch([
        ['backgroundType', 'image'],
        ['backgroundImage', d.path],
        ['backgroundFitMode', 'auto'],
        ['backgroundScale', '1.0'],
        ['backgroundOffsetX', '0'],
        ['backgroundOffsetY', '0']
      ]);
      document.getElementById('bg_hint').style.display='none';
      const img = document.getElementById('bg_prev');
      img.src=d.url+'?'+Date.now(); img.style.display='block';
      document.getElementById('bg_sel_lbl').textContent='Custom upload';
      const bgs = document.getElementById('bg_summary'); if (bgs) bgs.textContent = 'Custom upload';
      showConfirm();
    }
  } catch(e) {
    toast('Upload failed — check connection', 'error');
  } finally {
    if (uploadLabel) uploadLabel.classList.remove('loading-btn');
    input.disabled = false;
    input.value = '';
  }
}
async function uploadLogo(input) {
  const file = input.files[0]; if (!file) return;
  if (file.size > 2*1024*1024) { toast('File too large — max 2 MB', 'error'); input.value = ''; return; }
  const uploadLabel = document.querySelector('label[for="logo_file"]');
  if (uploadLabel) uploadLabel.classList.add('loading-btn');
  input.disabled = true;
  const fd = new FormData(); fd.append('logo', file);
  try {
    const r = await fetch('/api/logo',{method:'POST',body:fd});
    const d = await r.json();
    if (!d.ok) { toast(d.error || 'Upload failed', 'error'); return; }
    const img = document.getElementById('logo_prev');
    const bustedUrl = d.url + (d.url.includes('?') ? '&' : '?') + 'v=' + Date.now();
    img.src = bustedUrl;
    img.style.display='block';
    document.getElementById('logo_hint').style.display='none';
    const ls = document.getElementById('logo_summary'); if (ls) ls.textContent = 'Logo uploaded';

    logoVisible = true;
    const logoBtn = document.getElementById('logo_visible_btn');
    if (logoBtn) logoBtn.classList.add('on');
    await pub('logoSource', d.path);
    await pub('logoVisible', 'true');

    showConfirm();
  } catch(e) {
    toast('Upload failed — check connection', 'error');
  } finally {
    if (uploadLabel) uploadLabel.classList.remove('loading-btn');
    input.disabled = false;
    input.value = '';
  }
}
async function deleteLogo() {
  if (!confirm('Are you sure you want to remove the custom logo?')) return;
  
  try {
    const r = await fetch('/api/delete_logo', {method:'POST'});
    const d = await r.json();
    if (d.ok) {
      const img = document.getElementById('logo_prev');
      img.style.display='none';
      img.src = '';                          // NEW — clear stale bytes
      document.getElementById('logo_hint').style.display='block';
      const ls = document.getElementById('logo_summary'); if (ls) ls.textContent = 'No logo uploaded';

      // NEW — keep the admin toggle in sync with the backend's auto-hide
      logoVisible = false;
      const logoBtn = document.getElementById('logo_visible_btn');
      if (logoBtn) logoBtn.classList.remove('on');
      await pub('logoSource', '');

      showConfirm();
    }
  } catch(e) {}
}
async function uploadFont(input) {
  const file = input.files[0]; if (!file) return;
  if (file.size > 2*1024*1024) { toast('File too large — max 2 MB', 'error'); input.value = ''; return; }
  const uploadArea = document.getElementById('font_upload_area');
  if (uploadArea) uploadArea.classList.add('loading-btn');
  input.disabled = true;
  const fd = new FormData(); fd.append('font', file);
  try {
    const r = await fetch('/api/font',{method:'POST',body:fd});
    const d = await r.json();
    if (!d.ok) { toast(d.error || 'Upload failed', 'error'); return; }
    await loadFonts();
    showConfirm();
  } catch(e) {
    toast('Upload failed — check connection', 'error');
  } finally {
    if (uploadArea) uploadArea.classList.remove('loading-btn');
    input.disabled = false;
    input.value = '';
  }
}
async function loadFonts() {
  try {
    const r = await fetch('/api/fonts');
    const d = await r.json();
    if (!d.ok) return;

    const customFonts = (d.fonts || []).filter(f => !f.builtin);
    CUSTOM_FONTS = customFonts;
    document.getElementById('dyn_fonts').textContent =
      CUSTOM_FONTS.map(f=>`@font-face{font-family:'${f.family}';src:url('${f.url}')}`).join('\n');

    buildFontTypeGrid();
    buildFontGrid();
  } catch(e) {}
}
function onFontFamilyChange(family) {
  const isCustom = CUSTOM_FONTS.some(f => f.family === family);
  setFontFamily(family);
  buildFontTypeGrid();
}
async function deleteFont(filename) {
  if (!confirm('Are you sure you want to delete this font?')) return;
  try {
    const r = await fetch('/api/delete_font', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({filename})
    });
    const d = await r.json();
    if (d.ok) {
      await loadFonts();
      showConfirm();
    } else {
      alert(d.error || 'Failed to delete font');
    }
  } catch(e) {
    alert('Failed to delete font');
  }
}

/* ===== SECTION =====
   STATS
===== SECTION ===== */
async function loadStats() {
  try {
    const r = await fetch('/api/stats');
    const d = await r.json();

    // --- Live Metrics ---
    const statUptime = document.getElementById('stat_uptime');
    const statSessions = document.getElementById('stat_sessions');
    const statChanges = document.getElementById('stat_changes');
    const statCurrent = document.getElementById('stat_current');
    if (statUptime) statUptime.textContent = d.uptime || '--';
    if (statSessions) statSessions.textContent = String(d.session_count || 0);
    if (statChanges) statChanges.textContent = String(d.number_change_count || 0);
    if (statCurrent) statCurrent.textContent = d.currentNumber || '--';

    // --- Last Restart ---
    const ts = d.last_restart_ts;
    if (ts) {
      const dt = new Date(ts * 1000);
      const hRst = document.getElementById('h_rst');
      if (hRst) hRst.textContent =
        dt.toLocaleDateString() + ' ' + dt.toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
    }

    // --- Health Status ---
    const healthIndicator = document.getElementById('health_indicator');
    const healthStatus = document.getElementById('health_status');
    const warningDot = document.getElementById('health_warning_dot');

    if (healthIndicator && healthStatus) {
      if (d.uptime && d.uptime !== '0s' && d.uptime !== '0m 0s') {
        healthIndicator.style.background = 'var(--success)';
        healthIndicator.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="width:40px;height:40px"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>';
        healthStatus.textContent = 'System Online';
        healthStatus.style.color = 'var(--success)';
        if (warningDot) warningDot.style.display = 'none';
      } else {
        healthIndicator.style.background = 'var(--warning)';
        healthIndicator.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="width:40px;height:40px"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>';
        healthStatus.textContent = 'Just Started';
        healthStatus.style.color = 'var(--warning)';
        if (warningDot) warningDot.style.display = 'block';
      }
    }

    const connServer = document.getElementById('conn_server');
    if (connServer) {
      connServer.textContent = 'Connected';
      connServer.style.color = 'var(--success)';
    }

    // --- Remote Controller (MQTT) Status ---
    const mqttBrokerStatus = document.getElementById('mqtt_broker_status');
    const mqttStatusDetail = document.getElementById('mqtt_status_detail');
    if (mqttBrokerStatus && mqttStatusDetail) {
      if (_mqttConnected) {
        mqttBrokerStatus.textContent = 'Connected';
        mqttBrokerStatus.style.color = 'var(--success)';
        mqttStatusDetail.textContent = _mqttStatus || 'Connected';
        mqttStatusDetail.style.color = 'var(--text)';
      } else {
        mqttBrokerStatus.textContent = 'Disconnected';
        mqttBrokerStatus.style.color = 'var(--danger)';
        mqttStatusDetail.textContent = _mqttStatus || 'Disconnected';
        mqttStatusDetail.style.color = 'var(--text-secondary)';
      }
    }

  } catch(e) {
    console.error('Stats error:', e);
    const statUptime = document.getElementById('stat_uptime');
    const statSessions = document.getElementById('stat_sessions');
    const statChanges = document.getElementById('stat_changes');
    const statCurrent = document.getElementById('stat_current');
    if (statUptime) statUptime.textContent = 'Error';
    if (statSessions) statSessions.textContent = '--';
    if (statChanges) statChanges.textContent = '--';
    if (statCurrent) statCurrent.textContent = '--';

    const healthIndicator = document.getElementById('health_indicator');
    if (healthIndicator) {
      healthIndicator.style.background = 'var(--danger)';
      healthIndicator.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="width:40px;height:40px"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
    }
    const healthStatus = document.getElementById('health_status');
    if (healthStatus) {
      healthStatus.textContent = 'Connection Lost';
      healthStatus.style.color = 'var(--danger)';
    }
    const connServer = document.getElementById('conn_server');
    if (connServer) {
      connServer.textContent = 'Disconnected';
      connServer.style.color = 'var(--danger)';
    }
    const healthWarningDot = document.getElementById('health_warning_dot');
    if (healthWarningDot) {
      healthWarningDot.style.display = 'block';
    }
  }
}
/* ===== SECTION =====
   API
===== SECTION ===== */
function pub(key, value) {
  // Try WebSocket first if connected
  if (_ws && _wsReady) {
    try {
      _ws.send(JSON.stringify({type: "publish", key: key, value: String(value)}));
      return Promise.resolve({ok: true});
    } catch (e) {
      console.warn('[ws] Send failed, falling back to HTTP:', e);
    }
  }
  // Fallback to HTTP
  return fetch('/api/publish',{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({topic:'display/'+key, payload:String(value)})
  });
}

function pubBatch(items) {
  // Try WebSocket first if connected
  if (_ws && _wsReady) {
    try {
      items.forEach(([key, value]) => {
        _ws.send(JSON.stringify({type: "publish", key: key, value: String(value)}));
      });
      return Promise.resolve({ok: true});
    } catch (e) {
      console.warn('[ws] Batch send failed, falling back to HTTP:', e);
    }
  }
  // Fallback to HTTP
  return fetch('/api/publish_batch', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({
      items: items.map(([key, value]) => ({topic:'display/'+key, payload:String(value)}))
    })
  });
}

function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Debounced publish functions for sliders (150ms delay)
// NOTE: each text-size field gets its OWN debounced function — sharing one
// timer across keys would let a second slider cancel the first slider's
// pending publish (they'd stomp on each other's timeout).
const debouncedPubLogoSize = debounce((v) => pub('logoSize', String(v)), 150);
const debouncedPubVolStep = debounce((v) => pub('audioVolumeStep', String(v)), 120);
const _textSizeDebouncers = {};
function debouncedPubTextSize(key, v) {
  if (!_textSizeDebouncers[key]) {
    _textSizeDebouncers[key] = debounce((val) => pub(key, String(val)), 150);
  }
  _textSizeDebouncers[key](v);
}
const debouncedPubBgScale = debounce((v) => pub('backgroundScale', String(v)), 150);
const debouncedPubBgOffsetX = debounce((v) => pub('backgroundOffsetX', String(v)), 150);
const debouncedPubBgOffsetY = debounce((v) => pub('backgroundOffsetY', String(v)), 150);

// Background selection cooldown lock
let _bgSelectionLocked = false;
const BG_SELECTION_LOCK_MS = 1500;

function selectBackground(item) {
  console.log('[bg] click, locked=', _bgSelectionLocked, 'time=', Date.now());
  if (_bgSelectionLocked) {
    console.log('[bg] BLOCKED, time=', Date.now());
    return; // hard block, no queueing
  }

  _bgSelectionLocked = true;
  console.log('[bg] LOCK SET, time=', Date.now());
  lockBackgroundPicker(true); // visual: dim thumbnails, show small spinner/badge

  // Update UI
  document.querySelectorAll('.bg-btn').forEach(b => b.classList.remove('on'));
  const btnId = 'bgb_' + item.id;
  const btn = document.getElementById(btnId);
  if (btn) btn.classList.add('on');
  document.getElementById('bg_sel_lbl').textContent = item.label;
  const bgs = document.getElementById('bg_summary'); if (bgs) bgs.textContent = item.label;

  // Show preview
  const previewEl = document.getElementById('prev_bg');
  previewEl.innerHTML = '';

  if (item.type === 'animated' && item.video) {
    const vidUrl = videoUrl(item.video);
    previewEl.innerHTML = `<video src="${vidUrl}" muted loop playsinline autoplay></video>`;
    const payload = [
      ['backgroundType', 'video'],
      ['backgroundVideoSource', vidUrl],
      ['backgroundOrientation', item.ori || ''],
      ['backgroundFitMode', item.fit || 'auto'],
      ['backgroundScale', '1.0'],
      ['backgroundOffsetX', '0'],
      ['backgroundOffsetY', '0']
    ];
    pubBatch(payload)
      .then(showConfirm)
      .catch((e) => showError(e))
      .finally(() => {
        setTimeout(() => {
          _bgSelectionLocked = false;
          console.log('[bg] LOCK RELEASED, time=', Date.now());
          lockBackgroundPicker(false);
        }, BG_SELECTION_LOCK_MS);
      });
    return;
  }

  setPrevBg(qrc(item.id, item.ext));
  bgScale = 1.0; bgOffsetX = 0; bgOffsetY = 0;
  document.getElementById('bg_zoom_slider').value = 100;
  document.getElementById('bg_move_x_slider').value = 0;
  document.getElementById('bg_move_y_slider').value = 0;
  document.getElementById('bg_zoom_val').textContent = '100%';
  document.getElementById('bg_move_x_val').textContent = '0px';
  document.getElementById('bg_move_y_val').textContent = '0px';
  updateBgPreviewTransform();

  const payload = [
        ['backgroundType', 'image'],
        ['backgroundImage', qrc(item.id, item.ext)],
        ['backgroundOrientation', item.ori || ''],
        ['backgroundFitMode', item.fit || 'auto'],
        ['backgroundScale', '1.0'],
        ['backgroundOffsetX', '0'],
        ['backgroundOffsetY', '0']
      ];

  pubBatch(payload)
    .then(showConfirm)
    .catch((e) => showError(e))
    .finally(() => {
      setTimeout(() => {
        _bgSelectionLocked = false;
        console.log('[bg] LOCK RELEASED, time=', Date.now());
        lockBackgroundPicker(false);
      }, BG_SELECTION_LOCK_MS);
    });
}

function lockBackgroundPicker(locked) {
  document.querySelectorAll('.bg-btn').forEach(el => {
    el.classList.toggle('bg-btn-disabled', locked);
  });
  const statusEl = document.getElementById('bg-picker-status');
  if (statusEl) statusEl.textContent = locked ? 'Applying…' : '';
}

/* ===== SECTION =====
   INIT — load state from /api/state and hydrate UI
===== SECTION ===== */
async function init() {
  // Check if PIN is saved in localStorage for auto-fill
  let autoVerified = false;
  try {
    const savedPin = localStorage.getItem('cbAdminPin');
    if (savedPin && savedPin.length === 4) {
      document.getElementById('pin_entry').value = savedPin;
      // Auto-verify saved PIN
      const r = await fetch('/api/pin', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({pin: savedPin})
      });
      const d = await r.json();
      if (d.ok) {
        autoVerified = true;
      }
    }
  } catch(e) {}

  // Show PIN modal if auto-verification failed
  if (!autoVerified) {
    showPinModal();
  } else {
    document.getElementById('pin-modal').classList.add('hide');
    document.getElementById('app').style.display = 'flex';
  }

  // Set Home as default tab
  tab('home');
  buildTpls();

  try {
    const r = await fetch('/api/state');
    if (!r.ok) throw new Error(`Server returned ${r.status}`);
    const d = await r.json();

    // Update connection label (WebSocket status only, not MQTT)
    const connDot = document.getElementById('dot');
    const connLbl = document.getElementById('conn_lbl');
    // Store MQTT status for System Health tab
    _mqttConnected = !!d.mqttConnected;
    _mqttStatus = (d.mqttStatus || 'Connected').toString();
    // Header shows WebSocket status only
    if (_wsReady) {
      connDot.classList.remove('off');
      connDot.classList.add('on');
      connLbl.textContent = 'Connected';
    } else {
      connDot.classList.remove('on');
      connDot.classList.add('off');
      connLbl.textContent = 'Connecting...';
    }
    updateLockState();

    cat = d.category || 'A';
    document.getElementById('cat_id').value        = cat;
    document.getElementById('rc_code').textContent = cat;
    const cname = d.categoryDisplayName || 'Category A';
    document.getElementById('cat_name').value       = cname;
    document.getElementById('rc_name').textContent  = cname;
    document.getElementById('prev_cat').textContent = cname;
    const catS = document.getElementById('cat_summary'); if (catS) catS.textContent = cname;
    categoryVisible = d.categoryVisible !== 'false' && d.categoryVisible !== false;
    const catVisibleBtn = document.getElementById('cat_visible_btn');
    if (catVisibleBtn) catVisibleBtn.classList.toggle('on', categoryVisible);
    const catPreview = document.getElementById('prev_cat');
    if (catPreview) catPreview.style.display = categoryVisible ? '' : 'none';
    const rcCategoryRow = document.getElementById('rc_category_row');
    if (rcCategoryRow) rcCategoryRow.style.display = categoryVisible ? '' : 'none';

        document.getElementById('num_input').value      = parseInt(d.currentNumber)||0;
    liveCurrentNumber = String(parseInt(d.currentNumber)||0).padStart(2,'0');
    document.getElementById('prev_num').textContent = d.currentNumber||'00';
    document.getElementById('queueNumberDisplay').textContent = d.currentNumber||'00';
    // Force la taille de la prévisualisation au chargement
    const initNumSize = parseInt(d.numberFontSize)||96;
    document.getElementById('prev_num').style.fontSize = initNumSize + 'px';
    document.getElementById('facility').value        = d.facilityName||'';
    document.getElementById('prev_fac').textContent  = d.facilityName||'';
    document.getElementById('banner').value          = d.bannerText||'';
    document.getElementById('now_serving_text').value = d.nowServingText||'NOW SERVING';

    if (d.accentColor) setAccLocal(d.accentColor);

    if (d.layoutType) {
      layout = d.layoutType;
      document.querySelectorAll('.lay-thumb').forEach(el =>
        el.classList.toggle('on', el.id==='lay_'+d.layoutType));
      const layS = document.getElementById('layout_summary'); if (layS) layS.textContent = d.layoutType;
    }

    if (d.backgroundImage) {
      curBg = d.backgroundImage;
      // Determine if this is a custom upload or template
      isBgUploaded = d.backgroundImage.startsWith('/uploads/');
      setPrevBg(d.backgroundImage);
      highlightBg(d.backgroundImage);
    }
    if (d.backgroundFitMode) {
      const fitMode = d.backgroundFitMode;
      if (fitMode === 'fit' || fitMode === 'crop' || fitMode === 'stretch' || fitMode === 'auto') {
        const bgFitModeSelect = document.getElementById('bg_fit_mode');
        if (bgFitModeSelect) {
          bgFitModeSelect.value = fitMode;
          bgFitMode = fitMode;
        }
      }
    }
    bgScale = parseFloat(d.backgroundScale || '1.0') || 1.0;
    bgOffsetX = parseInt(d.backgroundOffsetX || '0') || 0;
    bgOffsetY = parseInt(d.backgroundOffsetY || '0') || 0;
    const zoomSlider = document.getElementById('bg_zoom_slider');
    const moveXSlider = document.getElementById('bg_move_x_slider');
    const moveYSlider = document.getElementById('bg_move_y_slider');
    const zoomVal = document.getElementById('bg_zoom_val');
    const moveXVal = document.getElementById('bg_move_x_val');
    const moveYVal = document.getElementById('bg_move_y_val');
    if (zoomSlider) zoomSlider.value = Math.round(bgScale * 100);
    if (moveXSlider) moveXSlider.value = bgOffsetX;
    if (moveYSlider) moveYSlider.value = bgOffsetY;
    if (zoomVal) zoomVal.textContent = Math.round(bgScale * 100) + '%';
    if (moveXVal) moveXVal.textContent = bgOffsetX + 'px';
    if (moveYVal) moveYVal.textContent = bgOffsetY + 'px';
    if (typeof updateBgPreviewTransform === 'function') updateBgPreviewTransform();

    // Logo — show empty-state prompt if no logo uploaded yet
    if (d.logoUrl) {
      const img = document.getElementById('logo_prev');
      if (img) {
        img.src = d.logoUrl; img.style.display='block';
        const logoHint = document.getElementById('logo_hint');
        if (logoHint) logoHint.style.display='none';
        const ls = document.getElementById('logo_summary'); if (ls) ls.textContent = 'Logo uploaded';
      }
    } else {
      const logoHint = document.getElementById('logo_hint');
      if (logoHint) logoHint.textContent = 'No logo uploaded — tap to add one';
    }
    if (d.logoPosition) {
      const logoPos = document.getElementById('logo_pos');
      if (logoPos) logoPos.value = d.logoPosition;
    }
    logoVisible = d.logoVisible !== 'false' && d.logoVisible !== false;
    const logoBtn = document.getElementById('logo_visible_btn');
    if (logoBtn) {
      logoBtn.classList.toggle('on', logoVisible);
    }

    facilityVisible = d.facilityVisible !== 'false' && d.facilityVisible !== false;
    const facilityBtn = document.getElementById('facility_visible_btn');
    if (facilityBtn) {
      facilityBtn.classList.toggle('on', facilityVisible);
    }

    nowServingVisible = d.nowServingVisible !== 'false' && d.nowServingVisible !== false;
    const nowServingBtn = document.getElementById('now_serving_visible_btn');
    if (nowServingBtn) {
      nowServingBtn.classList.toggle('on', nowServingVisible);
    }

    // Audio state
    muted   = d.audioMuted==='true'||d.audioMuted===true;
    volStep = parseInt(d.audioVolumeStep)||3;
    ttsOn   = d.ttsEnabled!=='false'&&d.ttsEnabled!==false;
    bannerOn= d.bannerEnabled!=='false'&&d.bannerEnabled!==false;
    gradOn  = d.accentGradientEnabled==='true'||d.accentGradientEnabled===true;
    window.audioPlaying = d.audioPlaying === true;

    document.getElementById('mute_btn').classList.toggle('on', muted);
    // Initialize volume slider from step index
    const pctInit = Math.round((volStep / 4) * 100);
    const vs = document.getElementById('vol_slider');
    if (vs) { vs.value = pctInit; document.getElementById('vol_label').textContent = pctInit + '%'; }
    document.getElementById('tts_btn').classList.toggle('on', ttsOn);
    document.getElementById('tts_lang').value = d.ttsLanguage||'en';
    updateTtsSummary();
    document.getElementById('banner_btn').classList.toggle('on', bannerOn);

    // Cadre settings
    const cadreEnabled = d.cadreEnabled === 'true' || d.cadreEnabled === true;
    document.getElementById('cadre_enabled_btn').classList.toggle('on', cadreEnabled);
    const cadreType = (d.cadreType === 'color') ? 'custom' : (d.cadreType || 'glass');
    _cadreType = cadreType;
    document.querySelectorAll('#cadre_type_grid .cadre-type-card').forEach(c =>
      c.classList.toggle('on', c.dataset.type === cadreType));
    if (d.cadreType) {
      const adjustBtn = document.getElementById('cadre_adjust_toggle_btn');
      if (adjustBtn) adjustBtn.style.display = 'block';
    }
    _cadreColor = d.cadreColor || '#FFB84D';
    const cPicker = document.getElementById('cadre_color_picker');
    if (cPicker) cPicker.value = _cadreColor;
    const cVal = document.getElementById('cadre_color_val');
    if (cVal) cVal.textContent = _cadreColor;
    buildCadreSwatchRow();
    const cRow = document.getElementById('cadre_color_row');
    if (cRow) cRow.style.display = (cadreType === 'custom') ? 'flex' : 'none';
    const cadreOpacity = parseFloat(d.cadreOpacity || 0.85) * 100;
    document.getElementById('cadre_opacity').value = cadreOpacity;
    document.getElementById('cadre_opacity_val').textContent = Math.round(cadreOpacity) + '%';
    const cadreBlur = d.cadreBlur || 32;
    document.getElementById('cadre_blur').value = cadreBlur;
    document.getElementById('cadre_blur_val').textContent = cadreBlur;
    const cadreRadius = d.cadrecornerRadius || 24;
    document.getElementById('cadre_radius').value = cadreRadius;
    document.getElementById('cadre_radius_val').textContent = cadreRadius + 'px';
    const cadreBorder = d.cadreBorderWidth || 1.5;
    document.getElementById('cadre_border').value = cadreBorder;
    document.getElementById('cadre_border_val').textContent = cadreBorder + 'px';
    const cadrePadding = d.cadrePadding || 32;
    document.getElementById('cadre_padding').value = cadrePadding;
    document.getElementById('cadre_padding_val').textContent = cadrePadding + 'px';

    // Unified Font section — hydrate fonts, sizes, and colors per element
    _fontValues = {
      numberFont: d.numberFont || 'DM Mono',
      categoryFont: d.categoryFont || d.numberFont || 'DM Mono',
      facilityFont: d.facilityFont || d.numberFont || 'DM Mono',
      bannerFont: d.bannerFont || d.numberFont || 'DM Mono',
      nowServingFont: d.nowServingFont || d.numberFont || 'DM Mono',
      numberFontSize: parseInt(d.numberFontSize) || 96,
      categoryFontSize: parseInt(d.categoryFontSize) || 34,
      facilityFontSize: parseInt(d.facilityFontSize) || 24,
      bannerFontSize: parseInt(d.bannerFontSize) || 24,
      nowServingFontSize: parseInt(d.nowServingFontSize) || 16,
      numberColor: d.numberColor || '#FFB84D',
      categoryColor: d.categoryColor || '#FFB84D',
      facilityColor: d.facilityColor || '#FFB84D',
      bannerColor: d.bannerColor || '#FFFFFF',
      nowServingColor: d.nowServingColor || '#FFFFFF'
    };

    // Apply fonts and colors to preview elements
    document.getElementById('prev_num').style.fontFamily = _fontValues.numberFont;
    document.getElementById('prev_num').style.fontSize = _fontValues.numberFontSize + 'px';
    document.getElementById('prev_num').style.color = _fontValues.numberColor;

    document.getElementById('prev_cat').style.fontFamily = _fontValues.categoryFont;
    document.getElementById('prev_cat').style.fontSize = _fontValues.categoryFontSize + 'px';
    document.getElementById('prev_cat').style.color = _fontValues.categoryColor;

    document.getElementById('prev_fac').style.fontFamily = _fontValues.facilityFont;
    document.getElementById('prev_fac').style.fontSize = _fontValues.facilityFontSize + 'px';
    document.getElementById('prev_fac').style.color = _fontValues.facilityColor;

    document.getElementById('prev_label').style.fontFamily = _fontValues.nowServingFont;
    document.getElementById('prev_label').style.fontSize = _fontValues.nowServingFontSize + 'px';
    document.getElementById('prev_label').style.color = _fontValues.nowServingColor;

    // Initialize the unified Font section with Number as default
    try {
      setFontElement('number');
    } catch(e) {
      console.error('Error initializing Font section:', e);
    }

    // Logo size slider — init from persisted value
    _curLs = parseInt(d.logoSize)||48;
    _curLs = Math.max(24, Math.min(120, _curLs));
    document.getElementById('ls_slider').value    = _curLs;
    document.getElementById('ls_val').textContent = _curLs+'px';

  } catch(e) { 
    console.error('init error', e); 
    // Hide loading overlay even on error
    const overlay = document.getElementById('loading-overlay');
    if (overlay) overlay.classList.add('hide');
    // Show error message in app
    const app = document.getElementById('app');
    if (app) {
      app.innerHTML = `
        <div style="padding: 40px 20px; text-align: center;">
          <h2 style="color: var(--danger); margin-bottom: 16px;">Connection Error</h2>
          <p style="color: var(--text-secondary); margin-bottom: 24px;">
            Unable to connect to the CandyBar server. Please make sure the application is running.
          </p>
          <button onclick="location.reload()" style="
            background: var(--primary);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
          ">Retry</button>
        </div>
      `;
    }
  }

  // Restore admin panel language from localStorage
  try {
    const saved = localStorage.getItem('cbAdminLang');
    if (saved && ['en','fr','ar'].includes(saved)) setAdminLang(saved);
  } catch(e) {}

  // Auto-fill PIN input if saved
  try {
    const savedPin = localStorage.getItem('cbAdminPin');
    if (savedPin) {
      const pinInput = document.getElementById('new_pin');
      if (pinInput) pinInput.value = savedPin;
    }
  } catch(e) {}

  // Only load stats and fonts if server connection succeeded
  try {
    loadFonts();
  } catch(e) {
    console.warn('Stats/fonts loading skipped due to server error');
  }

  // Hide loading overlay after everything is initialized
  const overlay = document.getElementById('loading-overlay');
  if (overlay) overlay.classList.add('hide');
}

let _ws;
let _wsReady = false;
let _statsInterval = null;
let _activeTab = 'home';

function setHealthPolling(active) {
  if (active) {
    if (_statsInterval === null) {
      loadStats();
      _statsInterval = setInterval(loadStats, 30000);
    }
  } else if (_statsInterval !== null) {
    clearInterval(_statsInterval);
    _statsInterval = null;
  }
}

let _wsRetryDelay = 1000;
function connectWS() {
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  _ws = new WebSocket(`${proto}://${location.host}/ws`);
  _ws.onopen = () => {
    _wsReady = true;
    _wsRetryDelay = 1000;
    console.log('[ws] Connected');
    updateLockState();
  };
  _ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === 'state_patch') applyStatePatch(msg.key, msg.value);
      else if (msg.type === 'publish_rejected') {
        console.warn('[ws] server rejected publish for', msg.key, msg.error);
        if (typeof toast === 'function') toast(`Invalid value rejected for ${msg.key}`, 'error');
      }
    } catch (e) { console.warn('[ws] parse error', e); }
  };
  _ws.onclose = () => {
    _wsReady = false;
    updateLockState();
    setTimeout(connectWS, _wsRetryDelay); // auto-reconnect, never give up
    _wsRetryDelay = Math.min(_wsRetryDelay * 1.5, 15000);
  };
  _ws.onerror = () => {
    _wsReady = false;
    _ws.close();
  };
}

let _connStatusPollInterval = null;
async function refreshConnectionStatus() {
  try {
    const r = await fetch('/api/state');
    if (!r.ok) throw new Error(`Server returned ${r.status}`);
    const d = await r.json();
    const connDot = document.getElementById('dot');
    const connLbl = document.getElementById('conn_lbl');
    // Store MQTT status for System Health tab
    _mqttConnected = !!d.mqttConnected;
    _mqttStatus = (d.mqttStatus || 'Connected').toString();
    // Header shows WebSocket status only
    if (connDot && connLbl) {
      if (_wsReady) {
        connDot.classList.remove('off');
        connDot.classList.add('on');
        connLbl.textContent = 'Connected';
      } else {
        connDot.classList.remove('on');
        connDot.classList.add('off');
        connLbl.textContent = 'Connecting...';
      }
    }
  } catch (e) {
    _mqttConnected = false;
    _mqttStatus = 'Error';
    const connDot = document.getElementById('dot');
    const connLbl = document.getElementById('conn_lbl');
    if (connDot) { connDot.classList.remove('on'); connDot.classList.add('off'); }
    if (connLbl) connLbl.textContent = 'Server unreachable';
  }
  updateLockState();
}
function startConnectionStatusPolling() {
  if (_connStatusPollInterval !== null) return;
  refreshConnectionStatus();
  _connStatusPollInterval = setInterval(refreshConnectionStatus, 5000);
}
function applyStatePatch(key, value) {
  if (key === 'audioPlaying') {
    window.audioPlaying = (value === true || value === 'true');
    updateAudioPlaybackUI();
  }
  if (key === 'currentNumber') {
    liveCurrentNumber = value;
    document.getElementById('num_input').value = parseInt(value)||0;
    document.getElementById('queueNumberDisplay').textContent = String(parseInt(value)||0).padStart(2,'0');
  }
  // Extend this for any other key you want reflected live in the admin UI
  // (bannerText, connection dot, etc.) without a manual reload.
}

document.addEventListener('DOMContentLoaded', () => {
  // Add Enter key listener for PIN input
  const pinInput = document.getElementById('pin_entry');
  if (pinInput) {
    pinInput.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') {
        verifyPin();
      }
    });
  }

  const categorySheet = document.getElementById('categorySheet');
  if (categorySheet) {
    categorySheet.addEventListener('click', (e) => {
      if (e.target === categorySheet) closeCategorySheet();
    });
  }

  const createCategorySheet = document.getElementById('createCategorySheet');
  if (createCategorySheet) {
    createCategorySheet.addEventListener('click', (e) => {
      if (e.target === createCategorySheet) closeCreateCategory();
    });
  }

  init();
  connectWS();
  startConnectionStatusPolling();
});

/* ===== SECTION =====
   BACKGROUND ADJUSTMENT MODAL
===== SECTION ===== */
function openBgAdjustModal() {
  console.log('Opening background adjustment modal');

  const modal = document.getElementById('bg_adjust_modal');
  const preview = document.getElementById('bg_preview_image');

  if (!modal || !preview) {
    console.error('Modal or preview element not found');
    return;
  }

  // Get current background from preview
  const currentBg = document.getElementById('prev_bg');
  if (!currentBg) {
    console.error('prev_bg element not found');
    return;
  }

  const bgImage = currentBg.style.backgroundImage || currentBg.style.background;
  console.log('Current background:', bgImage);

  // Set preview background
  preview.style.backgroundImage = bgImage;

  // Reset transform to current saved values or defaults
  bgTransform = { scale: bgScale || 1, x: bgOffsetX || 0, y: bgOffsetY || 0, rotation: 0 };
  updateBgPreview();

  // Show modal
  modal.style.display = 'flex';
  console.log('Modal displayed');

  // Attach gesture handlers
  attachBgGestureHandlers();
}

function closeBgAdjustModal() {
  const modal = document.getElementById('bg_adjust_modal');
  modal.style.display = 'none';
  detachBgGestureHandlers();
}

function updateBgPreview() {
  const preview = document.getElementById('bg_preview_image');
  preview.style.transform = `translate(${bgTransform.x}px, ${bgTransform.y}px) scale(${bgTransform.scale}) rotate(${bgTransform.rotation}deg)`;
}

function resetBgTransform() {
  bgTransform = { scale: 1, x: 0, y: 0, rotation: 0 };
  updateBgPreview();
}

function applyBgTransform() {
  // Save transform values
  bgScale = bgTransform.scale;
  bgOffsetX = bgTransform.x;
  bgOffsetY = bgTransform.y;

  // Send to backend with correct property names
  pubBatch([
    ['backgroundScale', bgScale],
    ['backgroundOffsetX', bgOffsetX],
    ['backgroundOffsetY', bgOffsetY]
  ]);

  // Update the main preview
  updateBgPreviewTransform();

  // Close modal
  closeBgAdjustModal();
}

function attachBgGestureHandlers() {
  const container = document.getElementById('bg_preview_container');

  // Mouse/Touch drag
  container.addEventListener('mousedown', onBgDragStart);
  container.addEventListener('touchstart', onBgDragStart, { passive: false });

  // Touch pinch and rotate
  container.addEventListener('touchmove', onBgTouchMove, { passive: false });
  container.addEventListener('touchend', onBgTouchEnd);

  // Mouse wheel for zoom (Ctrl+wheel for rotation)
  container.addEventListener('wheel', onBgWheel, { passive: false });
}

function detachBgGestureHandlers() {
  const container = document.getElementById('bg_preview_container');
  container.removeEventListener('mousedown', onBgDragStart);
  container.removeEventListener('touchstart', onBgDragStart);
  container.removeEventListener('touchmove', onBgTouchMove);
  container.removeEventListener('touchend', onBgTouchEnd);
  container.removeEventListener('wheel', onBgWheel);
}

function onBgDragStart(e) {
  e.preventDefault();
  const point = e.touches ? e.touches[0] : e;
  bgAdjustState.isDragging = true;
  bgAdjustState.startX = point.clientX;
  bgAdjustState.startY = point.clientY;
  bgAdjustState.initialX = bgTransform.x;
  bgAdjustState.initialY = bgTransform.y;

  document.addEventListener('mousemove', onBgDragMove);
  document.addEventListener('mouseup', onBgDragEnd);
  document.addEventListener('touchmove', onBgDragMove, { passive: false });
  document.addEventListener('touchend', onBgDragEnd);
}

function onBgDragMove(e) {
  if (!bgAdjustState.isDragging) return;
  e.preventDefault();

  const point = e.touches ? e.touches[0] : e;
  const deltaX = point.clientX - bgAdjustState.startX;
  const deltaY = point.clientY - bgAdjustState.startY;

  bgTransform.x = bgAdjustState.initialX + deltaX;
  bgTransform.y = bgAdjustState.initialY + deltaY;
  updateBgPreview();
}

function onBgDragEnd() {
  bgAdjustState.isDragging = false;
  document.removeEventListener('mousemove', onBgDragMove);
  document.removeEventListener('mouseup', onBgDragEnd);
  document.removeEventListener('touchmove', onBgDragMove);
  document.removeEventListener('touchend', onBgDragEnd);
}

function onBgTouchMove(e) {
  if (e.touches.length === 2) {
    e.preventDefault();
    const touch1 = e.touches[0];
    const touch2 = e.touches[1];

    // Calculate distance for pinch zoom
    const dist = Math.hypot(touch2.clientX - touch1.clientX, touch2.clientY - touch1.clientY);

    if (!bgPinchState.isPinching) {
      bgPinchState.isPinching = true;
      bgPinchState.initialDist = dist;
      bgPinchState.initialScale = bgTransform.scale;
    }

    const scaleChange = dist / bgPinchState.initialDist;
    bgTransform.scale = Math.max(0.5, Math.min(3, bgPinchState.initialScale * scaleChange));

    // Calculate angle for rotation
    const angle = Math.atan2(touch2.clientY - touch1.clientY, touch2.clientX - touch1.clientX) * (180 / Math.PI);

    if (!bgRotateState.isRotating) {
      bgRotateState.isRotating = true;
      bgRotateState.initialAngle = angle;
      bgRotateState.initialRotation = bgTransform.rotation;
    }

    const angleChange = angle - bgRotateState.initialAngle;
    bgTransform.rotation = bgRotateState.initialRotation + angleChange;

    updateBgPreview();
  }
}

function onBgTouchEnd(e) {
  if (e.touches.length < 2) {
    bgPinchState.isPinching = false;
    bgRotateState.isRotating = false;
  }
}

function onBgWheel(e) {
  e.preventDefault();

  if (e.ctrlKey) {
    // Ctrl + wheel = rotation
    const rotationChange = e.deltaY * 0.1;
    bgTransform.rotation += rotationChange;
  } else {
    // Regular wheel = zoom
    const zoomChange = e.deltaY * -0.001;
    bgTransform.scale = Math.max(0.5, Math.min(3, bgTransform.scale + zoomChange));
  }

  updateBgPreview();
}
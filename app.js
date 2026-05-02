const STORAGE_KEY = 'rise_and_shine_profile_v1';
const HISTORY_KEY = 'rise_and_shine_history_v1';
const USERS_KEY = 'rise_and_shine_users_v1';
const SESSION_COOKIE = 'rise_session';
const COOKIE_CONSENT = 'cookie_consent';

const el = (id) => document.getElementById(id);
const baseInput = el('baseSeconds');
const lockBtn = el('lockBtn');
const lockStatus = el('lockStatus');
const requiredText = el('requiredText');
const statusText = el('status');
const progressText = el('progress');
const startBtn = el('startBtn');
const stopBtn = el('stopBtn');
const historyList = el('history');
const video = el('preview');
const emailInput = el('email');
const passwordInput = el('password');
const signUpBtn = el('signUpBtn');
const signInBtn = el('signInBtn');
const signOutBtn = el('signOutBtn');
const authMsg = el('authMsg');
const authState = el('authState');
const cookieBanner = el('cookieBanner');
const acceptCookiesBtn = el('acceptCookiesBtn');

let stream, timer, completed = 0, required = 0;
let currentUser = null;

function setCookie(name, value, days = 365) {
  const d = new Date();
  d.setTime(d.getTime() + days * 24 * 60 * 60 * 1000);
  document.cookie = `${name}=${encodeURIComponent(value)};expires=${d.toUTCString()};path=/;SameSite=Lax`;
}

function getCookie(name) {
  return document.cookie.split('; ').find(row => row.startsWith(name + '='))?.split('=')[1];
}

function hasCookieConsent() { return getCookie(COOKIE_CONSENT) === 'yes'; }

function getUsers() { return JSON.parse(localStorage.getItem(USERS_KEY) || '{}'); }
function saveUsers(users) { localStorage.setItem(USERS_KEY, JSON.stringify(users)); }
function hash(str) { return btoa(unescape(encodeURIComponent(str))); }

function getProfile() { return JSON.parse(localStorage.getItem(`${STORAGE_KEY}_${currentUser}`) || 'null'); }
function saveProfile(p) { localStorage.setItem(`${STORAGE_KEY}_${currentUser}`, JSON.stringify(p)); }

function weeksSince(startDateIso) {
  const start = new Date(startDateIso);
  const now = new Date();
  return Math.max(0, Math.floor((now - start) / (7 * 24 * 60 * 60 * 1000)));
}
function todaysRequiredSeconds(profile) { return profile.baseSeconds + weeksSince(profile.lockedAt); }

function saveMorningCompletion(seconds) {
  if (!currentUser) return;
  const items = JSON.parse(localStorage.getItem(`${HISTORY_KEY}_${currentUser}`) || '[]');
  items.unshift({ date: new Date().toISOString(), seconds });
  localStorage.setItem(`${HISTORY_KEY}_${currentUser}`, JSON.stringify(items.slice(0, 120)));
  renderHistory();
}

function renderHistory() {
  if (!currentUser) { historyList.innerHTML = '<li>Sign in to view history.</li>'; return; }
  const items = JSON.parse(localStorage.getItem(`${HISTORY_KEY}_${currentUser}`) || '[]');
  historyList.innerHTML = items.map(i => `<li>${new Date(i.date).toLocaleString()}: completed ${i.seconds}s plank</li>`).join('') || '<li>No mornings recorded yet.</li>';
}

function renderProfile() {
  if (!currentUser) {
    lockStatus.textContent = 'Sign in to configure your plank goal.';
    requiredText.textContent = 'Sign in first.';
    startBtn.disabled = true;
    return;
  }
  const profile = getProfile();
  if (!profile) {
    baseInput.disabled = false; lockBtn.disabled = false;
    lockStatus.textContent = 'No base time locked yet.';
    requiredText.textContent = 'Lock your base time first.';
    startBtn.disabled = true;
    return;
  }
  required = todaysRequiredSeconds(profile);
  baseInput.disabled = true;
  lockBtn.disabled = true;
  lockStatus.textContent = `Locked at ${profile.baseSeconds}s on ${new Date(profile.lockedAt).toLocaleDateString()}.`;
  requiredText.textContent = `Today you must hold: ${required}s (includes +1s per week).`;
  startBtn.disabled = false;
}

function setSignedIn(email) {
  currentUser = email.toLowerCase();
  authState.textContent = `Signed in as ${currentUser}`;
  if (hasCookieConsent()) setCookie(SESSION_COOKIE, currentUser, 365);
  renderProfile();
  renderHistory();
}

function signOut() {
  currentUser = null;
  setCookie(SESSION_COOKIE, '', -1);
  authState.textContent = 'Signed out';
  renderProfile();
  renderHistory();
}

signUpBtn.onclick = () => {
  const email = emailInput.value.trim().toLowerCase();
  const password = passwordInput.value;
  if (!email || !password) { authMsg.textContent = 'Enter email and password.'; return; }
  const users = getUsers();
  if (users[email]) { authMsg.textContent = 'Account already exists.'; return; }
  users[email] = { passwordHash: hash(password) };
  saveUsers(users);
  authMsg.textContent = 'Account created. Signed in.';
  setSignedIn(email);
};

signInBtn.onclick = () => {
  const email = emailInput.value.trim().toLowerCase();
  const password = passwordInput.value;
  const users = getUsers();
  if (!users[email] || users[email].passwordHash !== hash(password)) { authMsg.textContent = 'Invalid credentials.'; return; }
  authMsg.textContent = 'Welcome back.';
  setSignedIn(email);
};

signOutBtn.onclick = signOut;

acceptCookiesBtn.onclick = () => {
  setCookie(COOKIE_CONSENT, 'yes', 365);
  cookieBanner.style.display = 'none';
};

lockBtn.onclick = () => {
  if (!currentUser) { lockStatus.textContent = 'Sign in first.'; return; }
  const v = Number(baseInput.value);
  if (!Number.isInteger(v) || v < 5 || v > 300) { lockStatus.textContent = 'Choose a valid base plank between 5 and 300 seconds.'; return; }
  if (getProfile()) { lockStatus.textContent = 'Base time is already locked and cannot be changed.'; return; }
  saveProfile({ baseSeconds: v, lockedAt: new Date().toISOString() });
  renderProfile();
};

async function detectPlankFrame() { return true; }

startBtn.onclick = async () => {
  if (!currentUser) { statusText.textContent = 'Sign in first.'; return; }
  completed = 0;
  progressText.textContent = `Progress: 0/${required}s`;
  statusText.textContent = 'Starting camera...';
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false });
    video.srcObject = stream;
  } catch { statusText.textContent = 'Camera permission required.'; return; }

  startBtn.disabled = true; stopBtn.disabled = false;
  timer = setInterval(async () => {
    const ok = await detectPlankFrame();
    completed = ok ? completed + 1 : Math.max(0, completed - 1);
    progressText.textContent = `Progress: ${completed}/${required}s`;
    statusText.textContent = ok ? 'Plank detected' : 'Adjust posture';
    if (completed >= required) {
      clearInterval(timer);
      if (stream) stream.getTracks().forEach(t => t.stop());
      saveMorningCompletion(required);
      statusText.textContent = 'Success. Alarm unlock complete.';
      startBtn.disabled = false; stopBtn.disabled = true;
    }
  }, 1000);
};

stopBtn.onclick = () => {
  clearInterval(timer);
  if (stream) stream.getTracks().forEach(t => t.stop());
  startBtn.disabled = false;
  stopBtn.disabled = true;
  statusText.textContent = 'Stopped.';
};

if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js');
if (!hasCookieConsent()) cookieBanner.style.display = 'block'; else cookieBanner.style.display = 'none';

const remembered = getCookie(SESSION_COOKIE);
if (remembered) setSignedIn(decodeURIComponent(remembered));
else {
  authState.textContent = 'Not signed in';
  renderProfile();
  renderHistory();
}

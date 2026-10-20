const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);
let token = localStorage.getItem('token') || '';
let currentStudent = null;

async function api(path, opts = {}) {
  const res = await fetch(path, {
    ...opts,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: 'Bearer ' + token } : {}),
      ...(opts.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Error de red');
  return data;
}

// ---------- login ----------
function showPanel(on) {
  $('#view-login').classList.toggle('hidden', on);
  $('#view-panel').classList.toggle('hidden', !on);
  $('#btn-logout').classList.toggle('hidden', !on);
}

$('#btn-login').addEventListener('click', async () => {
  $('#login-msg').textContent = '';
  try {
    const data = await api('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email: $('#login-email').value, password: $('#login-password').value }),
    });
    if (data.user.role !== 'docente') throw new Error('Esa cuenta no es de docente');
    token = data.token;
    localStorage.setItem('token', token);
    showPanel(true);
    loadStudents();
  } catch (e) {
    $('#login-msg').textContent = e.message;
  }
});

$('#btn-logout').addEventListener('click', () => {
  token = '';
  localStorage.removeItem('token');
  showPanel(false);
});

// ---------- tabs ----------
$$('.tab').forEach((t) =>
  t.addEventListener('click', () => {
    $$('.tab').forEach((x) => x.classList.remove('active'));
    t.classList.add('active');
    $('#tab-students').classList.toggle('hidden', t.dataset.tab !== 'students');
    $('#tab-qr').classList.toggle('hidden', t.dataset.tab !== 'qr');
  })
);

// ---------- alumnos ----------
async function loadStudents() {
  const students = await api('/api/admin/students');
  const tbody = $('#students-table tbody');
  tbody.innerHTML = '';
  $('#students-empty').classList.toggle('hidden', students.length > 0);
  students.forEach((s) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${esc(s.name)}</td><td>${esc(s.email)}</td><td>${(s.created_at || '').slice(0, 10)}</td>
      <td><button class="btn small">Ver datos</button></td>`;
    tr.querySelector('button').addEventListener('click', () => openStudent(s));
    tbody.appendChild(tr);
  });
}

function esc(s) {
  return String(s).replace(/[<>&"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' }[c]));
}

async function openStudent(s) {
  currentStudent = s;
  $('#student-detail').classList.remove('hidden');
  $('#student-name').textContent = `${s.name} (${s.email})`;
  await loadStudentData();
  $('#student-detail').scrollIntoView({ behavior: 'smooth' });
}

$('#btn-back').addEventListener('click', () => {
  $('#student-detail').classList.add('hidden');
  currentStudent = null;
});

async function loadStudentData() {
  if (!currentStudent) return;
  const data = await api('/api/admin/students/' + currentStudent.id);
  renderAttendance(data.attendance);
  renderGrades('#act-table', data.activities, 'activities');
  renderGrades('#exam-table', data.exams, 'exams');
}

function renderAttendance(rows) {
  const tbody = $('#att-table tbody');
  tbody.innerHTML = '';
  rows.forEach((r) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${r.date}</td><td><span class="badge ${r.status}">${r.status}</span></td><td>${esc(r.note)}</td>
      <td><button class="btn danger small">✕</button></td>`;
    tr.querySelector('button').addEventListener('click', async () => {
      await api(`/api/admin/attendance/${r.id}`, { method: 'DELETE' });
      loadStudentData();
    });
    tbody.appendChild(tr);
  });
}

function renderGrades(sel, rows, table) {
  const tbody = document.querySelector(sel + ' tbody');
  tbody.innerHTML = '';
  rows.forEach((r) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${esc(r.name)}</td><td>${r.score}/${r.max_score}</td><td>${r.max_score}</td><td>${r.date}</td><td>${esc(r.note)}</td>
      <td><button class="btn danger small">✕</button></td>`;
    tr.querySelector('button').addEventListener('click', async () => {
      await api(`/api/admin/${table}/${r.id}`, { method: 'DELETE' });
      loadStudentData();
    });
    tbody.appendChild(tr);
  });
}

$('#att-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  await api(`/api/admin/students/${currentStudent.id}/attendance`, {
    method: 'POST',
    body: JSON.stringify({ date: $('#att-date').value, status: $('#att-status').value, note: $('#att-note').value }),
  });
  $('#att-note').value = '';
  loadStudentData();
});

$('#act-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  await api(`/api/admin/students/${currentStudent.id}/activities`, {
    method: 'POST',
    body: JSON.stringify({
      name: $('#act-name').value, score: $('#act-score').value, max_score: $('#act-max').value,
      date: $('#act-date').value, note: $('#act-note').value,
    }),
  });
  e.target.reset();
  $('#act-max').value = 20;
  loadStudentData();
});

$('#exam-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  await api(`/api/admin/students/${currentStudent.id}/exams`, {
    method: 'POST',
    body: JSON.stringify({
      name: $('#exam-name').value, score: $('#exam-score').value, max_score: $('#exam-max').value,
      date: $('#exam-date').value, note: $('#exam-note').value,
    }),
  });
  e.target.reset();
  $('#exam-max').value = 20;
  loadStudentData();
});

// ---------- QR ----------
$('#btn-qr').addEventListener('click', async () => {
  const data = await api('/api/qr', {
    method: 'POST',
    body: JSON.stringify({ ssid: $('#qr-ssid').value, password: $('#qr-pass').value }),
  });
  $('#qr-img').src = data.png;
  $('#qr-url').textContent = data.serverUrl;
  $('#qr-result').classList.remove('hidden');
});

// ---------- init ----------
(async () => {
  try {
    const net = await api('/api/network');
    $('#netinfo').textContent = 'Servidor: ' + net.url;
  } catch {}
  if (token) {
    try {
      const me = await api('/api/me');
      if (me.user.role === 'docente') {
        showPanel(true);
        loadStudents();
        return;
      }
    } catch {}
    token = '';
    localStorage.removeItem('token');
  }
  showPanel(false);
})();

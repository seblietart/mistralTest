"use strict";

const STORAGE_ITEMS = "monbudget_items_v1";
const STORAGE_UNPLANNED = "monbudget_unplanned_v1";

const FREQUENCIES = {
  monthly: { label: "Mensuelle", timesPerYear: 12, monthsPerCharge: 1 },
  everyThreeMonths: { label: "Trimestrielle", timesPerYear: 4, monthsPerCharge: 3 },
  everySixMonths: { label: "Semestrielle", timesPerYear: 2, monthsPerCharge: 6 },
  yearly: { label: "Annuelle", timesPerYear: 1, monthsPerCharge: 12 }
};

const money = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" }).format.bind(null);

const view = document.getElementById("view");
const dlg = document.getElementById("form-dialog");
const form = document.getElementById("item-form");

let items = load(STORAGE_ITEMS, []);
let unplannedBudget = load(STORAGE_UNPLANNED, 100);
let currentTab = "month";
let editingId = null;

function load(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw === null ? fallback : JSON.parse(raw);
  } catch {
    return fallback;
  }
}

function save(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
  }
}

function persist() {
  save(STORAGE_ITEMS, items);
  save(STORAGE_UNPLANNED, unplannedBudget);
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = String(text);
  return div.innerHTML;
}

function uid() {
  return crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2);
}

function monthIndexOf(date) {
  return date.getFullYear() * 12 + date.getMonth();
}

function monthStart(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function nextMonthStart(date) {
  return date.getMonth() === 11
    ? new Date(date.getFullYear() + 1, 0, 1)
    : new Date(date.getFullYear(), date.getMonth() + 1, 1);
}

function monthDays(date) {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
}

function monthName(date) {
  return date.toLocaleDateString("fr-FR", { month: "long", year: "numeric" });
}

function monthlyEquivalent(item) {
  return item.isCredit ? item.amount : item.amount * FREQUENCIES[item.frequency].timesPerYear / 12;
}

function chargesIn(item, monthAnchor) {
  if (!item.active) return false;
  const m = monthIndexOf(monthAnchor);
  const anchor = monthIndexOf(new Date(item.anchorDate));
  if (item.isCredit) {
    const first = creditFirstChargeMonthIndex(item);
    return m >= first && (m - first) < Math.max(item.installments || 0, 0);
  }
  if (item.frequency === "monthly") return true;
  if (m < anchor) return false;
  return (m - anchor) % FREQUENCIES[item.frequency].monthsPerCharge === 0;
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function creditFirstChargeMonthIndex(item) {
  const anchor = new Date(item.anchorDate);
  const anchorMonth = monthIndexOf(anchor);
  const occurrenceInAnchorMonth = new Date(anchor.getFullYear(), anchor.getMonth(), Math.min(item.day || 1, 28));
  return occurrenceInAnchorMonth >= startOfDay(anchor) ? anchorMonth : anchorMonth + 1;
}

function monthFromIndex(index) {
  return new Date(Math.floor(index / 12), index % 12, 1);
}

function creditPaidCount(item, reference = new Date()) {
  const today = startOfDay(reference);
  const anchorDay = startOfDay(new Date(item.anchorDate));
  let paid = 0;
  let cursor = monthFromIndex(creditFirstChargeMonthIndex(item));
  while (true) {
    const occurrence = new Date(cursor.getFullYear(), cursor.getMonth(), Math.min(item.day || 1, 28));
    if (occurrence >= today) break;
    if (occurrence > anchorDay) paid += 1;
    cursor = nextMonthStart(cursor);
  }
  return paid;
}

function creditRemaining(item, reference = new Date()) {
  if (!item.isCredit) return 0;
  return Math.max((item.installments || 0) - creditPaidCount(item, reference), 0);
}

function creditEndMonth(item) {
  const first = creditFirstChargeMonthIndex(item);
  return monthFromIndex(first + Math.max(item.installments, 1) - 1);
}

function monthlyCharges(list, monthAnchor) {
  return list.filter(i => i.kind === "expense" && i.active && chargesIn(i, monthAnchor));
}

function monthlyTotal(list, kind, reference = new Date()) {
  return list
    .filter(i => i.kind === kind && i.active && !(i.isCredit && creditRemaining(i, reference) <= 0))
    .reduce((sum, i) => sum + monthlyEquivalent(i), 0);
}

function chargeTotal(list) {
  return list.reduce((sum, i) => sum + i.amount, 0);
}

function creditShortMeta(item) {
  const remaining = creditRemaining(item);
  if (remaining <= 0) return "";
  const plural = remaining > 1 ? "s" : "";
  return ` · ${remaining} échéance${plural} restante${plural} · fin ${monthName(creditEndMonth(item))}`;
}

function chargeRow(item) {
  const credit = item.isCredit ? creditShortMeta(item) : "";
  return `<div class="row small"><span>${escapeHtml(item.name)}</span><span class="muted">le ${item.day} · ${money(item.amount)}${escapeHtml(credit)}</span></div>`;
}

function itemMeta(item) {
  if (item.isCredit) {
    const remaining = creditRemaining(item);
    if (remaining <= 0) return `Crédit · terminé`;
    const plural = remaining > 1 ? "s" : "";
    return `Crédit · le ${item.day} · ${remaining} échéance${plural} restante${plural} · fin ${monthName(creditEndMonth(item))}`;
  }
  const extra = item.frequency !== "monthly"
    ? ` · soit ${money(monthlyEquivalent(item))}/mois`
    : "";
  return `${FREQUENCIES[item.frequency].label} · le ${item.day}${extra}`;
}

function itemRow(item) {
  return `<div class="item${item.active ? "" : " inactive"}">
    <button type="button" class="item-main" data-action="edit" data-id="${item.id}">
      <span class="item-name">${escapeHtml(item.name)}</span>
      <span class="item-meta">${escapeHtml(itemMeta(item))}</span>
    </button>
    <div class="item-right">
      <span class="item-amount${item.kind === "income" ? " green" : ""}">${money(item.amount)}</span>
      <button type="button" class="item-delete" data-action="delete" data-id="${item.id}" aria-label="Supprimer ${escapeHtml(item.name)}">🗑️</button>
    </div>
  </div>`;
}

function renderMonth() {
  if (items.length === 0) {
    view.innerHTML = `<section class="card empty">
      <h2>Aucune donnée</h2>
      <p>Ajoutez vos revenus et vos charges récurrentes dans l'onglet Récurrents.</p>
      <button type="button" class="primary" data-action="go-items">Ajouter</button>
    </section>`;
    return;
  }

  const now = new Date();
  const cur = monthStart(now);
  const next = nextMonthStart(now);
  const today = now.getDate();
  const days = monthDays(cur);
  const nextDays = monthDays(next);
  const income = monthlyTotal(items, "income");
  const fixed = monthlyTotal(items, "expense");
  const leftover = income - fixed;
  const effective = Math.min(unplannedBudget, Math.max(0, leftover));
  const remaining = leftover - effective;
  const perDay = days > 0 ? remaining / days : 0;
  const monthCharges = monthlyCharges(items, cur);
  const alreadySum = chargeTotal(monthCharges.filter(i => i.day <= today));
  const upcoming = monthCharges.filter(i => i.day > today).sort((a, b) => a.day - b.day);
  const upcomingSum = chargeTotal(upcoming);
  const nextCharges = monthlyCharges(items, next).sort((a, b) => a.day - b.day);
  const nextSum = chargeTotal(nextCharges);
  const nextPerDay = nextDays > 0 ? (income - nextSum - effective) / nextDays : 0;
  const dayPct = Math.min(100, Math.round(today / Math.max(days, 1) * 100));
  const sliderMax = Math.max(50, Math.round(leftover > 0 ? leftover : 50));
  const projected = income - nextSum - effective;

  view.innerHTML = `
    <section class="card">
      <h2>Où j'en suis — ${monthName(cur)}</h2>
      <div class="row"><span>Revenus mensuels</span><strong class="green">${money(income)}</strong></div>
      <div class="row"><span>Charges fixes (lissées / mois)</span><strong class="red">${money(fixed)}</strong></div>
      <div class="row"><span>Déjà débité ce mois-ci</span><strong>${money(alreadySum)}</strong></div>
      <div class="row"><span>Encore à débiter ce mois</span><strong>${money(upcomingSum)}</strong></div>
      <div class="progress"><div class="progress-fill" style="width:${dayPct}%"></div></div>
      <p class="caption">Jour ${today} sur ${days}</p>
    </section>

    <section class="card">
      <h2>Dépenses non prévues</h2>
      <div class="row big"><span>Curseur imprévus</span><strong class="green" id="unplanned-value">${money(effective)}</strong></div>
      <input type="range" id="unplanned-slider" min="0" max="${sliderMax}" step="5" value="${Math.round(Math.min(unplannedBudget, sliderMax))}"${leftover <= 0 ? " disabled" : ""}>
      <div class="row"><span>Reste à vivre après imprévus</span><strong class="${remaining < 0 ? "red" : ""}">${money(remaining)}</strong></div>
      <div class="row"><span>Budget par jour</span><strong>${money(perDay)}</strong></div>
      ${leftover <= 0 ? '<p class="warning">⚠️ Vos charges dépassent vos revenus. Mettez le curseur à 0 ou revoyez vos charges.</p>' : ""}
    </section>

    <section class="card">
      <h2>Projection — ${monthName(next)}</h2>
      <div class="row"><span>Revenus prévus</span><strong class="green">${money(income)}</strong></div>
      <div class="row"><span>Charges prévues</span><strong class="red">${money(nextSum)}</strong></div>
      <div class="row"><span>Imprévus estimés</span><strong>${money(effective)}</strong></div>
      <div class="row"><span>Reste à vivre projeté</span><strong class="${projected < 0 ? "red" : ""}">${money(projected)}</strong></div>
      <div class="row"><span>Soit par jour</span><strong class="${nextPerDay < 0 ? "red" : ""}">${money(nextPerDay)}</strong></div>
      ${nextCharges.map(chargeRow).join("")}
    </section>`;
}

function downloadBackup() {
  const payload = {
    app: "MonBudget",
    version: 1,
    exportedAt: new Date().toISOString(),
    unplannedBudget,
    items
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `monbudget-sauvegarde-${new Date().toISOString().slice(0, 10)}.json`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function normalizeImportedItem(raw) {
  if (!raw || typeof raw !== "object") return null;
  const name = typeof raw.name === "string" ? raw.name.trim() : "";
  const amount = Number(raw.amount);
  const kind = raw.kind === "income" ? "income" : raw.kind === "expense" ? "expense" : null;
  if (!name || !Number.isFinite(amount) || amount <= 0 || !kind) return null;
  const isCredit = kind === "expense" && raw.isCredit === true;
  const installments = isCredit ? Math.max(1, Math.round(Number(raw.installments) || 12)) : 0;
  const nonMonthly = raw.frequency && raw.frequency !== "monthly" && (raw.frequency in FREQUENCIES) ? raw.frequency : "monthly";
  const frequency = isCredit ? "monthly" : nonMonthly;
  const isoDate = value => {
    const date = value ? new Date(value) : new Date();
    return Number.isNaN(date.getTime()) ? new Date().toISOString() : date.toISOString();
  };
  return {
    id: typeof raw.id === "string" && raw.id ? raw.id : uid(),
    name,
    amount,
    kind,
    frequency,
    day: Math.min(28, Math.max(1, Math.round(Number(raw.day) || 1))),
    active: raw.active === false ? false : true,
    isCredit,
    installments,
    anchorDate: isoDate(raw.anchorDate),
    createdAt: isoDate(raw.createdAt)
  };
}

function importBackup(text) {
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    return { status: "invalid" };
  }
  const rawItems = Array.isArray(data) ? data : data && Array.isArray(data.items) ? data.items : null;
  if (!rawItems) return { status: "invalid" };
  const parsed = rawItems.map(normalizeImportedItem).filter(Boolean);
  if (parsed.length !== rawItems.length) return { status: "invalid" };
  if (items.length > 0 && !confirm(`Remplacer vos ${items.length} élément(s) actuels par les ${parsed.length} élément(s) du fichier de sauvegarde ?`)) {
    return { status: "cancelled" };
  }
  items = parsed;
  if (data && typeof data === "object" && Number.isFinite(Number(data.unplannedBudget))) {
    unplannedBudget = Number(data.unplannedBudget);
  }
  return { status: "done", count: parsed.length };
}

function renderItems() {
  const incomes = items.filter(i => i.kind === "income");
  const expenses = items.filter(i => i.kind === "expense");
  view.innerHTML = `
    <section class="card">
      <div class="card-head"><h2>Revenus</h2><button type="button" class="chip" data-action="add" data-kind="income">+ Revenu</button></div>
      ${incomes.length ? incomes.map(itemRow).join("") : '<p class="caption">Aucun revenu.</p>'}
    </section>
    <section class="card">
      <div class="card-head"><h2>Charges fixes et récurrentes</h2><button type="button" class="chip" data-action="add" data-kind="expense">+ Dépense</button></div>
      ${expenses.length ? expenses.map(itemRow).join("") : '<p class="caption">Aucune dépense.</p>'}
    </section>
    <section class="card">
      <div class="card-head"><h2>Sauvegarde</h2></div>
      <p class="caption">Vos données restent enregistrées sur votre téléphone. Exportez régulièrement un fichier de sauvegarde ; vous pourrez le restaurer ici ou sur un autre appareil.</p>
      <div class="card-actions">
        <button type="button" class="chip" data-action="export-json">Exporter</button>
        <button type="button" class="chip" data-action="import-json">Restaurer</button>
      </div>
    </section>`;
}

function render() {
  if (currentTab === "month") {
    renderMonth();
  } else {
    renderItems();
  }
}

function setTab(tab) {
  currentTab = tab;
  document.getElementById("tab-month").classList.toggle("active", tab === "month");
  document.getElementById("tab-items").classList.toggle("active", tab === "items");
  render();
}

function parseAmount() {
  const value = parseFloat(document.getElementById("f-amount").value.replace(",", "."));
  return Number.isFinite(value) && value > 0 ? value : null;
}

function updateEquivalent() {
  const amount = parseAmount();
  const frequency = FREQUENCIES[document.getElementById("f-frequency").value];
  const equivalent = (amount ?? 0) * frequency.timesPerYear / 12;
  document.getElementById("f-equivalent").textContent = amount ? money(equivalent) : "—";
}

function toggleDaySelect() {
  const hidden = document.getElementById("f-frequency").value !== "monthly";
  document.getElementById("day-label").classList.toggle("hidden", hidden);
}

function updateFormVisibility() {
  const kind = document.getElementById("f-kind").value;
  const isCreditOption = kind === "expense" && document.getElementById("f-credit-type").value === "credit";
  document.getElementById("credit-type-label").classList.toggle("hidden", kind !== "expense");
  document.getElementById("installments-label").classList.toggle("hidden", !isCreditOption);
  document.getElementById("frequency-label").classList.toggle("hidden", isCreditOption);
  toggleDaySelect();
}

function openForm(kind, item) {
  editingId = item ? item.id : null;
  form.reset();
  document.getElementById("form-title").textContent = item ? "Modifier" : "Nouvel élément";
  document.getElementById("f-name").value = item ? item.name : "";
  document.getElementById("f-amount").value = item ? String(item.amount).replace(".", ",") : "";
  document.getElementById("f-kind").value = item ? item.kind : kind;
  document.getElementById("f-frequency").value = item ? item.frequency : "monthly";
  document.getElementById("f-credit-type").value = item && item.isCredit ? "credit" : "recurring";
  document.getElementById("f-installments").value = String(item && item.installments ? item.installments : 12);
  document.getElementById("f-day").value = String(item ? item.day : 1);
  document.getElementById("f-active").checked = item ? item.active : true;
  document.getElementById("active-label").classList.toggle("hidden", !item);
  updateFormVisibility();
  updateEquivalent();
  dlg.showModal();
}

function fillDaySelect() {
  document.getElementById("f-day").innerHTML = Array.from(
    { length: 28 },
    (_, index) => `<option value="${index + 1}">le ${index + 1}</option>`
  ).join("");
}

view.addEventListener("click", event => {
  const target = event.target.closest("[data-action]");
  if (!target) return;
  const action = target.dataset.action;
  if (action === "go-items") {
    setTab("items");
  } else if (action === "add") {
    openForm(target.dataset.kind, null);
  } else if (action === "edit") {
    const item = items.find(x => x.id === target.dataset.id);
    if (item) openForm(item.kind, item);
  } else if (action === "delete") {
    if (confirm("Supprimer cet élément ?")) {
      items = items.filter(x => x.id !== target.dataset.id);
      persist();
      render();
    }
  } else if (action === "export-json") {
    downloadBackup();
  } else if (action === "import-json") {
    document.getElementById("import-file").click();
  }
});

view.addEventListener("input", event => {
  if (event.target.id === "unplanned-slider") {
    unplannedBudget = Number(event.target.value);
    save(STORAGE_UNPLANNED, unplannedBudget);
    const label = document.getElementById("unplanned-value");
    if (label) label.textContent = money(unplannedBudget);
  }
});

view.addEventListener("change", event => {
  if (event.target.id === "unplanned-slider") {
    render();
  }
});

document.getElementById("tab-month").addEventListener("click", () => setTab("month"));
document.getElementById("tab-items").addEventListener("click", () => setTab("items"));
document.getElementById("f-cancel").addEventListener("click", () => dlg.close());
document.getElementById("f-frequency").addEventListener("change", () => {
  updateFormVisibility();
  updateEquivalent();
});
document.getElementById("f-amount").addEventListener("input", updateEquivalent);
document.getElementById("f-kind").addEventListener("change", updateFormVisibility);
document.getElementById("f-credit-type").addEventListener("change", updateFormVisibility);

form.addEventListener("submit", event => {
  event.preventDefault();
  const name = document.getElementById("f-name").value.trim();
  const amount = parseAmount();
  if (!name || !amount) return;
  const kind = document.getElementById("f-kind").value;
  const isCredit = kind === "expense" && document.getElementById("f-credit-type").value === "credit";
  const installments = isCredit
    ? Math.max(1, Math.round(Number(document.getElementById("f-installments").value) || 1))
    : 0;
  const frequency = isCredit ? "monthly" : document.getElementById("f-frequency").value;
  const day = Math.min(28, Math.max(1, Number(document.getElementById("f-day").value) || 1));
  const active = document.getElementById("f-active").checked;
  if (editingId) {
    const item = items.find(x => x.id === editingId);
    if (item) {
      const resetAnchor = isCredit && !(item.isCredit && installments === item.installments);
      Object.assign(item, {
        name,
        amount,
        kind,
        frequency,
        day,
        active,
        isCredit,
        installments,
        anchorDate: resetAnchor ? new Date().toISOString() : item.anchorDate
      });
    }
  } else {
    const now = new Date().toISOString();
    items.push({ id: uid(), name, amount, kind, frequency, day, active: true, isCredit, installments, anchorDate: now, createdAt: now });
  }
  persist();
  dlg.close();
  render();
});

document.getElementById("app-subtitle").textContent = monthName(new Date());
fillDaySelect();
render();

document.getElementById("import-file").addEventListener("change", event => {
  const file = event.target.files[0];
  event.target.value = "";
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    const result = importBackup(String(reader.result));
    if (result.status === "invalid") {
      alert("Fichier de sauvegarde invalide.");
    } else if (result.status === "done") {
      persist();
      render();
    }
  };
  reader.readAsText(file);
});

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js").catch(() => {});
  });
}

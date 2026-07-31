(function () {
  const pageMap = {
    Dashboard: "dashboard.html",
    Clients: "clients.html",
    Subscriptions: "subscriptions.html",
    Plans: "plans.html",
    "Audit Log": "audit-log.html",
    Settings: "settings.html",
    "Admin Profile": "admin-profile.html",
    Logout: "login.html",
  };

  const detailPages = [
    "client-detail.html",
    "client-events.html",
    "client-billing.html",
    "client-menu.html",
    "client-custom-menus.html",
    "client-employees.html",
    "client-reports.html",
    "client-audit.html",
  ];

  function normalize(text) {
    return (text || "").replace(/\s+/g, " ").trim();
  }

  function wireNavigation() {
    document.querySelectorAll("a").forEach((link) => {
      const label = normalize(link.textContent);
      const match = Object.keys(pageMap).find((key) => label === key || label.endsWith(` ${key}`));
      if (match) link.setAttribute("href", pageMap[match]);
    });
  }

  function syncActiveNavigation() {
    const fileName = location.pathname.split("/").pop() || "dashboard.html";
    const activeLabel =
      Object.keys(pageMap).find((key) => pageMap[key] === fileName) ||
      (fileName.startsWith("client-") ? "Clients" : null);
    if (!activeLabel) return;
    const activeClass =
      "flex items-center gap-3 px-6 py-3 text-primary border-l-4 border-primary bg-surface-container-high transition-all active:scale-[0.98] font-label-md text-label-md";
    const inactiveClass =
      "flex items-center gap-3 px-6 py-3 text-on-surface-variant hover:bg-surface-container-highest transition-colors font-label-md text-label-md";
    document.querySelectorAll("aside nav a").forEach((link) => {
      const label = normalize(link.textContent);
      const isActive = label === activeLabel || label.endsWith(` ${activeLabel}`);
      link.className = isActive ? activeClass : inactiveClass;
    });
  }

  function replaceSidebarBrandLogo() {
    const candidates = Array.from(document.querySelectorAll("aside .flex.items-center.gap-3"));
    const brand = candidates.find((node) => normalize(node.textContent).includes("CaterPro"));
    if (!brand) return;
    const iconBox = brand.querySelector(".w-8.h-8, .w-10.h-10");
    if (!iconBox) return;
    iconBox.className = "cp-brand-logo shrink-0";
    iconBox.innerHTML = '<img src="../assets/caterpro_logo.png" alt="CaterPro" class="w-full h-full object-contain" />';
  }

  function replaceSimpleSidebarTitle() {
    if (document.querySelector("aside .cp-brand-logo")) return;
    const title = document.querySelector("aside h1");
    if (!title || title.previousElementSibling?.classList?.contains("cp-brand-logo")) return;
    const wrapper = title.parentElement;
    if (!wrapper || wrapper.querySelector(".cp-brand-logo")) return;
    const logo = document.createElement("img");
    logo.src = "../assets/caterpro_logo.png";
    logo.alt = "CaterPro";
    logo.className = "cp-brand-logo mb-3";
    wrapper.prepend(logo);
  }

  function replaceLoginLogo() {
    if (document.querySelector("aside")) return;
    const loginHeading = Array.from(document.querySelectorAll("h1, h2")).find((node) =>
      normalize(node.textContent).includes("CaterPro")
    );
    if (!loginHeading) return;
    const nearby = loginHeading.parentElement;
    if (!nearby || nearby.querySelector(".cp-login-logo")) return;
    const logo = document.createElement("img");
    logo.src = "../assets/caterpro_logo.png";
    logo.alt = "CaterPro";
    logo.className = "cp-login-logo mx-auto mb-4";
    nearby.prepend(logo);
  }

  function removeDuplicateSidebarLogos() {
    const logos = Array.from(document.querySelectorAll("aside .cp-brand-logo"));
    logos.slice(1).forEach((logo) => logo.remove());
  }

  function wireClientDetailTabs() {
    const detailTargets = {
      "Client Details": "client-detail.html",
      Details: "client-detail.html",
      Overview: "client-detail.html",
      Events: "client-events.html",
      "Events & Orders": "client-events.html",
      "Orders & Menu": "client-events.html",
      "Quotations/Invoices": "client-billing.html",
      "Quotations & Invoices": "client-billing.html",
      Billing: "client-billing.html",
      Payments: "client-billing.html",
      "Menu Items": "client-menu.html",
      "Menus & Catalog": "client-menu.html",
      Employees: "client-employees.html",
      Reports: "client-reports.html",
      "Audit Activity": "client-audit.html",
    };
    document.querySelectorAll("a, button").forEach((node) => {
      const label = normalize(node.textContent);
      const match = Object.keys(detailTargets).find((key) => label === key || label.endsWith(` ${key}`));
      const target = match ? detailTargets[match] : null;
      if (!target) return;
      if (node.tagName.toLowerCase() === "a") {
        node.setAttribute("href", target);
      } else {
        node.addEventListener("click", () => {
          window.location.href = target;
        });
      }
    });
  }

  function goToPage(fileName) {
    window.location.href = fileName;
  }

  function wireLogin() {
    const form = document.querySelector("form");
    if (!form || location.pathname.split("/").pop() !== "login.html") return;
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const email = form.querySelector('input[type="email"], input[name="email"]')?.value || "admin@caterpro.in";
      const password = form.querySelector('input[type="password"], input[name="password"]')?.value || "password";
      const button = form.querySelector('button[type="submit"], button');
      if (button) button.disabled = true;
      try {
        const response = await fetch(`${apiBase()}/auth/login`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email, password }),
        });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(payload.message || "Unable to login");
        localStorage.setItem("caterpro.admin.token", payload.token);
        localStorage.setItem("caterpro.admin.user", JSON.stringify(payload.user || {}));
        goToPage("dashboard.html");
      } catch (error) {
        showAdminState(`Login failed: ${networkLoginMessage(error)}`);
      } finally {
        if (button) button.disabled = false;
      }
    });
  }

  function wireActionButtons() {
    document.querySelectorAll("button, a").forEach((node) => {
      const label = normalize(node.textContent);
      const iconText = normalize(node.querySelector(".material-symbols-outlined")?.textContent);
      const title = normalize(node.getAttribute("title") || node.getAttribute("aria-label") || "");

      if (location.pathname.split("/").pop() !== "login.html" && label.includes("Login")) {
        node.addEventListener("click", () => goToPage("dashboard.html"));
      }
      if (label.includes("Create User") || label.includes("Create Client")) {
        node.addEventListener("click", () => goToPage("client-detail.html"));
      }
      if (label.includes("Open Audit Log")) {
        node.addEventListener("click", () => goToPage("audit-log.html"));
      }
      if (
        iconText === "info" ||
        iconText === "visibility" ||
        title.includes("Info") ||
        title.includes("View")
      ) {
        node.addEventListener("click", () => goToPage("client-detail.html"));
      }
      if (iconText === "receipt_long" || iconText === "request_quote") {
        node.addEventListener("click", () => goToPage("client-billing.html"));
      }
      if (iconText === "event" || iconText === "calendar_month") {
        node.addEventListener("click", () => goToPage("client-events.html"));
      }
    });
  }

  function wireClientRows() {
    if (location.pathname.split("/").pop() !== "clients.html") return;
    document.querySelectorAll("tbody tr").forEach((row) => {
      row.style.cursor = "pointer";
      row.addEventListener("click", (event) => {
        if (event.target.closest("button, a, input, select")) return;
        goToPage("client-detail.html");
      });
    });
  }

  function wireDetailFallbacks() {
    if (!detailPages.includes(location.pathname.split("/").pop())) return;
    document.querySelectorAll("button, a").forEach((node) => {
      const label = normalize(node.textContent);
      if (label.includes("Invoices") || label.includes("Billing")) {
        node.addEventListener("click", () => goToPage("client-billing.html"));
      }
      if (label.includes("Events")) {
        node.addEventListener("click", () => goToPage("client-events.html"));
      }
      if (label.includes("Menu")) {
        node.addEventListener("click", () => goToPage("client-menu.html"));
      }
      if (label.includes("Employees")) {
        node.addEventListener("click", () => goToPage("client-employees.html"));
      }
      if (label.includes("Reports")) {
        node.addEventListener("click", () => goToPage("client-reports.html"));
      }
      if (label.includes("Audit")) {
        node.addEventListener("click", () => goToPage("client-audit.html"));
      }
      if (label.includes("Details") || label.includes("Overview")) {
        node.addEventListener("click", () => goToPage("client-detail.html"));
      }
    });
  }

  function apiBase() {
    const saved = localStorage.getItem("caterpro.admin.apiBase");
    if (saved) return saved.replace(/\/$/, "");
    if (location.pathname.startsWith("/admin/") || location.port === "8787") return `${location.origin}/api`;
    return "http://localhost:8787/api";
  }

  function networkLoginMessage(error) {
    const message = error?.message || "Unable to login";
    if (!message.toLowerCase().includes("fetch")) return message;
    return "API is not reachable. Start the CaterPro backend and open http://localhost:8787/admin";
  }

  function authHeaders() {
    const token = localStorage.getItem("caterpro.admin.token") || "";
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async function adminFetch(path) {
    const response = await fetch(`${apiBase()}${path}`, { headers: authHeaders() });
    const payload = await response.json().catch(() => ({}));
    if (response.status === 401 || response.status === 403) {
      localStorage.removeItem("caterpro.admin.token");
      if (location.pathname.split("/").pop() !== "login.html") goToPage("login.html");
    }
    if (!response.ok) throw new Error(payload.message || `Request failed: ${response.status}`);
    return payload;
  }

  async function adminRequest(path, options = {}) {
    const headers = { ...authHeaders(), ...(options.headers || {}) };
    if (options.body && !(options.body instanceof FormData)) headers["Content-Type"] = "application/json";
    const response = await fetch(`${apiBase()}${path}`, {
      ...options,
      headers,
      body: options.body && !(options.body instanceof FormData) ? JSON.stringify(options.body) : options.body,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.message || `Request failed: ${response.status}`);
    return payload;
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatMoney(value) {
    return `\u20B9${Number(value || 0).toLocaleString("en-IN")}`;
  }

  function formatDate(value) {
    if (!value) return "-";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return escapeHtml(value);
    return date.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
  }

  function initials(name) {
    return String(name || "CP")
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase())
      .join("") || "CP";
  }

  function setMainContent(html) {
    const main = document.querySelector("main");
    if (!main) return;
    const header = main.querySelector("header");
    Array.from(main.children).forEach((child) => {
      if (child !== header) child.remove();
    });
    main.insertAdjacentHTML("beforeend", html);
  }

  function showAdminState(message) {
    const loginMain = document.querySelector("main");
    if (location.pathname.split("/").pop() === "login.html" && loginMain) {
      let node = document.getElementById("admin-login-state");
      if (!node) {
        node = document.createElement("div");
        node.id = "admin-login-state";
        node.className = "mt-4 rounded-lg border border-error/30 bg-error-container px-4 py-3 text-on-error-container text-sm";
        document.querySelector("form")?.append(node);
      }
      node.textContent = message;
      return;
    }
    setMainContent(`<div class="p-container_padding"><div class="rounded-xl border border-outline-variant bg-white p-6 text-on-surface-variant">${escapeHtml(message)}</div></div>`);
  }

  function metricCard(icon, label, value, tone = "primary") {
    const tones = {
      primary: "bg-primary/10 text-primary",
      secondary: "bg-secondary/10 text-secondary",
      error: "bg-error-container text-error",
      surface: "bg-surface-container-high text-on-surface-variant",
    };
    return `<div class="bg-surface-container-lowest border border-outline-variant p-5 rounded-xl">
      <div class="flex justify-between items-start mb-4">
        <div class="p-2 ${tones[tone] || tones.primary} rounded-lg"><span class="material-symbols-outlined">${icon}</span></div>
      </div>
      <p class="text-on-surface-variant font-label-sm text-label-sm uppercase tracking-wider">${label}</p>
      <h3 class="text-headline-sm font-headline-sm text-on-surface mt-1">${value}</h3>
    </div>`;
  }

  function clientTabHref(file, userId) {
    return `${file}?userId=${encodeURIComponent(userId || "")}`;
  }

  function clientFrame(data, activeKey, body) {
    const user = data.user || {};
    const tabs = [
      ["Client Details", "client-detail.html", "details"],
      ["Events", "client-events.html", "events"],
      ["Quotations & Invoices", "client-billing.html", "billing"],
      ["Menu Items", "client-menu.html", "menu"],
      ["Custom Menu", "client-custom-menus.html", "customMenus"],
      ["Employees", "client-employees.html", "employees"],
      ["Reports", "client-reports.html", "reports"],
      ["Audit Activity", "client-audit.html", "audit"],
    ];
    return `<div class="p-container_padding max-w-[1600px] mx-auto space-y-gutter">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div class="flex items-start gap-5 min-w-0">
          <div class="w-20 h-20 rounded-2xl bg-white border border-outline-variant shadow-sm flex items-center justify-center overflow-hidden shrink-0">
            <img class="w-full h-full object-contain p-2" alt="CaterPro" src="../assets/caterpro_logo.png"/>
          </div>
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-3 mb-1">
              <h1 class="font-display-lg text-display-lg text-on-surface">${escapeHtml(user.businessName || user.name || "Client")}</h1>
              <span class="px-2.5 py-0.5 rounded-full bg-primary-container text-on-primary-container text-[11px] font-bold uppercase tracking-wider">${escapeHtml(user.plan || "Plan")}</span>
              <span class="px-2.5 py-0.5 rounded-full bg-secondary-container text-on-secondary-container text-[11px] font-bold uppercase tracking-wider">${escapeHtml(user.status || "Active")}</span>
            </div>
            <p class="text-on-surface-variant font-body-md flex items-center gap-2"><span class="material-symbols-outlined text-base">mail</span>${escapeHtml(user.email || "")}</p>
          </div>
        </div>
        <div class="flex gap-3">
          <button class="px-5 py-2.5 border border-outline-variant rounded-lg font-label-md text-label-md hover:bg-white transition-all flex items-center gap-2"><span class="material-symbols-outlined text-lg">edit</span> Edit Client</button>
          <button class="px-5 py-2.5 bg-primary text-on-primary rounded-lg font-label-md text-label-md hover:bg-primary/90 transition-all flex items-center gap-2 shadow-md shadow-primary/20"><span class="material-symbols-outlined text-lg">add_circle</span> New Order</button>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        ${metricCard("payments", "Total Earning", formatMoney(user.totalEarning), "secondary")}
        ${metricCard("pending_actions", "Pending Payment", formatMoney(user.pendingPayment), "error")}
        ${metricCard("receipt", "Total Orders", String(user.eventCount || 0), "primary")}
        ${metricCard("sync_saved_locally", "Sync Status", user.lastSyncAt ? `Synced ${formatDate(user.lastSyncAt)}` : "No sync activity", "surface")}
      </div>
      <nav class="border-b border-outline-variant flex gap-8 overflow-x-auto scrollbar-hide">
        ${tabs.map(([label, file, key]) => `<a class="pb-3 border-b-2 ${activeKey === key ? "border-primary text-primary font-bold" : "border-transparent text-on-surface-variant hover:text-primary"} transition-all flex items-center gap-2 whitespace-nowrap" href="${clientTabHref(file, user.id)}">${label}</a>`).join("")}
      </nav>
      ${body}
    </div>`;
  }

  async function renderDashboard() {
    const data = await adminFetch("/admin/overview");
    const users = data.users || [];
    const totals = data.totals || {};
    setMainContent(`<div class="p-container_padding max-w-[1600px] mx-auto space-y-gutter">
      <div class="flex items-center justify-between">
        <div><h2 class="font-display-lg text-display-lg text-on-surface">Administrative Overview</h2><p class="text-on-surface-variant">Live data from CaterPro online DB state: ${escapeHtml(data.storage?.stateId || "default")}</p></div>
        <button class="flex items-center gap-2 px-4 py-2 border border-outline-variant bg-surface-container-lowest rounded-lg font-label-md text-label-md" onclick="location.reload()"><span class="material-symbols-outlined text-[18px]">refresh</span>Refresh</button>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-gutter">
        ${metricCard("group", "Total Users", String(totals.users || 0), "primary")}
        ${metricCard("person_check", "Active Users", String(totals.activeUsers || 0), "secondary")}
        ${metricCard("event", "Total Events", String(totals.events || 0), "primary")}
        ${metricCard("pending_actions", "Pending Payments", formatMoney(totals.pendingPayment), "error")}
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-gutter">
        <section class="lg:col-span-2 bg-white border border-outline-variant rounded-xl overflow-hidden">
          <div class="p-6 border-b border-outline-variant"><h3 class="font-title-lg text-title-lg">Clients</h3></div>
          <div class="divide-y divide-outline-variant">${users.length ? users.slice(0, 8).map(user => `<a class="p-4 flex items-center gap-4 hover:bg-surface-container-low transition-colors" href="${clientTabHref("client-detail.html", user.id)}"><div class="w-10 h-10 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-bold">${initials(user.businessName)}</div><div><p class="font-label-md text-label-md">${escapeHtml(user.businessName)}</p><p class="text-label-sm text-on-surface-variant">${escapeHtml(user.email)}</p></div><div class="ml-auto text-right"><p class="font-semibold">${formatMoney(user.totalEarning)}</p><p class="text-label-sm text-error">${formatMoney(user.pendingPayment)} pending</p></div></a>`).join("") : `<div class="p-6 text-on-surface-variant">No business users found in DB.</div>`}</div>
        </section>
        <section class="bg-white border border-outline-variant rounded-xl p-6 space-y-4">
          <h3 class="font-title-lg text-title-lg">Storage</h3>
          <div class="flex justify-between"><span class="text-on-surface-variant">Supabase</span><span class="font-bold">${data.storage?.supabaseEnabled ? "Connected" : "Not configured"}</span></div>
          <div class="flex justify-between"><span class="text-on-surface-variant">Total Revenue</span><span class="font-bold">${formatMoney(totals.totalEarning)}</span></div>
          <div class="flex justify-between"><span class="text-on-surface-variant">Invoices</span><span class="font-bold">${totals.invoices || 0}</span></div>
        </section>
      </div>
    </div>`);
  }

  async function renderClients() {
    let data = await adminFetch("/admin/users");
    setMainContent(`<div class="p-6 space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex flex-wrap gap-3">
          <input id="admin-client-search" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2 min-w-[320px]" placeholder="Search clients, owner, email, mobile"/>
          <select id="admin-client-plan-filter" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2">
            <option value="">All plans</option>
            ${[...new Set(data.map((user) => user.plan).filter(Boolean))].sort().map((plan) => `<option value="${escapeHtml(plan)}">${escapeHtml(plan)}</option>`).join("")}
          </select>
          <select id="admin-client-status-filter" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2">
            <option value="">All status</option>
            ${[...new Set(data.map((user) => user.status).filter(Boolean))].sort().map((status) => `<option value="${escapeHtml(status)}">${escapeHtml(status)}</option>`).join("")}
          </select>
        </div>
        <span class="text-xs font-label-sm text-on-surface-variant">${data.length} clients from DB</span>
      </div>
      <div class="bg-white rounded-xl border border-outline-variant overflow-hidden">
        <table class="w-full text-left border-collapse min-w-[1200px]">
          <thead><tr class="bg-surface-container-low/50 border-b border-outline-variant">${clientHeader("Business Name", "businessName")}${clientHeader("Owner", "ownerName")}${clientHeader("Plan", "plan")}${clientHeader("Contact", "email")}${clientHeader("Stats", "eventCount", "text-center")}${clientHeader("Financials", "totalEarning", "text-right")}${clientHeader("Status", "status")}<th class="px-4 py-3 text-right">Actions</th></tr></thead>
          <tbody id="admin-client-rows" class="divide-y divide-outline-variant"></tbody>
        </table>
      </div>
    </div>`);
    const search = document.getElementById("admin-client-search");
    const planFilter = document.getElementById("admin-client-plan-filter");
    const statusFilter = document.getElementById("admin-client-status-filter");
    const rows = document.getElementById("admin-client-rows");
    const state = { sortKey: "businessName", sortDirection: "asc" };
    const renderRows = () => {
      const query = (search?.value || "").toLowerCase();
      const plan = planFilter?.value || "";
      const status = statusFilter?.value || "";
      const filtered = data.filter((user) => {
        const searchText = [user.businessName, user.ownerName, user.name, user.email, user.phone, user.city, user.plan, user.status].join(" ").toLowerCase();
        return (!query || searchText.includes(query)) && (!plan || user.plan === plan) && (!status || user.status === status);
      }).sort((a, b) => compareClientValues(a[state.sortKey], b[state.sortKey], state.sortDirection));
      rows.innerHTML = filtered.length ? filtered.map(clientRow).join("") : `<tr><td class="px-4 py-6 text-on-surface-variant" colspan="8">No clients match the selected filters.</td></tr>`;
      wireClientTableActions(data);
    };
    document.querySelectorAll("[data-client-sort]").forEach((header) => {
      header.addEventListener("click", () => {
        const key = header.dataset.clientSort;
        state.sortDirection = state.sortKey === key && state.sortDirection === "asc" ? "desc" : "asc";
        state.sortKey = key;
        document.querySelectorAll("[data-client-sort-icon]").forEach((icon) => { icon.textContent = "unfold_more"; });
        const icon = header.querySelector("[data-client-sort-icon]");
        if (icon) icon.textContent = state.sortDirection === "asc" ? "arrow_upward" : "arrow_downward";
        renderRows();
      });
    });
    [search, planFilter, statusFilter].forEach((control) => control?.addEventListener("input", renderRows));
    renderRows();
  }

  function clientHeader(label, key, align = "") {
    return `<th class="px-4 py-3 ${align}"><button class="inline-flex items-center gap-1 font-bold hover:text-primary" data-client-sort="${key}">${label}<span class="material-symbols-outlined text-[17px]" data-client-sort-icon>${key === "businessName" ? "arrow_upward" : "unfold_more"}</span></button></th>`;
  }

  function compareClientValues(left, right, direction) {
    const multiplier = direction === "desc" ? -1 : 1;
    const leftNumber = Number(left);
    const rightNumber = Number(right);
    if (!Number.isNaN(leftNumber) && !Number.isNaN(rightNumber)) return (leftNumber - rightNumber) * multiplier;
    return String(left || "").localeCompare(String(right || ""), undefined, { numeric: true, sensitivity: "base" }) * multiplier;
  }

  function clientRow(user) {
    const disabled = String(user.status || "").toLowerCase() === "disabled";
    return `<tr class="hover:bg-surface-bright transition-colors ${disabled ? "opacity-65 bg-surface-container-low/50" : ""}">
      <td class="px-4 py-4"><div class="flex items-center gap-3"><div class="w-9 h-9 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-bold">${initials(user.businessName)}</div><div><p class="font-bold">${escapeHtml(user.businessName)}</p><p class="text-xs text-on-surface-variant">${escapeHtml(user.city || "")}</p></div></div></td>
      <td class="px-4 py-4">${escapeHtml(user.ownerName)}</td>
      <td class="px-4 py-4"><span class="px-2 py-0.5 rounded bg-primary-container text-on-primary-container text-[11px] font-bold uppercase">${escapeHtml(user.plan)}</span></td>
      <td class="px-4 py-4"><div class="text-xs"><p>${escapeHtml(user.email)}</p><p class="text-on-surface-variant">${escapeHtml(user.phone || "-")}</p></div></td>
      <td class="px-4 py-4 text-center text-xs">${user.eventCount || 0} events | ${user.invoiceCount || 0} invoices</td>
      <td class="px-4 py-4 text-right"><p class="font-bold">${formatMoney(user.totalEarning)}</p><p class="text-xs text-error">Pending: ${formatMoney(user.pendingPayment)}</p></td>
      <td class="px-4 py-4"><span class="px-2 py-1 rounded-full ${disabled ? "bg-error-container text-on-error-container" : "bg-secondary-container text-on-secondary-container"} text-[11px] font-bold">${escapeHtml(user.status)}</span></td>
      <td class="px-4 py-4 text-right">
        <div class="inline-flex gap-1">
          <a class="p-2 inline-flex hover:bg-surface-container-highest rounded text-on-surface-variant" title="Info" href="${clientTabHref("client-detail.html", user.id)}"><span class="material-symbols-outlined text-[18px]">info</span></a>
          <button class="client-edit p-2 inline-flex hover:bg-surface-container-highest rounded text-on-surface-variant" data-id="${escapeHtml(user.id)}" title="Edit"><span class="material-symbols-outlined text-[18px]">edit</span></button>
          <button class="client-disable p-2 inline-flex hover:bg-error-container rounded ${disabled ? "text-primary" : "text-error"}" data-id="${escapeHtml(user.id)}" title="${disabled ? "Enable" : "Disable"}"><span class="material-symbols-outlined text-[18px]">${disabled ? "toggle_on" : "block"}</span></button>
        </div>
      </td>
    </tr>`;
  }

  function wireClientTableActions(users) {
    const byId = new Map(users.map((user) => [String(user.id), user]));
    document.querySelectorAll(".client-edit").forEach((button) => button.addEventListener("click", async () => {
      const user = byId.get(button.dataset.id || "");
      if (!user) return;
      const businessName = prompt("Business name", user.businessName || "");
      if (businessName === null) return;
      const ownerName = prompt("Owner name", user.ownerName || user.name || "");
      if (ownerName === null) return;
      const phone = prompt("Phone", user.phone || "");
      if (phone === null) return;
      const plan = prompt("Plan", user.plan || "");
      if (plan === null) return;
      const status = prompt("Status", user.status || "Active");
      if (status === null) return;
      await adminRequest(`/admin/users/${encodeURIComponent(user.id)}`, {
        method: "PUT",
        body: { businessName, name: ownerName, phone, plan, status },
      });
      location.reload();
    }));
    document.querySelectorAll(".client-disable").forEach((button) => button.addEventListener("click", async () => {
      const user = byId.get(button.dataset.id || "");
      if (!user) return;
      const disabled = String(user.status || "").toLowerCase() === "disabled";
      const nextStatus = disabled ? "Active" : "Disabled";
      if (!confirm(`${nextStatus === "Disabled" ? "Disable" : "Enable"} ${user.businessName || user.email}?`)) return;
      await adminRequest(`/admin/users/${encodeURIComponent(user.id)}`, {
        method: "PUT",
        body: { status: nextStatus },
      });
      location.reload();
    }));
  }

  async function renderClientPage(activeKey) {
    const params = new URLSearchParams(location.search);
    const userId = params.get("userId") || localStorage.getItem("caterpro.admin.selectedUserId") || "";
    const data = await adminFetch(`/admin/client-data${userId ? `?userId=${encodeURIComponent(userId)}` : ""}`);
    if (data.user?.id) localStorage.setItem("caterpro.admin.selectedUserId", data.user.id);
    const bodies = {
      details: clientDetailsBody(data),
      events: clientEventsBody(data),
      billing: clientBillingBody(data),
      menu: clientMenuBody(data),
      customMenus: clientCustomMenusBody(data),
      employees: clientEmployeesBody(data),
      reports: clientReportsBody(data),
      audit: clientAuditBody(data),
    };
    setMainContent(clientFrame(data, activeKey, bodies[activeKey] || bodies.details));
    wireAdminDataTables();
    if (activeKey === "menu") wireClientMenuActions(data);
    if (activeKey === "customMenus") wireClientCustomMenuActions(data);
  }

  function clientDetailsBody(data) {
    const params = new URLSearchParams(location.search);
    const appClientId = params.get("appClientId") || "";
    if (appClientId) return appClientDetailsBody(data, appClientId);
    const profile = data.businessProfile || {};
    const rows = [
      { section: "Business", field: "Business Name", value: profile.businessName || data.user?.businessName || "" },
      { section: "Business", field: "Email", value: profile.email || data.user?.email || "" },
      { section: "Business", field: "Phone", value: profile.phone || data.user?.phone || "" },
      { section: "Tax & Legal", field: "GSTIN", value: profile.gstin || "" },
      { section: "Bank", field: "Bank", value: profile.bankName || "" },
      { section: "Bank", field: "IFSC", value: profile.ifsc || "" },
      { section: "Address", field: "Address", value: profile.address || "" },
      { section: "Operations", field: "Events", value: String(data.events?.length || 0) },
      { section: "Operations", field: "Invoices", value: String(data.invoices?.length || 0) },
      { section: "Operations", field: "Employees", value: String(data.employees?.length || 0) },
      { section: "Operations", field: "Menu Items", value: String(data.menuItems?.length || 0) },
    ];
    return adminTable({
      id: "client-details-table",
      title: "Client Details",
      subtitle: "Business profile and operational snapshot from the client DB state.",
      filters: [{ key: "section", label: "section", values: uniqueValues(rows, (row) => row.section) }],
      columns: [{ label: "Section", key: "section", width: "18%" }, { label: "Field", key: "field", width: "18%" }, { label: "Value", key: "value", width: "auto" }],
      rows: rows.map((row) => `<tr ${rowAttrs([row.section, row.field, row.value].join(" "), { section: row.section })}>
        ${cell(escapeHtml(row.section), "section")}
        ${cell(`<div class="font-semibold">${escapeHtml(row.field)}</div>`, "field")}
        ${cell(escapeHtml(row.value || "-"), "value")}
        <td class="px-6 py-4 text-right">${iconButton("info", `${row.field} info`)}${iconButton("edit", `Edit ${row.field}`)}</td>
      </tr>`),
      empty: "No client details found.",
      actionWidth: "112px",
    });
  }

  function appClientDetailsBody(data, appClientId) {
    const client = (data.clients || []).find((item) => item.id === appClientId) || {};
    const mobile = String(client.mobile || "");
    const name = String(client.name || "");
    const linkedEvents = (data.events || []).filter((event) => String(event.mobile || "") === mobile || String(event.primaryClient || "").toLowerCase() === name.toLowerCase());
    const linkedInvoices = (data.invoices || []).filter((invoice) => String(invoice.mobile || "") === mobile || String(invoice.clientName || "").toLowerCase() === name.toLowerCase());
    const rows = [
      { section: "Client", field: "Name", value: client.name || "" },
      { section: "Client", field: "Mobile", value: client.mobile || "" },
      { section: "Client", field: "Address", value: client.address || client.city || "" },
      { section: "Client", field: "GST", value: client.gst || "" },
      { section: "Activity", field: "Events", value: String(linkedEvents.length) },
      { section: "Activity", field: "Quotations & Invoices", value: String(linkedInvoices.length) },
    ];
    return adminTable({
      id: "app-client-details-table",
      title: client.name ? `Client: ${client.name}` : "Client Details",
      subtitle: "Individual event client details from this CaterPro business account.",
      filters: [{ key: "section", label: "section", values: uniqueValues(rows, (row) => row.section) }],
      columns: [{ label: "Section", key: "section", width: "18%" }, { label: "Field", key: "field", width: "18%" }, { label: "Value", key: "value", width: "auto" }],
      rows: rows.map((row) => `<tr ${rowAttrs([row.section, row.field, row.value].join(" "), { section: row.section })}>
        ${cell(escapeHtml(row.section), "section")}
        ${cell(`<div class="font-semibold">${escapeHtml(row.field)}</div>`, "field")}
        ${cell(escapeHtml(row.value || "-"), "value")}
        <td class="px-6 py-4 text-right whitespace-nowrap">${iconButton("info", `${row.field} info`)}${iconButton("edit", `Edit ${row.field}`)}</td>
      </tr>`),
      empty: "No client details found.",
      actionWidth: "112px",
    });
  }

  function field(label, value, wide = false) {
    return `<label class="space-y-1.5 ${wide ? "md:col-span-2" : ""}"><span class="text-label-sm font-label-sm text-on-surface-variant">${label}</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(value || "")}" /></label>`;
  }

  function simpleTable(headers, rows, empty) {
    return `<section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
      <table class="w-full text-left"><thead class="bg-surface-container"><tr>${headers.map(h => `<th class="px-6 py-4">${h}</th>`).join("")}</tr></thead>
      <tbody class="divide-y divide-outline-variant/30">${rows.length ? rows.join("") : `<tr><td class="px-6 py-6 text-on-surface-variant" colspan="${headers.length}">${empty}</td></tr>`}</tbody></table>
    </section>`;
  }

  function tableHeader(label, key, align = "") {
    return `<th class="px-6 py-4 ${align}"><button class="inline-flex items-center gap-1 font-bold hover:text-primary" data-table-sort="${key}">${label}<span class="material-symbols-outlined text-[17px]" data-table-sort-icon>unfold_more</span></button></th>`;
  }

  function rowAttrs(search, filters = {}) {
    return `data-search="${escapeHtml(String(search || "").toLowerCase())}" ${Object.entries(filters).map(([key, value]) => `data-filter-${key}="${escapeHtml(value || "")}"`).join(" ")}`;
  }

  function cell(value, key, align = "") {
    return `<td class="px-6 py-4 align-middle ${align}" data-sort-${key}="${escapeHtml(value ?? "")}">${value}</td>`;
  }

  function iconButton(icon, title, extra = "") {
    return `<button class="p-2 inline-flex hover:bg-surface-container-highest rounded text-on-surface-variant ${extra}" title="${escapeHtml(title)}"><span class="material-symbols-outlined text-[18px]">${icon}</span></button>`;
  }

  function iconLink(icon, title, href, extra = "") {
    return `<a class="p-2 inline-flex hover:bg-surface-container-highest rounded text-on-surface-variant ${extra}" title="${escapeHtml(title)}" href="${escapeHtml(href)}" target="_blank" rel="noopener"><span class="material-symbols-outlined text-[18px]">${icon}</span></a>`;
  }

  function adminTable({ id, title, subtitle, filters = [], columns, rows, empty, actionWidth = "132px" }) {
    return `<section class="space-y-3" data-admin-table="${id}">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 class="font-title-lg text-title-lg">${escapeHtml(title)}</h3>
          ${subtitle ? `<p class="text-sm text-on-surface-variant">${escapeHtml(subtitle)}</p>` : ""}
        </div>
        <div class="flex flex-wrap gap-2">
          <input class="admin-table-search bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2 min-w-[280px]" placeholder="Search ${escapeHtml(title.toLowerCase())}"/>
          ${filters.map((filter) => `<select class="admin-table-filter bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2" data-filter-key="${escapeHtml(filter.key)}"><option value="">All ${escapeHtml(filter.label)}</option>${filter.values.map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`).join("")}</select>`).join("")}
        </div>
      </div>
      <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
        <div class="overflow-x-auto">
          <table class="w-full text-left min-w-[1100px] table-fixed">
            <colgroup>${columns.map((column) => `<col style="width:${escapeHtml(column.width || "auto")}">`).join("")}<col style="width:${escapeHtml(actionWidth)}"></colgroup>
            <thead class="bg-surface-container"><tr>${columns.map((column) => tableHeader(column.label, column.key, column.align)).join("")}<th class="px-6 py-4 text-right">Actions</th></tr></thead>
            <tbody class="admin-table-rows divide-y divide-outline-variant/30">${rows.length ? rows.join("") : `<tr data-empty-row><td class="px-6 py-6 text-on-surface-variant" colspan="${columns.length + 1}">${escapeHtml(empty)}</td></tr>`}</tbody>
          </table>
        </div>
      </section>
    </section>`;
  }

  function uniqueValues(items, selector) {
    return [...new Set(items.map(selector).filter(Boolean).map(String))].sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
  }

  function asArray(value) {
    return Array.isArray(value) ? value : [];
  }

  function wireAdminDataTables() {
    document.querySelectorAll("[data-admin-table]").forEach((table) => {
      const search = table.querySelector(".admin-table-search");
      const filters = [...table.querySelectorAll(".admin-table-filter")];
      const rowsBody = table.querySelector(".admin-table-rows");
      const dataRows = [...rowsBody?.querySelectorAll("tr:not([data-empty-row])") || []];
      const applyFilters = () => {
        const query = String(search?.value || "").toLowerCase();
        dataRows.forEach((row) => {
          const matchesSearch = !query || String(row.dataset.search || "").includes(query);
          const matchesFilters = filters.every((filter) => {
            const value = filter.value;
            const key = filter.dataset.filterKey;
            return !value || row.dataset[`filter${key[0].toUpperCase()}${key.slice(1)}`] === value;
          });
          row.style.display = matchesSearch && matchesFilters ? "" : "none";
        });
      };
      search?.addEventListener("input", applyFilters);
      filters.forEach((filter) => filter.addEventListener("input", applyFilters));
      table.querySelectorAll("[data-table-sort]").forEach((button) => {
        button.addEventListener("click", () => {
          const key = button.dataset.tableSort;
          const current = button.dataset.sortDirection === "asc" ? "desc" : "asc";
          button.dataset.sortDirection = current;
          table.querySelectorAll("[data-table-sort-icon]").forEach((icon) => { icon.textContent = "unfold_more"; });
          const icon = button.querySelector("[data-table-sort-icon]");
          if (icon) icon.textContent = current === "asc" ? "arrow_upward" : "arrow_downward";
          dataRows.sort((left, right) => compareClientValues(left.querySelector(`[data-sort-${key}]`)?.getAttribute(`data-sort-${key}`), right.querySelector(`[data-sort-${key}]`)?.getAttribute(`data-sort-${key}`), current));
          dataRows.forEach((row) => rowsBody.appendChild(row));
          applyFilters();
        });
      });
    });
  }

  function appClientForEvent(data, event) {
    const mobile = String(event.mobile || "").replace(/\D/g, "");
    const name = String(event.primaryClient || "").trim().toLowerCase();
    return (data.clients || []).find((client) => {
      const clientMobile = String(client.mobile || "").replace(/\D/g, "");
      const clientName = String(client.name || "").trim().toLowerCase();
      return (mobile && clientMobile === mobile) || (name && clientName === name);
    }) || null;
  }

  function appClientLink(data, event) {
    const client = appClientForEvent(data, event);
    const label = event.primaryClient || client?.name || event.mobile || "-";
    if (!client?.id) return escapeHtml(label);
    return `<a class="font-semibold text-primary hover:underline" href="${clientTabHref("client-detail.html", data.user?.id)}&appClientId=${encodeURIComponent(client.id)}">${escapeHtml(label)}</a><p class="text-xs text-on-surface-variant">${escapeHtml(event.mobile || client.mobile || "")}</p>`;
  }

  function clientEventsBody(data) {
    const events = data.events || [];
    return adminTable({
      id: "client-events-table",
      title: "Events",
      subtitle: `${events.length} events from DB`,
      filters: [{ key: "status", label: "status", values: uniqueValues(events, (event) => event.status) }],
      columns: [{ label: "Event", key: "event", width: "20%" }, { label: "Client", key: "client", width: "20%" }, { label: "Date", key: "date", width: "12%" }, { label: "Venue", key: "venue", width: "22%" }, { label: "Status", key: "status", width: "10%" }, { label: "Total", key: "total", align: "text-right", width: "10%" }, { label: "Balance", key: "balance", align: "text-right", width: "10%" }],
      rows: events.map((event) => `<tr ${rowAttrs([event.name, event.primaryClient, event.mobile, event.venue, event.status].join(" "), { status: event.status || "" })}>
        ${cell(`<div class="font-semibold">${escapeHtml(event.name || "Untitled Event")}</div>`, "event")}
        ${cell(appClientLink(data, event), "client")}
        ${cell(formatDate(event.date), "date")}
        ${cell(escapeHtml(event.venue || "-"), "venue")}
        ${cell(escapeHtml(event.status || "-"), "status")}
        ${cell(formatMoney(event.total), "total", "text-right font-bold")}
        ${cell(formatMoney(event.balance), "balance", "text-right text-error")}
        <td class="px-6 py-4 text-right whitespace-nowrap">${iconButton("info", "Event info")}${iconButton("edit", "Edit event")}${iconButton("delete", "Delete event", "text-error hover:bg-error-container")}</td>
      </tr>`),
      empty: "No events found for this user.",
      actionWidth: "120px",
    });
  }

  function clientBillingBody(data) {
    const invoices = data.invoices || [];
    const userId = data.user?.id || "";
    return adminTable({
      id: "client-billing-table",
      title: "Quotations & Invoices",
      subtitle: `${invoices.length} billing documents from DB`,
      filters: [{ key: "type", label: "type", values: uniqueValues(invoices, (invoice) => invoice.type) }],
      columns: [{ label: "Type", key: "type", width: "12%" }, { label: "Document #", key: "document", width: "23%" }, { label: "Client", key: "client", width: "25%" }, { label: "Date", key: "date", width: "14%" }, { label: "Total", key: "total", align: "text-right", width: "12%" }, { label: "Pending", key: "pending", align: "text-right", width: "12%" }],
      rows: invoices.map((invoice) => `<tr ${rowAttrs([invoice.type, invoice.documentNumber, invoice.clientName, invoice.eventName, invoice.mobile].join(" "), { type: invoice.type || "" })}>
        ${cell(escapeHtml(invoice.type || "-"), "type")}
        ${cell(`<span class="font-data-mono text-data-mono">${escapeHtml(invoice.documentNumber || "-")}</span>`, "document")}
        ${cell(escapeHtml(invoice.clientName || "-"), "client")}
        ${cell(formatDate(invoice.date), "date")}
        ${cell(formatMoney(invoice.total), "total", "text-right font-bold")}
        ${cell(formatMoney(invoice.pending), "pending", "text-right text-error")}
        <td class="px-6 py-4 text-right whitespace-nowrap">${iconButton("info", "Document info")}${iconButton("edit", "Edit document")}${iconLink("download", `Open ${invoice.type || "document"} PDF`, billingPdfUrl(userId, invoice))}</td>
      </tr>`),
      empty: "No invoices or quotations found for this user.",
      actionWidth: "120px",
    });
  }

  function billingPdfUrl(userId, invoice) {
    const token = localStorage.getItem("caterpro.admin.token") || "";
    const tokenQuery = token ? `?token=${encodeURIComponent(token)}` : "";
    if (invoice.source === "manual") {
      return `${apiBase()}/admin/users/${encodeURIComponent(userId)}/manual-invoices/${encodeURIComponent(invoice.invoiceId || invoice.id || "")}/pdf${tokenQuery}`;
    }
    return `${apiBase()}/admin/users/${encodeURIComponent(userId)}/events/${encodeURIComponent(invoice.eventId || invoice.id || "")}/documents/${encodeURIComponent(invoice.pdfType || "invoice")}${tokenQuery}`;
  }

  function clientMenuBody(data) {
    const items = data.menuItems || [];
    return `<section class="bg-surface-container-low p-4 rounded-xl border border-outline-variant">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 class="font-title-lg text-title-lg">Menu Items</h3>
          <p class="text-on-surface-variant text-sm">${items.length} user-specific items from DB</p>
        </div>
        <div class="flex flex-wrap gap-2">
          <button id="menu-export" class="px-4 py-2 border border-outline-variant rounded-lg font-label-md text-label-md flex items-center gap-2"><span class="material-symbols-outlined text-[18px]">upload_file</span> Export</button>
          <button id="menu-template" class="px-4 py-2 border border-outline-variant rounded-lg font-label-md text-label-md flex items-center gap-2"><span class="material-symbols-outlined text-[18px]">description</span> Import Template</button>
          <label class="px-4 py-2 bg-primary text-on-primary rounded-lg font-label-md text-label-md flex items-center gap-2 cursor-pointer"><span class="material-symbols-outlined text-[18px]">download</span> Import<input id="menu-import-file" class="hidden" type="file" accept=".csv,.json"/></label>
        </div>
      </div>
    </section>
    ${adminTable({
      id: "client-menu-table",
      title: "Menu Item Records",
      subtitle: "Search, filter, sort, edit, disable, or delete user-specific menu items.",
      filters: [
        { key: "category", label: "category", values: uniqueValues(items, (item) => item.category) },
        { key: "type", label: "type", values: ["Veg", "Non-Veg"] },
        { key: "status", label: "status", values: ["Active", "Disabled"] },
      ],
      columns: [{ label: "Name", key: "name", width: "44%" }, { label: "Category", key: "category", width: "15%" }, { label: "Meals", key: "meals", width: "18%" }, { label: "Type", key: "type", width: "10%" }, { label: "Status", key: "status", width: "10%" }],
      rows: items.map(menuRow),
      empty: "No user-specific menu items found.",
      actionWidth: "132px",
    })}`;
  }

  function menuRow(item) {
    const title = item.title || [item.kannada, item.english].filter(Boolean).join(" / ") || item.name || item.id;
    const encoded = encodeURIComponent(item.id || "");
    const type = item.veg === false ? "Non-Veg" : "Veg";
    const status = item.disabled ? "Disabled" : "Active";
    return `<tr class="${item.disabled ? "opacity-60 bg-surface-container-low/40" : ""}" ${rowAttrs([title, item.id, item.category, item.meals, type, status].join(" "), { category: item.category || "", type, status })}>
      ${cell(`<div class="font-semibold">${escapeHtml(title)}</div><p class="text-xs text-on-surface-variant">${escapeHtml(item.id || "")}</p>`, "name")}
      ${cell(escapeHtml(item.category || "-"), "category")}
      ${cell(escapeHtml(Array.isArray(item.meals) ? item.meals.join(", ") : item.meals || "-"), "meals")}
      ${cell(type, "type")}
      ${cell(`<span class="px-2 py-1 rounded-full text-[11px] font-bold ${item.disabled ? "bg-error-container text-on-error-container" : "bg-secondary-container text-on-secondary-container"}">${status}</span>`, "status")}
      <td class="px-6 py-4 text-right whitespace-nowrap">
        <div class="flex justify-end gap-1">
          <button class="menu-edit p-2 hover:bg-surface-container-highest rounded" data-id="${encoded}" title="Edit"><span class="material-symbols-outlined text-[18px]">edit</span></button>
          <button class="menu-toggle p-2 hover:bg-surface-container-highest rounded" data-id="${encoded}" title="${item.disabled ? "Enable" : "Disable"}"><span class="material-symbols-outlined text-[18px]">${item.disabled ? "toggle_on" : "block"}</span></button>
          <button class="menu-delete p-2 hover:bg-error-container rounded text-error" data-id="${encoded}" title="Delete"><span class="material-symbols-outlined text-[18px]">delete</span></button>
        </div>
      </td>
    </tr>`;
  }

  function menuCsvRows(items) {
    const columns = ["id", "english", "kannada", "title", "category", "meals", "veg", "disabled"];
    const escapeCell = (value) => `"${String(value ?? "").replace(/"/g, '""')}"`;
    return [columns.join(","), ...items.map((item) => columns.map((column) => {
      const value = column === "meals" && Array.isArray(item.meals) ? item.meals.join("|") : item[column];
      return escapeCell(value);
    }).join(","))].join("\n");
  }

  function downloadTextFile(name, text, type = "text/csv") {
    const blob = new Blob([text], { type });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = name;
    link.click();
    URL.revokeObjectURL(url);
  }

  function parseCsv(text) {
    const rows = [];
    let cell = "";
    let row = [];
    let quoted = false;
    for (let index = 0; index < text.length; index += 1) {
      const char = text[index];
      const next = text[index + 1];
      if (quoted && char === '"' && next === '"') {
        cell += '"';
        index += 1;
      } else if (char === '"') {
        quoted = !quoted;
      } else if (!quoted && char === ",") {
        row.push(cell);
        cell = "";
      } else if (!quoted && (char === "\n" || char === "\r")) {
        if (char === "\r" && next === "\n") index += 1;
        row.push(cell);
        if (row.some((value) => value.trim())) rows.push(row);
        row = [];
        cell = "";
      } else {
        cell += char;
      }
    }
    row.push(cell);
    if (row.some((value) => value.trim())) rows.push(row);
    const headers = rows.shift()?.map((header) => header.trim()) || [];
    return rows.map((values) => Object.fromEntries(headers.map((header, index) => {
      let value = values[index] || "";
      if (header === "meals") value = value.split(/[|,]/).map((meal) => meal.trim()).filter(Boolean);
      if (header === "veg" || header === "disabled") value = ["true", "1", "yes", "y"].includes(String(value).toLowerCase());
      return [header, value];
    })));
  }

  function selectedAttr(value, current) {
    return String(value) === String(current) ? "selected" : "";
  }

  function menuMealsValue(item) {
    return Array.isArray(item.meals) ? item.meals : String(item.meals || "").split(",").map((meal) => meal.trim()).filter(Boolean);
  }

  function menuEditModal(item, items) {
    const categoryOptions = uniqueValues(items, (entry) => entry.category);
    const mealOptions = uniqueValues(items.flatMap((entry) => menuMealsValue(entry)).map((meal) => ({ meal })), (entry) => entry.meal);
    const selectedMeals = new Set(menuMealsValue(item));
    const categoryList = categoryOptions.includes(item.category) ? categoryOptions : [item.category, ...categoryOptions].filter(Boolean);
    const mealList = mealOptions.length ? mealOptions : ["Breakfast", "Juice", "Lunch", "Snack", "Dinner", "Others"];
    return `<div id="menu-edit-modal" class="fixed inset-0 z-[100] bg-black/40 flex items-center justify-center p-6">
      <form id="menu-edit-form" class="w-full max-w-3xl bg-white rounded-xl border border-outline-variant shadow-xl overflow-hidden">
        <div class="px-6 py-4 border-b border-outline-variant flex items-center justify-between">
          <div>
            <h3 class="font-title-lg text-title-lg">Edit Menu Item</h3>
            <p class="text-sm text-on-surface-variant">Update every stored field for this user-specific item.</p>
          </div>
          <button type="button" class="menu-modal-close p-2 hover:bg-surface-container-highest rounded" title="Close"><span class="material-symbols-outlined">close</span></button>
        </div>
        <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-4 max-h-[70vh] overflow-y-auto">
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">ID</span><input name="id" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(item.id || "")}"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Status</span><select name="status" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5"><option value="Active" ${selectedAttr(item.disabled ? "Disabled" : "Active", "Active")}>Active</option><option value="Disabled" ${selectedAttr(item.disabled ? "Disabled" : "Active", "Disabled")}>Disabled</option></select></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">English</span><input name="english" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(item.english || "")}"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Kannada</span><input name="kannada" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(item.kannada || "")}"/></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">Title</span><input name="title" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(item.title || [item.kannada, item.english].filter(Boolean).join("/") || "")}"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Category</span><select name="category" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5">${categoryList.map((category) => `<option value="${escapeHtml(category)}" ${selectedAttr(category, item.category)}>${escapeHtml(category)}</option>`).join("")}<option value="__custom__">Custom category...</option></select></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Custom Category</span><input name="customCategory" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" placeholder="Use only if custom selected"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Type</span><select name="veg" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5"><option value="true" ${selectedAttr(item.veg !== false, true)}>Veg</option><option value="false" ${selectedAttr(item.veg === false, true)}>Non-Veg</option></select></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Meals</span><select name="meals" multiple size="6" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5">${mealList.map((meal) => `<option value="${escapeHtml(meal)}" ${selectedMeals.has(meal) ? "selected" : ""}>${escapeHtml(meal)}</option>`).join("")}</select></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">Custom Meals</span><input name="customMeals" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" placeholder="Comma separated, optional" value="${escapeHtml([...selectedMeals].filter((meal) => !mealList.includes(meal)).join(", "))}"/></label>
        </div>
        <div class="px-6 py-4 border-t border-outline-variant flex justify-end gap-3">
          <button type="button" class="menu-modal-close px-4 py-2 border border-outline-variant rounded-lg font-label-md text-label-md">Cancel</button>
          <button type="submit" class="px-5 py-2 bg-primary text-on-primary rounded-lg font-label-md text-label-md flex items-center gap-2"><span class="material-symbols-outlined text-[18px]">save</span>Save Menu Item</button>
        </div>
      </form>
    </div>`;
  }

  function openMenuEditModal(item, items, onSave) {
    document.getElementById("menu-edit-modal")?.remove();
    document.body.insertAdjacentHTML("beforeend", menuEditModal(item, items));
    const modal = document.getElementById("menu-edit-modal");
    const form = document.getElementById("menu-edit-form");
    const close = () => modal?.remove();
    modal?.querySelectorAll(".menu-modal-close").forEach((button) => button.addEventListener("click", close));
    modal?.addEventListener("click", (event) => {
      if (event.target === modal) close();
    });
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const selectedMeals = [...form.querySelectorAll('select[name="meals"] option:checked')].map((option) => option.value);
      const customMeals = String(formData.get("customMeals") || "").split(",").map((meal) => meal.trim()).filter(Boolean);
      const category = formData.get("category") === "__custom__" ? String(formData.get("customCategory") || "").trim() : String(formData.get("category") || "").trim();
      await onSave({
        ...item,
        id: String(formData.get("id") || item.id || "").trim(),
        english: String(formData.get("english") || "").trim(),
        kannada: String(formData.get("kannada") || "").trim(),
        title: String(formData.get("title") || "").trim(),
        category,
        meals: [...new Set([...selectedMeals, ...customMeals])],
        veg: formData.get("veg") === "true",
        disabled: formData.get("status") === "Disabled",
      });
      close();
    });
  }

  function wireClientMenuActions(data) {
    const userId = data.user?.id || "";
    const items = data.menuItems || [];
    const byId = new Map(items.map((item) => [String(item.id), item]));
    document.getElementById("menu-export")?.addEventListener("click", () => {
      downloadTextFile(`caterpro-menu-${userId || "user"}.csv`, menuCsvRows(items));
    });
    document.getElementById("menu-template")?.addEventListener("click", () => {
      downloadTextFile("caterpro-menu-import-template.csv", "id,english,kannada,title,category,meals,veg,disabled\nMNU-001,Idli,\u0C87\u0CA1\u0CCD\u0CB2\u0CBF,\u0C87\u0CA1\u0CCD\u0CB2\u0CBF/Idli,South Indian,Breakfast,true,false\n");
    });
    document.getElementById("menu-import-file")?.addEventListener("change", async (event) => {
      const file = event.target.files?.[0];
      if (!file) return;
      const text = await file.text();
      const itemsToImport = file.name.toLowerCase().endsWith(".json") ? JSON.parse(text) : parseCsv(text);
      await adminRequest(`/admin/users/${encodeURIComponent(userId)}/menu-items/import`, {
        method: "POST",
        body: { items: Array.isArray(itemsToImport) ? itemsToImport : itemsToImport.items },
      });
      location.reload();
    });
    document.querySelectorAll(".menu-edit").forEach((button) => button.addEventListener("click", async () => {
      const item = byId.get(decodeURIComponent(button.dataset.id || ""));
      if (!item) return;
      openMenuEditModal(item, items, async (updatedItem) => {
        await adminRequest(`/admin/users/${encodeURIComponent(userId)}/menu-items/${encodeURIComponent(item.id)}`, {
          method: "PUT",
          body: updatedItem,
        });
        location.reload();
      });
    }));
    document.querySelectorAll(".menu-toggle").forEach((button) => button.addEventListener("click", async () => {
      const item = byId.get(decodeURIComponent(button.dataset.id || ""));
      if (!item) return;
      await adminRequest(`/admin/users/${encodeURIComponent(userId)}/menu-items/${encodeURIComponent(item.id)}`, {
        method: "PUT",
        body: { ...item, disabled: !item.disabled },
      });
      location.reload();
    }));
    document.querySelectorAll(".menu-delete").forEach((button) => button.addEventListener("click", async () => {
      const item = byId.get(decodeURIComponent(button.dataset.id || ""));
      if (!item || !confirm(`Delete "${item.title || item.english || item.id}"?`)) return;
      await adminRequest(`/admin/users/${encodeURIComponent(userId)}/menu-items/${encodeURIComponent(item.id)}`, { method: "DELETE" });
      location.reload();
    }));
  }

  function customMenuItemNames(menu, menuItems) {
    const ids = new Set(asArray(menu.itemIds).map(String));
    return menuItems
      .filter((item) => ids.has(String(item.id)))
      .map((item) => item.title || [item.kannada, item.english].filter(Boolean).join(" / ") || item.english || item.id);
  }

  function clientCustomMenusBody(data) {
    const menus = data.customMenus || [];
    const menuItems = data.menuItems || [];
    return `<section class="bg-surface-container-low p-4 rounded-xl border border-outline-variant">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 class="font-title-lg text-title-lg">Custom Menu</h3>
          <p class="text-on-surface-variant text-sm">${menus.length} user-created custom menus from DB</p>
        </div>
        <button id="custom-menu-add" class="px-4 py-2 bg-primary text-on-primary rounded-lg font-label-md text-label-md flex items-center gap-2"><span class="material-symbols-outlined text-[18px]">add</span>Add Custom Menu</button>
      </div>
    </section>
    ${adminTable({
      id: "client-custom-menus-table",
      title: "Custom Menu Records",
      subtitle: "View, edit, or delete ready-made custom menus created by this user.",
      filters: [{ key: "type", label: "type", values: uniqueValues(menus, (menu) => menu.type) }],
      columns: [{ label: "Name", key: "name", width: "30%" }, { label: "Type", key: "type", width: "16%" }, { label: "Items", key: "items", width: "12%" }, { label: "Selected Items", key: "selected", width: "auto" }],
      rows: menus.map((menu) => customMenuRow(menu, menuItems)),
      empty: "No custom menus found for this user.",
      actionWidth: "120px",
    })}`;
  }

  function customMenuRow(menu, menuItems) {
    const selectedNames = customMenuItemNames(menu, menuItems);
    const encoded = encodeURIComponent(menu.id || "");
    return `<tr ${rowAttrs([menu.id, menu.name, menu.type, selectedNames.join(" ")].join(" "), { type: menu.type || "" })}>
      ${cell(`<div class="font-semibold">${escapeHtml(menu.name || "Untitled Custom Menu")}</div><p class="text-xs text-on-surface-variant">${escapeHtml(menu.id || "")}</p>`, "name")}
      ${cell(escapeHtml(menu.type || "-"), "type")}
      ${cell(String(asArray(menu.itemIds).length), "items", "font-bold")}
      ${cell(escapeHtml(selectedNames.slice(0, 8).join(", ") || "-") + (selectedNames.length > 8 ? `<span class="text-on-surface-variant"> +${selectedNames.length - 8} more</span>` : ""), "selected")}
      <td class="px-6 py-4 text-right whitespace-nowrap">
        <button class="custom-menu-view p-2 hover:bg-surface-container-highest rounded" data-id="${encoded}" title="View"><span class="material-symbols-outlined text-[18px]">visibility</span></button>
        <button class="custom-menu-edit p-2 hover:bg-surface-container-highest rounded" data-id="${encoded}" title="Edit"><span class="material-symbols-outlined text-[18px]">edit</span></button>
        <button class="custom-menu-delete p-2 hover:bg-error-container rounded text-error" data-id="${encoded}" title="Delete"><span class="material-symbols-outlined text-[18px]">delete</span></button>
      </td>
    </tr>`;
  }

  function customMenuModal(menu, data, mode = "edit") {
    const menuItems = data.menuItems || [];
    const selectedIds = new Set(asArray(menu.itemIds).map(String));
    const types = uniqueValues([{ type: "Breakfast" }, { type: "Juice" }, { type: "Lunch" }, { type: "Snack" }, { type: "Dinner" }, { type: "Others" }, ...(data.customMenus || [])], (item) => item.type);
    const readonly = mode === "view";
    return `<div id="custom-menu-modal" class="fixed inset-0 z-[100] bg-black/40 flex items-center justify-center p-6">
      <form id="custom-menu-form" class="w-full max-w-4xl bg-white rounded-xl border border-outline-variant shadow-xl overflow-hidden">
        <div class="px-6 py-4 border-b border-outline-variant flex items-center justify-between">
          <div>
            <h3 class="font-title-lg text-title-lg">${readonly ? "View" : menu.id ? "Edit" : "Add"} Custom Menu</h3>
            <p class="text-sm text-on-surface-variant">Ready-made menu group created by this CaterPro user.</p>
          </div>
          <button type="button" class="custom-menu-modal-close p-2 hover:bg-surface-container-highest rounded" title="Close"><span class="material-symbols-outlined">close</span></button>
        </div>
        <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-4 max-h-[70vh] overflow-y-auto">
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">ID</span><input name="id" ${readonly ? "readonly" : ""} class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(menu.id || "")}" placeholder="Auto generated if empty"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Type</span><select name="type" ${readonly ? "disabled" : ""} class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5">${types.map((type) => `<option value="${escapeHtml(type)}" ${selectedAttr(type, menu.type)}>${escapeHtml(type)}</option>`).join("")}<option value="__custom__">Custom type...</option></select></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">Name</span><input name="name" ${readonly ? "readonly" : ""} class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(menu.name || "")}"/></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">Custom Type</span><input name="customType" ${readonly ? "readonly" : ""} class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" placeholder="Use only if custom selected"/></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">Menu Items</span><select name="itemIds" multiple size="14" ${readonly ? "disabled" : ""} class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5">${menuItems.map((item) => {
            const label = item.title || [item.kannada, item.english].filter(Boolean).join(" / ") || item.english || item.id;
            return `<option value="${escapeHtml(item.id || "")}" ${selectedIds.has(String(item.id)) ? "selected" : ""}>${escapeHtml(label)}</option>`;
          }).join("")}</select></label>
        </div>
        <div class="px-6 py-4 border-t border-outline-variant flex justify-end gap-3">
          <button type="button" class="custom-menu-modal-close px-4 py-2 border border-outline-variant rounded-lg font-label-md text-label-md">${readonly ? "Close" : "Cancel"}</button>
          ${readonly ? "" : `<button type="submit" class="px-5 py-2 bg-primary text-on-primary rounded-lg font-label-md text-label-md flex items-center gap-2"><span class="material-symbols-outlined text-[18px]">save</span>Save Custom Menu</button>`}
        </div>
      </form>
    </div>`;
  }

  function openCustomMenuModal(menu, data, mode, onSave) {
    document.getElementById("custom-menu-modal")?.remove();
    document.body.insertAdjacentHTML("beforeend", customMenuModal(menu, data, mode));
    const modal = document.getElementById("custom-menu-modal");
    const form = document.getElementById("custom-menu-form");
    const close = () => modal?.remove();
    modal?.querySelectorAll(".custom-menu-modal-close").forEach((button) => button.addEventListener("click", close));
    modal?.addEventListener("click", (event) => { if (event.target === modal) close(); });
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const type = formData.get("type") === "__custom__" ? String(formData.get("customType") || "").trim() : String(formData.get("type") || "").trim();
      const itemIds = [...form.querySelectorAll('select[name="itemIds"] option:checked')].map((option) => option.value).filter(Boolean);
      await onSave({
        ...menu,
        id: String(formData.get("id") || menu.id || "").trim(),
        name: String(formData.get("name") || "").trim(),
        type,
        itemIds,
      });
      close();
    });
  }

  function wireClientCustomMenuActions(data) {
    const userId = data.user?.id || "";
    const menus = data.customMenus || [];
    const byId = new Map(menus.map((menu) => [String(menu.id), menu]));
    document.getElementById("custom-menu-add")?.addEventListener("click", () => {
      openCustomMenuModal({ id: "", name: "", type: "Breakfast", itemIds: [] }, data, "add", async (menu) => {
        await adminRequest(`/admin/users/${encodeURIComponent(userId)}/custom-menus`, { method: "POST", body: menu });
        location.reload();
      });
    });
    document.querySelectorAll(".custom-menu-view").forEach((button) => button.addEventListener("click", () => {
      const menu = byId.get(decodeURIComponent(button.dataset.id || ""));
      if (menu) openCustomMenuModal(menu, data, "view", async () => {});
    }));
    document.querySelectorAll(".custom-menu-edit").forEach((button) => button.addEventListener("click", () => {
      const menu = byId.get(decodeURIComponent(button.dataset.id || ""));
      if (!menu) return;
      openCustomMenuModal(menu, data, "edit", async (updated) => {
        await adminRequest(`/admin/users/${encodeURIComponent(userId)}/custom-menus/${encodeURIComponent(menu.id)}`, { method: "PUT", body: updated });
        location.reload();
      });
    }));
    document.querySelectorAll(".custom-menu-delete").forEach((button) => button.addEventListener("click", async () => {
      const menu = byId.get(decodeURIComponent(button.dataset.id || ""));
      if (!menu || !confirm(`Delete custom menu "${menu.name || menu.id}"?`)) return;
      await adminRequest(`/admin/users/${encodeURIComponent(userId)}/custom-menus/${encodeURIComponent(menu.id)}`, { method: "DELETE" });
      location.reload();
    }));
  }

  function clientEmployeesBody(data) {
    const employees = data.employees || [];
    return adminTable({
      id: "client-employees-table",
      title: "Employees",
      subtitle: `${employees.length} employees from DB`,
      filters: [{ key: "designation", label: "designation", values: uniqueValues(employees, (emp) => emp.designation) }],
      columns: [{ label: "Employee", key: "employee", width: "28%" }, { label: "Designation", key: "designation", width: "24%" }, { label: "Mobile", key: "mobile", width: "18%" }, { label: "Pay / Day", key: "payDay", align: "text-right", width: "14%" }, { label: "Pay / Hour", key: "payHour", align: "text-right", width: "14%" }],
      rows: employees.map((emp) => `<tr ${rowAttrs([emp.name, emp.designation, emp.mobile].join(" "), { designation: emp.designation || "" })}>
        ${cell(`<div class="font-semibold">${escapeHtml(emp.name || "-")}</div>`, "employee")}
        ${cell(escapeHtml(emp.designation || "-"), "designation")}
        ${cell(escapeHtml(emp.mobile || "-"), "mobile")}
        ${cell(formatMoney(emp.payPerDay), "payDay", "text-right")}
        ${cell(formatMoney(emp.payPerHour), "payHour", "text-right")}
        <td class="px-6 py-4 text-right whitespace-nowrap">${iconButton("info", "Employee info")}${iconButton("edit", "Edit employee")}${iconButton("block", "Disable employee", "text-error hover:bg-error-container")}</td>
      </tr>`),
      empty: "No employees found for this user.",
      actionWidth: "120px",
    });
  }

  function clientReportsBody(data) {
    const reports = data.reports || {};
    const rows = [
      { metric: "Revenue", value: reports.totalRevenue, formatted: formatMoney(reports.totalRevenue), group: "Financial" },
      { metric: "Pending", value: reports.pendingPayment, formatted: formatMoney(reports.pendingPayment), group: "Financial" },
      { metric: "Orders", value: reports.monthlyOrders, formatted: String(reports.monthlyOrders || 0), group: "Operations" },
      { metric: "Invoices", value: reports.invoiceCount, formatted: String(reports.invoiceCount || 0), group: "Billing" },
    ];
    return adminTable({
      id: "client-reports-table",
      title: "Reports",
      subtitle: "Report metrics generated from the client DB state.",
      filters: [{ key: "group", label: "group", values: uniqueValues(rows, (row) => row.group) }],
      columns: [{ label: "Metric", key: "metric", width: "42%" }, { label: "Group", key: "group", width: "28%" }, { label: "Value", key: "value", align: "text-right", width: "20%" }],
      rows: rows.map((row) => `<tr ${rowAttrs([row.metric, row.group, row.formatted].join(" "), { group: row.group })}>
        ${cell(`<div class="font-semibold">${escapeHtml(row.metric)}</div>`, "metric")}
        ${cell(escapeHtml(row.group), "group")}
        ${cell(escapeHtml(row.formatted), "value", "text-right font-bold")}
        <td class="px-6 py-4 text-right whitespace-nowrap">${iconButton("info", "Report info")}${iconButton("download", "Export report")}</td>
      </tr>`),
      empty: "No report metrics found for this user.",
      actionWidth: "96px",
    });
  }

  function clientAuditBody(data) {
    const logs = data.auditLogs || [];
    return adminTable({
      id: "client-audit-table",
      title: "Audit Activity",
      subtitle: `${logs.length} audit records from DB`,
      filters: [
        { key: "action", label: "action", values: uniqueValues(logs, (log) => log.action) },
        { key: "entity", label: "entity", values: uniqueValues(logs, (log) => log.entityType || log.entity) },
      ],
      columns: [{ label: "Time", key: "time", width: "16%" }, { label: "Action", key: "action", width: "18%" }, { label: "Entity", key: "entity", width: "18%" }, { label: "Details", key: "details", width: "auto" }],
      rows: logs.map((log) => {
        const entity = log.entityType || log.entity || "-";
        const details = log.message || log.details || log.entityId || "-";
        return `<tr ${rowAttrs([log.createdAt, log.updatedAt, log.action, entity, details].join(" "), { action: log.action || "", entity })}>
          ${cell(formatDate(log.createdAt || log.updatedAt), "time")}
          ${cell(escapeHtml(log.action || "-"), "action")}
          ${cell(escapeHtml(entity), "entity")}
          ${cell(escapeHtml(details), "details")}
          <td class="px-6 py-4 text-right whitespace-nowrap">${iconButton("info", "Audit info")}</td>
        </tr>`;
      }),
      empty: "No audit activity found for this user.",
      actionWidth: "80px",
    });
  }

  async function renderSubscriptions() {
    const users = await adminFetch("/admin/users");
    setMainContent(`<div class="p-container_padding space-y-gutter">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex flex-wrap gap-3">
          <input id="admin-subscription-search" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2 min-w-[320px]" placeholder="Search client, plan, billing, status"/>
          <select id="admin-subscription-plan-filter" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2">
            <option value="">All plans</option>
            ${[...new Set(users.map((user) => user.plan).filter(Boolean))].sort().map((plan) => `<option value="${escapeHtml(plan)}">${escapeHtml(plan)}</option>`).join("")}
          </select>
          <select id="admin-subscription-status-filter" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2">
            <option value="">All status</option>
            ${[...new Set(users.map((user) => user.subscriptionStatus || user.status).filter(Boolean))].sort().map((status) => `<option value="${escapeHtml(status)}">${escapeHtml(status)}</option>`).join("")}
          </select>
          <select id="admin-subscription-cycle-filter" class="bg-surface-container-lowest border border-outline-variant rounded-lg px-4 py-2">
            <option value="">All billing cycles</option>
            ${[...new Set(users.map((user) => user.billingCycle).filter(Boolean))].sort().map((cycle) => `<option value="${escapeHtml(cycle)}">${escapeHtml(cycle)}</option>`).join("")}
          </select>
        </div>
        <span class="text-xs font-label-sm text-on-surface-variant">${users.length} subscriptions from DB</span>
      </div>
      <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
        <div class="overflow-x-auto">
          <table class="w-full text-left min-w-[1200px]">
            <thead><tr class="bg-surface-container-low/50 border-b border-outline-variant">${subscriptionHeader("Client", "businessName")}${subscriptionHeader("Plan", "plan")}${subscriptionHeader("Status", "subscriptionStatus")}${subscriptionHeader("Billing Cycle", "billingCycle")}${subscriptionHeader("Next Renewal", "nextRenewal")}${subscriptionHeader("Earning", "totalEarning", "text-right")}${subscriptionHeader("Pending", "pendingPayment", "text-right")}<th class="px-6 py-4 text-right">Actions</th></tr></thead>
            <tbody id="admin-subscription-rows" class="divide-y divide-outline-variant/30"></tbody>
          </table>
        </div>
      </section>
    </div>`);
    const search = document.getElementById("admin-subscription-search");
    const planFilter = document.getElementById("admin-subscription-plan-filter");
    const statusFilter = document.getElementById("admin-subscription-status-filter");
    const cycleFilter = document.getElementById("admin-subscription-cycle-filter");
    const rows = document.getElementById("admin-subscription-rows");
    const state = { sortKey: "businessName", sortDirection: "asc" };
    const renderRows = () => {
      const query = (search?.value || "").toLowerCase();
      const plan = planFilter?.value || "";
      const status = statusFilter?.value || "";
      const cycle = cycleFilter?.value || "";
      const filtered = users.filter((user) => {
        const subscriptionStatus = user.subscriptionStatus || user.status || "";
        const searchText = [user.businessName, user.ownerName, user.email, user.phone, user.plan, subscriptionStatus, user.billingCycle, user.nextRenewal].join(" ").toLowerCase();
        return (!query || searchText.includes(query)) && (!plan || user.plan === plan) && (!status || subscriptionStatus === status) && (!cycle || user.billingCycle === cycle);
      }).sort((a, b) => compareClientValues(subscriptionSortValue(a, state.sortKey), subscriptionSortValue(b, state.sortKey), state.sortDirection));
      rows.innerHTML = filtered.length ? filtered.map(subscriptionRow).join("") : `<tr><td class="px-6 py-6 text-on-surface-variant" colspan="8">No subscriptions match the selected filters.</td></tr>`;
      wireSubscriptionActions(users);
    };
    document.querySelectorAll("[data-subscription-sort]").forEach((header) => {
      header.addEventListener("click", () => {
        const key = header.dataset.subscriptionSort;
        state.sortDirection = state.sortKey === key && state.sortDirection === "asc" ? "desc" : "asc";
        state.sortKey = key;
        document.querySelectorAll("[data-subscription-sort-icon]").forEach((icon) => { icon.textContent = "unfold_more"; });
        const icon = header.querySelector("[data-subscription-sort-icon]");
        if (icon) icon.textContent = state.sortDirection === "asc" ? "arrow_upward" : "arrow_downward";
        renderRows();
      });
    });
    [search, planFilter, statusFilter, cycleFilter].forEach((control) => control?.addEventListener("input", renderRows));
    renderRows();
  }

  function subscriptionHeader(label, key, align = "") {
    return `<th class="px-6 py-4 ${align}"><button class="inline-flex items-center gap-1 font-bold hover:text-primary" data-subscription-sort="${key}">${label}<span class="material-symbols-outlined text-[17px]" data-subscription-sort-icon>${key === "businessName" ? "arrow_upward" : "unfold_more"}</span></button></th>`;
  }

  function subscriptionSortValue(user, key) {
    if (key === "subscriptionStatus") return user.subscriptionStatus || user.status || "";
    return user[key];
  }

  function subscriptionRow(user) {
    const subscriptionStatus = user.subscriptionStatus || user.status || "Active";
    const disabled = String(subscriptionStatus).toLowerCase() === "disabled";
    return `<tr class="hover:bg-surface-bright transition-colors ${disabled ? "opacity-65 bg-surface-container-low/50" : ""}">
      <td class="px-6 py-4"><div class="flex items-center gap-3"><div class="w-9 h-9 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-bold">${initials(user.businessName)}</div><div><p class="font-bold">${escapeHtml(user.businessName)}</p><p class="text-xs text-on-surface-variant">${escapeHtml(user.email || "")}</p></div></div></td>
      <td class="px-6 py-4"><span class="px-2 py-0.5 rounded bg-primary-container text-on-primary-container text-[11px] font-bold uppercase">${escapeHtml(user.plan || "-")}</span></td>
      <td class="px-6 py-4"><span class="px-2 py-1 rounded-full ${disabled ? "bg-error-container text-on-error-container" : "bg-secondary-container text-on-secondary-container"} text-[11px] font-bold">${escapeHtml(subscriptionStatus)}</span></td>
      <td class="px-6 py-4">${escapeHtml(user.billingCycle || "-")}</td>
      <td class="px-6 py-4">${formatDate(user.nextRenewal)}</td>
      <td class="px-6 py-4 text-right font-bold">${formatMoney(user.totalEarning)}</td>
      <td class="px-6 py-4 text-right text-error">${formatMoney(user.pendingPayment)}</td>
      <td class="px-6 py-4 text-right">
        <div class="inline-flex gap-1">
          <a class="p-2 inline-flex hover:bg-surface-container-highest rounded text-on-surface-variant" title="Subscription info" href="${clientTabHref("client-detail.html", user.id)}"><span class="material-symbols-outlined text-[18px]">info</span></a>
          <button class="subscription-change p-2 inline-flex hover:bg-surface-container-highest rounded text-on-surface-variant" data-id="${escapeHtml(user.id)}" title="Change subscription"><span class="material-symbols-outlined text-[18px]">edit_calendar</span></button>
          <button class="subscription-disable p-2 inline-flex hover:bg-error-container rounded ${disabled ? "text-primary" : "text-error"}" data-id="${escapeHtml(user.id)}" title="${disabled ? "Enable subscription" : "Disable subscription"}"><span class="material-symbols-outlined text-[18px]">${disabled ? "toggle_on" : "block"}</span></button>
        </div>
      </td>
    </tr>`;
  }

  function wireSubscriptionActions(users) {
    const byId = new Map(users.map((user) => [String(user.id), user]));
    document.querySelectorAll(".subscription-change").forEach((button) => button.addEventListener("click", async () => {
      const user = byId.get(button.dataset.id || "");
      if (!user) return;
      const plan = prompt("Plan", user.plan || "Monthly");
      if (plan === null) return;
      const subscriptionStatus = prompt("Subscription status", user.subscriptionStatus || user.status || "Active");
      if (subscriptionStatus === null) return;
      const billingCycle = prompt("Billing cycle", user.billingCycle || "");
      if (billingCycle === null) return;
      const nextRenewal = prompt("Next renewal date (YYYY-MM-DD)", user.nextRenewal || "");
      if (nextRenewal === null) return;
      await adminRequest(`/admin/users/${encodeURIComponent(user.id)}`, {
        method: "PUT",
        body: { plan, subscriptionStatus, billingCycle, nextRenewal },
      });
      location.reload();
    }));
    document.querySelectorAll(".subscription-disable").forEach((button) => button.addEventListener("click", async () => {
      const user = byId.get(button.dataset.id || "");
      if (!user) return;
      const currentStatus = user.subscriptionStatus || user.status || "Active";
      const disabled = String(currentStatus).toLowerCase() === "disabled";
      const nextStatus = disabled ? "Active" : "Disabled";
      if (!confirm(`${nextStatus === "Disabled" ? "Disable" : "Enable"} subscription for ${user.businessName || user.email}?`)) return;
      await adminRequest(`/admin/users/${encodeURIComponent(user.id)}`, {
        method: "PUT",
        body: { subscriptionStatus: nextStatus },
      });
      location.reload();
    }));
  }

  async function renderPlans() {
    const overview = await adminFetch("/admin/overview");
    const plans = [
      {
        name: "Monthly",
        price: 999,
        cycle: "per month",
        badge: "Starter",
        description: "Flexible month-to-month access for caterers who want to start using CaterPro without a long commitment.",
        benefits: ["Client and event management", "Menu, quotation, and invoice tools", "PDF and WhatsApp sharing", "Online sync with local app data"],
      },
      {
        name: "6 Months",
        price: 3999,
        cycle: "for 6 months",
        badge: "Best Value",
        featured: true,
        description: "Reduced pricing for active teams that use CaterPro through regular catering seasons.",
        benefits: ["Everything in Monthly", "Priority operational support", "Admin dashboard visibility", "Better value for recurring usage"],
      },
      {
        name: "Annual",
        price: 5999,
        cycle: "per year",
        badge: "Growth",
        description: "Annual access for established kitchens that want predictable yearly billing.",
        benefits: ["Everything in 6 Months", "Long-term data continuity", "Full-year subscription tracking", "Lowest monthly equivalent cost"],
      },
    ];
    const totalUsers = overview.totals?.users || 0;
    setMainContent(`<div class="p-container_padding max-w-[1600px] mx-auto space-y-gutter">
      <section class="bg-white border border-outline-variant rounded-xl p-6">
        <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
          <div>
            <h2 class="font-display-lg text-display-lg text-on-surface">Plans</h2>
            <p class="text-on-surface-variant mt-1">Subscription plans available for CaterPro customers. Feature segregation can be adjusted later from this structure.</p>
          </div>
          <div class="px-4 py-2 rounded-lg bg-primary-container text-on-primary-container font-label-md text-label-md">${totalUsers} active client${totalUsers === 1 ? "" : "s"}</div>
        </div>
      </section>
      <section class="grid grid-cols-1 lg:grid-cols-3 gap-gutter">
        ${plans.map(planCard).join("")}
      </section>
      <section class="bg-white border border-outline-variant rounded-xl overflow-hidden">
        <div class="p-6 border-b border-outline-variant">
          <h3 class="font-title-lg text-title-lg">Common Benefits</h3>
          <p class="text-on-surface-variant text-sm mt-1">All plans currently include the same core CaterPro access. Exact feature limits can be separated later.</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left min-w-[900px]">
            <thead class="bg-surface-container">
              <tr><th class="px-6 py-4">Benefit</th><th class="px-6 py-4">Monthly</th><th class="px-6 py-4">6 Months</th><th class="px-6 py-4">Annual</th></tr>
            </thead>
            <tbody class="divide-y divide-outline-variant/30">
              ${["Events, clients, and billing", "Menu and inventory data", "PDF exports and WhatsApp sharing", "Online sync and admin visibility", "Future feature segregation ready"].map((benefit) => `<tr><td class="px-6 py-4 font-semibold">${benefit}</td><td class="px-6 py-4 text-primary"><span class="material-symbols-outlined text-[18px] align-middle">check_circle</span></td><td class="px-6 py-4 text-primary"><span class="material-symbols-outlined text-[18px] align-middle">check_circle</span></td><td class="px-6 py-4 text-primary"><span class="material-symbols-outlined text-[18px] align-middle">check_circle</span></td></tr>`).join("")}
            </tbody>
          </table>
        </div>
      </section>
    </div>`);
  }

  function planCard(plan) {
    return `<article class="relative bg-white border ${plan.featured ? "border-primary shadow-lg shadow-primary/10" : "border-outline-variant"} rounded-xl p-6 flex flex-col min-h-[430px]">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h3 class="font-headline-md text-headline-md text-on-surface">${escapeHtml(plan.name)}</h3>
          <p class="text-on-surface-variant mt-2">${escapeHtml(plan.description)}</p>
        </div>
        <span class="shrink-0 px-2.5 py-1 rounded-full ${plan.featured ? "bg-primary text-on-primary" : "bg-secondary-container text-on-secondary-container"} text-[11px] font-bold uppercase tracking-wider">${escapeHtml(plan.badge)}</span>
      </div>
      <div class="mt-6">
        <span class="font-display-lg text-display-lg text-on-surface">\u20B9${Number(plan.price).toLocaleString("en-IN")}</span>
        <span class="text-on-surface-variant ml-2">${escapeHtml(plan.cycle)}</span>
      </div>
      <div class="mt-6 pt-6 border-t border-outline-variant space-y-3 flex-1">
        ${plan.benefits.map((benefit) => `<div class="flex gap-3"><span class="material-symbols-outlined text-primary text-[20px]">check_circle</span><span class="text-on-surface-variant">${escapeHtml(benefit)}</span></div>`).join("")}
      </div>
      <button class="mt-6 w-full px-4 py-2.5 rounded-lg ${plan.featured ? "bg-primary text-on-primary" : "border border-outline-variant text-on-surface hover:bg-surface-container-low"} font-label-md text-label-md transition-colors">Manage Plan</button>
    </article>`;
  }

  async function renderAuditLog() {
    const logs = await adminFetch("/admin/audit-logs");
    setMainContent(`<div class="p-container_padding space-y-gutter">${simpleTable(["Time", "User", "Action", "Entity", "Details"], logs.map(log => `<tr><td class="px-6 py-4">${formatDate(log.createdAt || log.updatedAt)}</td><td class="px-6 py-4">${escapeHtml(log.userName || log.userEmail)}</td><td class="px-6 py-4">${escapeHtml(log.action || "-")}</td><td class="px-6 py-4">${escapeHtml(log.entityType || log.entity || "-")}</td><td class="px-6 py-4">${escapeHtml(log.message || log.details || log.entityId || "-")}</td></tr>`), "No audit logs found in DB.")}</div>`);
  }

  async function renderSettings() {
    const overview = await adminFetch("/admin/overview");
    setMainContent(`<div class="p-container_padding"><section class="bg-white border border-outline-variant rounded-xl p-6 space-y-4"><h2 class="font-title-lg text-title-lg">Settings</h2><div class="flex justify-between"><span class="text-on-surface-variant">API Base</span><span class="font-data-mono text-data-mono">${escapeHtml(apiBase())}</span></div><div class="flex justify-between"><span class="text-on-surface-variant">Supabase State</span><span class="font-data-mono text-data-mono">${escapeHtml(overview.storage?.stateId || "")}</span></div><div class="flex justify-between"><span class="text-on-surface-variant">Admin</span><span>${escapeHtml(overview.admin?.email || "")}</span></div></section></div>`);
  }

  async function renderAdminProfile() {
    const profile = await adminFetch("/admin/profile");
    setMainContent(`<div class="p-container_padding max-w-[1200px] mx-auto space-y-gutter">
      <section class="bg-white border border-outline-variant rounded-xl p-6">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-5">
          <div class="flex items-center gap-4">
            <div class="w-16 h-16 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center text-headline-sm font-bold">${initials(profile.name || profile.email)}</div>
            <div>
              <h2 class="font-display-lg text-display-lg text-on-surface">Admin Profile</h2>
              <p class="text-on-surface-variant">${escapeHtml(profile.email || "")}</p>
            </div>
          </div>
          <span class="px-3 py-1 rounded-full bg-secondary-container text-on-secondary-container text-[11px] font-bold uppercase tracking-wider">${escapeHtml(profile.status || "Active")}</span>
        </div>
      </section>
      <form id="admin-profile-form" class="bg-white border border-outline-variant rounded-xl overflow-hidden">
        <div class="px-6 py-4 border-b border-outline-variant">
          <h3 class="font-title-lg text-title-lg">Profile Information</h3>
          <p class="text-sm text-on-surface-variant">Changes are saved to the CaterPro DB admin user record.</p>
        </div>
        <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-5">
          ${profileField("Full Name", "name", profile.name)}
          ${profileField("Email Address", "email", profile.email, "email")}
          ${profileField("Phone", "phone", profile.phone)}
          ${profileField("Designation", "designation", profile.designation)}
          ${profileField("Avatar URL", "avatarUrl", profile.avatarUrl)}
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Status</span><select name="status" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5"><option value="Active" ${selectedAttr(profile.status || "Active", "Active")}>Active</option><option value="Disabled" ${selectedAttr(profile.status, "Disabled")}>Disabled</option></select></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">New Password</span><input name="password" type="password" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" placeholder="Leave blank to keep current password"/></label>
        </div>
        <div class="px-6 py-4 border-t border-outline-variant flex items-center justify-between gap-4">
          <p id="admin-profile-state" class="text-sm text-on-surface-variant"></p>
          <button type="submit" class="px-5 py-2.5 bg-primary text-on-primary rounded-lg font-label-md text-label-md flex items-center gap-2"><span class="material-symbols-outlined text-[18px]">save</span>Update Profile</button>
        </div>
      </form>
    </div>`);
    wireAdminProfileForm();
  }

  function profileField(label, name, value, type = "text") {
    return `<label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">${label}</span><input name="${name}" type="${type}" class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="${escapeHtml(value || "")}"/></label>`;
  }

  function wireAdminProfileForm() {
    const form = document.getElementById("admin-profile-form");
    const state = document.getElementById("admin-profile-state");
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const body = Object.fromEntries(["name", "email", "phone", "designation", "avatarUrl", "status", "password"].map((key) => [key, String(formData.get(key) || "").trim()]));
      if (!body.password) delete body.password;
      if (state) state.textContent = "Saving profile...";
      try {
        const updated = await adminRequest("/admin/profile", { method: "PUT", body });
        localStorage.setItem("caterpro.admin.email", updated.email || "");
        if (state) {
          state.className = "text-sm text-primary";
          state.textContent = "Profile updated";
        }
      } catch (error) {
        if (state) {
          state.className = "text-sm text-error";
          state.textContent = error.message;
        }
      }
    });
  }

  async function hydrateAdminData() {
    const page = location.pathname.split("/").pop() || "dashboard.html";
    if (page === "login.html") return;
    if (!localStorage.getItem("caterpro.admin.token")) {
      goToPage("login.html");
      return;
    }
    try {
      if (page === "dashboard.html") return await renderDashboard();
      if (page === "clients.html") return await renderClients();
      if (page === "subscriptions.html") return await renderSubscriptions();
      if (page === "plans.html") return await renderPlans();
      if (page === "audit-log.html") return await renderAuditLog();
      if (page === "settings.html") return await renderSettings();
      if (page === "admin-profile.html") return await renderAdminProfile();
      const clientPages = {
        "client-detail.html": "details",
        "client-events.html": "events",
        "client-billing.html": "billing",
        "client-menu.html": "menu",
        "client-custom-menus.html": "customMenus",
        "client-employees.html": "employees",
        "client-reports.html": "reports",
        "client-audit.html": "audit",
      };
      if (clientPages[page]) return await renderClientPage(clientPages[page]);
    } catch (error) {
      showAdminState(`Unable to load real DB data: ${error.message}`);
    }
  }

  window.addEventListener("DOMContentLoaded", () => {
    wireNavigation();
    syncActiveNavigation();
    wireClientDetailTabs();
    wireLogin();
    wireActionButtons();
    wireClientRows();
    wireDetailFallbacks();
    replaceSidebarBrandLogo();
    replaceSimpleSidebarTitle();
    replaceLoginLogo();
    removeDuplicateSidebarLogos();
    hydrateAdminData();
  });
})();

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const pagesDir = path.join(root, "pages");
const sourcePath = path.join(pagesDir, "client-detail.html");
const source = fs.readFileSync(sourcePath, "utf8");
const beforeMainContent = source.split("<!-- Page Canvas -->")[0];
const afterMainContent = source.slice(source.lastIndexOf("</main>"));

const tabs = [
  ["Client Details", "client-detail.html", "details"],
  ["Events", "client-events.html", "events"],
  ["Quotations & Invoices", "client-billing.html", "billing"],
  ["Menu Items", "client-menu.html", "menu"],
  ["Employees", "client-employees.html", "employees"],
  ["Reports", "client-reports.html", "reports"],
  ["Audit Activity", "client-audit.html", "audit"],
];

function iconStat(icon, label, value, tone = "primary") {
  const tones = {
    primary: "bg-primary-container/30 text-primary",
    secondary: "bg-secondary-container/30 text-on-secondary-container",
    error: "bg-error-container/30 text-error",
    healthy: "bg-secondary-fixed/30 text-on-secondary-fixed-variant",
  };
  return `
<div class="bg-white border border-outline-variant p-5 rounded-2xl flex items-center gap-4">
  <div class="w-12 h-12 rounded-full ${tones[tone]} flex items-center justify-center">
    <span class="material-symbols-outlined">${icon}</span>
  </div>
  <div>
    <p class="text-xs text-on-surface-variant font-label-sm">${label}</p>
    <h3 class="text-xl font-bold">${value}</h3>
  </div>
</div>`;
}

function clientHeader(activeKey) {
  const tabMarkup = tabs
    .map(([label, href, key]) => {
      const active = key === activeKey;
      return `<a class="pb-3 border-b-2 ${active ? "border-primary text-primary font-bold" : "border-transparent text-on-surface-variant hover:text-primary"} transition-all flex items-center gap-2 whitespace-nowrap" href="${href}">${label}</a>`;
    })
    .join("\n");

  return `
<!-- Page Canvas -->
<div class="p-container_padding max-w-[1600px] mx-auto space-y-gutter">
  <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
    <div class="flex items-start gap-5 min-w-0">
      <div class="w-20 h-20 rounded-2xl bg-white border border-outline-variant shadow-sm flex items-center justify-center overflow-hidden shrink-0">
        <img class="w-full h-full object-contain p-2" alt="CaterPro" src="../assets/caterpro_logo.png"/>
      </div>
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-3 mb-1">
          <h1 class="font-display-lg text-display-lg text-on-surface">Malnad Kitchen</h1>
          <span class="px-2.5 py-0.5 rounded-full bg-primary-container text-on-primary-container text-[11px] font-bold uppercase tracking-wider">Pro</span>
          <span class="px-2.5 py-0.5 rounded-full bg-secondary-container text-on-secondary-container text-[11px] font-bold uppercase tracking-wider">Active</span>
        </div>
        <p class="text-on-surface-variant font-body-md flex items-center gap-2">
          <span class="material-symbols-outlined text-base">mail</span>
          admin@malnadkitchen.com
        </p>
      </div>
    </div>
    <div class="flex gap-3">
      <button class="px-5 py-2.5 border border-outline-variant rounded-lg font-label-md text-label-md hover:bg-white transition-all flex items-center gap-2">
        <span class="material-symbols-outlined text-lg">edit</span> Edit Client
      </button>
      <button class="px-5 py-2.5 bg-primary text-on-primary rounded-lg font-label-md text-label-md hover:bg-primary/90 transition-all flex items-center gap-2 shadow-md shadow-primary/20">
        <span class="material-symbols-outlined text-lg">add_circle</span> New Order
      </button>
    </div>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
    ${iconStat("payments", "Total Earning", "₹12,00,000", "secondary")}
    ${iconStat("pending_actions", "Pending Payment", "₹45,000", "error")}
    ${iconStat("receipt", "Total Orders", "154", "primary")}
    <div class="bg-white border border-outline-variant p-5 rounded-2xl flex items-center gap-4">
      <div class="w-12 h-12 rounded-full bg-secondary-fixed/30 flex items-center justify-center text-on-secondary-fixed-variant">
        <span class="material-symbols-outlined">sync_saved_locally</span>
      </div>
      <div>
        <p class="text-xs text-on-surface-variant font-label-sm">Sync Status</p>
        <div class="flex items-center gap-2">
          <h3 class="text-xl font-bold">Healthy</h3>
          <span class="w-2 h-2 rounded-full bg-secondary"></span>
        </div>
      </div>
    </div>
  </div>

  <nav class="border-b border-outline-variant flex gap-8 overflow-x-auto scrollbar-hide">
    ${tabMarkup}
  </nav>
`;
}

function table(actions = true) {
  return actions
    ? `<div class="flex items-center justify-end gap-2">
        <button class="p-2 text-on-surface-variant hover:bg-surface-container rounded-lg transition-colors" title="Edit"><span class="material-symbols-outlined text-[20px]">edit</span></button>
        <button class="p-2 text-error hover:bg-error-container rounded-lg transition-colors" title="Delete"><span class="material-symbols-outlined text-[20px]">delete</span></button>
      </div>`
    : "";
}

const details = `
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2 space-y-6">
      <section class="bg-white rounded-2xl border border-outline-variant overflow-hidden">
        <div class="px-6 py-4 border-b border-outline-variant bg-surface-container-low/30">
          <h4 class="font-title-lg text-title-lg">User Profile</h4>
        </div>
        <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-6">
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Full Name</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="Rajesh Hegde"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Primary Email</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="admin@malnadkitchen.com"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Phone Number</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="+91 98765 43210"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Designation</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="Managing Director"/></label>
        </div>
      </section>
      <section class="bg-white rounded-2xl border border-outline-variant overflow-hidden">
        <div class="px-6 py-4 border-b border-outline-variant bg-surface-container-low/30">
          <h4 class="font-title-lg text-title-lg">Business Details</h4>
        </div>
        <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-6">
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">GSTIN Number</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="29AABCM1234F1Z5"/></label>
          <label class="space-y-1.5"><span class="text-label-sm font-label-sm text-on-surface-variant">Bank Account Number</span><input class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" value="50200012345678"/></label>
          <label class="space-y-1.5 md:col-span-2"><span class="text-label-sm font-label-sm text-on-surface-variant">Business Address</span><textarea class="w-full border-outline-variant rounded-lg bg-surface-bright px-4 py-2.5" rows="3">#42, 2nd Floor, Malnad Heights, Jayanagar 4th Block, Bengaluru, Karnataka 560011</textarea></label>
        </div>
      </section>
    </div>
    <div class="space-y-6">
      <section class="bg-white p-6 rounded-2xl border border-outline-variant shadow-sm space-y-4">
        <h4 class="font-label-md font-bold uppercase tracking-wider text-on-surface-variant">Operational Snapshot</h4>
        <div class="flex justify-between"><span class="text-sm text-on-surface-variant">Active Subscriptions</span><span class="font-bold">Pro Yearly</span></div>
        <div class="flex justify-between"><span class="text-sm text-on-surface-variant">Billing Cycle</span><span class="font-bold">Aug 2024 - Jul 2025</span></div>
        <div class="flex justify-between"><span class="text-sm text-on-surface-variant">Next Renewal</span><span class="text-secondary font-bold">342 Days left</span></div>
        <div class="h-px bg-outline-variant/30"></div>
        <div class="flex justify-between items-center"><span class="text-sm text-on-surface-variant">Order Volume</span><div class="w-24 h-2 bg-surface-container-highest rounded-full overflow-hidden"><div class="bg-primary h-full w-[78%]"></div></div></div>
      </section>
      <section class="bg-white rounded-2xl border border-outline-variant overflow-hidden shadow-sm">
        <div class="h-40 bg-surface-container-high flex items-center justify-center text-primary"><span class="material-symbols-outlined text-5xl">map</span></div>
        <div class="p-4 flex items-center justify-between"><span class="font-label-sm text-label-sm text-on-surface-variant">Verified on Google Maps</span><button class="text-primary font-label-md text-label-md">Update Location</button></div>
      </section>
    </div>
  </div>
</div>`;

const events = `
  <section class="bg-surface-container-low p-4 rounded-xl border border-outline-variant">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <label class="space-y-1"><span class="font-label-sm text-label-sm text-on-surface-variant">Search Events</span><input class="w-full bg-white border border-outline-variant rounded-lg py-2 px-3" placeholder="Event name or venue"/></label>
      <label class="space-y-1"><span class="font-label-sm text-label-sm text-on-surface-variant">Date Range</span><input class="w-full bg-white border border-outline-variant rounded-lg py-2 px-3" placeholder="Select dates"/></label>
      <label class="space-y-1"><span class="font-label-sm text-label-sm text-on-surface-variant">Status</span><select class="w-full bg-white border border-outline-variant rounded-lg py-2 px-3"><option>All Statuses</option><option>Confirmed</option><option>Completed</option></select></label>
      <div class="flex items-end gap-2"><button class="flex-1 border border-outline-variant py-2 rounded-lg">Reset</button><button class="flex-1 bg-primary text-on-primary py-2 rounded-lg">Apply</button></div>
    </div>
  </section>
  <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
    <table class="w-full text-left">
      <thead class="bg-surface-container-low border-b border-outline-variant"><tr><th class="px-6 py-4 font-label-sm text-label-sm uppercase">Event & Venue</th><th class="px-6 py-4 font-label-sm text-label-sm uppercase">Date</th><th class="px-6 py-4 font-label-sm text-label-sm uppercase">Status</th><th class="px-6 py-4 font-label-sm text-label-sm uppercase text-right">Total</th><th class="px-6 py-4 font-label-sm text-label-sm uppercase text-right">Actions</th></tr></thead>
      <tbody class="divide-y divide-outline-variant">
        ${["Send Off - Mr. Ramesh|Grand Palace Hall|Oct 24, 2026|Confirmed|₹45,000","Satyanarayana Pooje|Private Residence|Oct 15, 2026|Completed|₹12,500","Corporate Lunch|Malnad Kitchen HUB|Nov 02, 2026|Pending|₹62,000"].map((row) => {
          const [event, venue, date, status, total] = row.split("|");
          return `<tr class="hover:bg-surface-bright"><td class="px-6 py-4"><p class="font-title-lg text-label-md">${event}</p><p class="text-on-surface-variant text-body-sm">${venue}</p></td><td class="px-6 py-4">${date}</td><td class="px-6 py-4"><span class="px-3 py-1 rounded-full bg-secondary-container text-on-secondary-container font-label-sm text-label-sm">${status}</span></td><td class="px-6 py-4 text-right font-semibold">${total}</td><td class="px-6 py-4">${table()}</td></tr>`;
        }).join("")}
      </tbody>
    </table>
  </section>
</div>`;

const billing = `
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
    ${iconStat("receipt_long", "Total Billed", "₹4,25,000", "primary")}
    ${iconStat("schedule", "Outstanding", "₹62,450", "error")}
    ${iconStat("request_quote", "Active Quotations", "04", "secondary")}
    <button class="bg-primary-container text-on-primary-container p-6 rounded-xl border border-outline-variant flex flex-col items-center justify-center gap-1"><span class="material-symbols-outlined text-4xl">add_circle</span><span class="font-label-md">Generate Invoice</span></button>
  </div>
  <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
    <table class="w-full text-left">
      <thead class="bg-surface-container"><tr><th class="px-6 py-4">Type</th><th class="px-6 py-4">Doc #</th><th class="px-6 py-4">Date</th><th class="px-6 py-4">Total</th><th class="px-6 py-4">Status</th><th class="px-6 py-4 text-right">Actions</th></tr></thead>
      <tbody class="divide-y divide-outline-variant/30">
        ${["Invoice|INV-2026-0842|Oct 12, 2026|₹14,500|Overdue","Invoice|INV-2026-0791|Oct 05, 2026|₹28,200|Paid","Quotation|QTN-2026-112|Oct 24, 2026|₹8,450|Pending"].map((row) => {
          const [type, doc, date, total, status] = row.split("|");
          return `<tr class="hover:bg-surface-container-low"><td class="px-6 py-4">${type}</td><td class="px-6 py-4 font-data-mono text-data-mono">${doc}</td><td class="px-6 py-4">${date}</td><td class="px-6 py-4 font-semibold">${total}</td><td class="px-6 py-4"><span class="px-3 py-1 rounded-full bg-surface-container-highest">${status}</span></td><td class="px-6 py-4">${table()}</td></tr>`;
        }).join("")}
      </tbody>
    </table>
  </section>
</div>`;

const menu = `
  <section class="bg-surface-container-low p-4 rounded-xl border border-outline-variant">
    <div class="flex flex-wrap justify-between gap-4">
      <div class="relative min-w-[280px] flex-1"><span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant">search</span><input class="w-full bg-white border border-outline-variant rounded-lg py-2 pl-10 pr-4" placeholder="Search menu, vegetables, utensils"/></div>
      <button class="px-5 py-2.5 bg-primary text-on-primary rounded-lg font-label-md flex items-center gap-2"><span class="material-symbols-outlined">add</span>Add Item</button>
    </div>
  </section>
  <section class="grid grid-cols-1 lg:grid-cols-3 gap-4">
    ${["Menu Items|377|restaurant_menu","Vegetables|96|eco","Utensils|64|skillet"].map((item) => {
      const [title, count, icon] = item.split("|");
      return `<div class="bg-white border border-outline-variant rounded-2xl p-5 flex items-center gap-4"><div class="w-12 h-12 rounded-full bg-primary-container/30 text-primary flex items-center justify-center"><span class="material-symbols-outlined">${icon}</span></div><div><p class="text-on-surface-variant text-label-sm">${title}</p><h3 class="text-xl font-bold">${count}</h3></div></div>`;
    }).join("")}
  </section>
  <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
    <table class="w-full text-left"><thead class="bg-surface-container"><tr><th class="px-6 py-4">Name</th><th class="px-6 py-4">Category</th><th class="px-6 py-4">Visibility</th><th class="px-6 py-4 text-right">Actions</th></tr></thead><tbody class="divide-y divide-outline-variant/30">
      ${["Akki Rotti / ಅಕ್ಕಿ ರೊಟ್ಟಿ|South Indian|User Catalog","Paneer Pakoda / ಪನೀರ್ ಪಕೋಡ|Starter|User Catalog","Coffee Tea Cups|Utensil|User Catalog"].map((row) => { const [name, category, visibility] = row.split("|"); return `<tr><td class="px-6 py-4 font-semibold">${name}</td><td class="px-6 py-4">${category}</td><td class="px-6 py-4">${visibility}</td><td class="px-6 py-4">${table()}</td></tr>`; }).join("")}
    </tbody></table>
  </section>
</div>`;

const employees = `
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
    ${iconStat("groups", "Total Employees", "42", "primary")}
    ${iconStat("badge", "Active Staff", "36", "secondary")}
    ${iconStat("payments", "Monthly Payroll", "₹2,84,000", "primary")}
    ${iconStat("event_available", "Attendance Today", "31", "healthy")}
  </div>
  <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
    <table class="w-full text-left"><thead class="bg-surface-container"><tr><th class="px-6 py-4">Employee</th><th class="px-6 py-4">Role</th><th class="px-6 py-4">Mobile</th><th class="px-6 py-4">Status</th><th class="px-6 py-4 text-right">Actions</th></tr></thead><tbody class="divide-y divide-outline-variant/30">
      ${["Nagaraj|Chef|9845011111|Active","Lakshmi|Service Lead|9845022222|Active","Pradeep|Driver|9845033333|On Leave"].map((row) => { const [name, role, mobile, status] = row.split("|"); return `<tr><td class="px-6 py-4 font-semibold">${name}</td><td class="px-6 py-4">${role}</td><td class="px-6 py-4">${mobile}</td><td class="px-6 py-4"><span class="px-3 py-1 rounded-full bg-secondary-container text-on-secondary-container">${status}</span></td><td class="px-6 py-4">${table()}</td></tr>`; }).join("")}
    </tbody></table>
  </section>
</div>`;

const reports = `
  <section class="grid grid-cols-1 md:grid-cols-3 gap-4">
    ${["Monthly Revenue|Track paid, pending, and cancelled bill value.|bar_chart","Order Performance|Compare event volume by date range and menu type.|monitoring","Catalog Usage|See frequently used menu items and add-ons.|restaurant_menu"].map((row) => { const [title, body, icon] = row.split("|"); return `<div class="bg-white border border-outline-variant rounded-2xl p-6 space-y-4"><span class="material-symbols-outlined text-primary text-3xl">${icon}</span><div><h3 class="font-title-lg text-title-lg">${title}</h3><p class="text-on-surface-variant">${body}</p></div><div class="flex gap-2"><button class="px-4 py-2 bg-primary text-on-primary rounded-lg">Export PDF</button><button class="px-4 py-2 border border-outline-variant rounded-lg">CSV</button></div></div>`; }).join("")}
  </section>
  <section class="bg-white rounded-xl border border-outline-variant p-6">
    <h3 class="font-title-lg text-title-lg mb-4">Report Filters</h3>
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4"><input class="border border-outline-variant rounded-lg px-3 py-2" value="01 Jul 2026"/><input class="border border-outline-variant rounded-lg px-3 py-2" value="31 Jul 2026"/><select class="border border-outline-variant rounded-lg px-3 py-2"><option>All Events</option></select><button class="bg-primary text-on-primary rounded-lg">Run Report</button></div>
  </section>
</div>`;

const audit = `
  <section class="bg-surface-container-low p-4 rounded-xl border border-outline-variant">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4"><input class="bg-white border border-outline-variant rounded-lg py-2 px-3" placeholder="Search activity"/><select class="bg-white border border-outline-variant rounded-lg py-2 px-3"><option>All Modules</option><option>Events</option><option>Billing</option></select><input class="bg-white border border-outline-variant rounded-lg py-2 px-3" placeholder="Date range"/><button class="bg-primary text-on-primary rounded-lg">Apply</button></div>
  </section>
  <section class="bg-white rounded-xl border border-outline-variant overflow-hidden shadow-sm">
    <table class="w-full text-left"><thead class="bg-surface-container"><tr><th class="px-6 py-4">Time</th><th class="px-6 py-4">User</th><th class="px-6 py-4">Module</th><th class="px-6 py-4">Activity</th><th class="px-6 py-4 text-right">Actions</th></tr></thead><tbody class="divide-y divide-outline-variant/30">
      ${["31 Jul 2026, 10:42 AM|Rajesh Kumar|Billing|Updated invoice settlement","31 Jul 2026, 09:15 AM|Rajesh Kumar|Menu Items|Renamed menu item","30 Jul 2026, 06:20 PM|System|Sync|Online DB sync completed"].map((row) => { const [time, user, module, activity] = row.split("|"); return `<tr><td class="px-6 py-4">${time}</td><td class="px-6 py-4">${user}</td><td class="px-6 py-4">${module}</td><td class="px-6 py-4">${activity}</td><td class="px-6 py-4 text-right"><button class="px-3 py-1 border border-outline-variant rounded-lg">View Diff</button></td></tr>`; }).join("")}
    </tbody></table>
  </section>
</div>`;

const pageContent = {
  "client-detail.html": ["Client Details", "details", details],
  "client-events.html": ["Client Events", "events", events],
  "client-billing.html": ["Client Billing", "billing", billing],
  "client-menu.html": ["Client Menu Items", "menu", menu],
  "client-employees.html": ["Client Employees", "employees", employees],
  "client-reports.html": ["Client Reports", "reports", reports],
  "client-audit.html": ["Client Audit Activity", "audit", audit],
};

for (const [file, [title, activeKey, body]] of Object.entries(pageContent)) {
  const loadingBody = `
<div class="p-container_padding max-w-[1600px] mx-auto">
  <div class="rounded-xl border border-outline-variant bg-white p-6 text-on-surface-variant">
    Loading ${title.toLowerCase()} from CaterPro DB...
  </div>
</div>`;
  const html = (beforeMainContent + loadingBody + afterMainContent)
    .replace(/<title>.*?<\/title>/, `<title>CaterPro Admin - ${title}</title>`);
  fs.writeFileSync(path.join(pagesDir, file), html, "utf8");
}

const fs = require("fs");
const path = require("path");

const pagesDir = path.resolve(__dirname, "..", "pages");
const pages = [
  "dashboard.html",
  "clients.html",
  "subscriptions.html",
  "plans.html",
  "audit-log.html",
  "settings.html",
];

function placeholder(file) {
  const name = file.replace(".html", "").replace(/-/g, " ");
  return `
<div class="p-container_padding">
  <div class="rounded-xl border border-outline-variant bg-white p-6 text-on-surface-variant">
    Loading ${name} from CaterPro DB...
  </div>
</div>
`;
}

for (const file of pages) {
  const filePath = path.join(pagesDir, file);
  const html = fs.readFileSync(filePath, "utf8");
  const headerEnd = html.indexOf("</header>");
  const mainEnd = html.lastIndexOf("</main>");
  if (headerEnd === -1 || mainEnd === -1 || mainEnd <= headerEnd) {
    throw new Error(`Unable to find page shell in ${file}`);
  }
  const nextStart = headerEnd + "</header>".length;
  const stripped = `${html.slice(0, nextStart)}${placeholder(file)}${html.slice(mainEnd)}`;
  fs.writeFileSync(filePath, stripped, "utf8");
}


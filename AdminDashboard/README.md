# CaterPro Admin Dashboard

This folder contains everything related to the planned CaterPro Admin Dashboard.

The admin dashboard is intended to be separable from the mobile app later, so keep admin-only requirements, UI prompts, designs, backend notes, and future implementation files here.

Current contents:

- `requirements.md`: product requirements and full Stitch UI generation prompt.
- `index.html`: launcher page for the generated admin UI.
- `pages/`: generated standalone HTML screens copied from the Stitch UI exports.
- `assets/`: shared CaterPro logo plus small generated-dashboard CSS/JS helpers.
- `UI/`: original Stitch source folders with each screen's `screen.png` and `code.html`.

Local preview:

- Start a static server in this folder.
- Open `http://localhost:5178/` or `http://localhost:5178/pages/dashboard.html`.

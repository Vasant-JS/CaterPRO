# CaterPro Admin Dashboard Requirements

## Objective

Build a web admin dashboard for CaterPro operators to maintain the online database, user accounts, subscriptions, plans, client data, catalog data, events, invoices, menus, employees, reports, and audit history.

The admin dashboard is separate from the mobile catering app. It is an internal operations tool with one admin login, full edit access, and careful audit logging for every change.

## Primary Users

- Admin/operator: full access to all users, clients, subscriptions, plans, app data, settings, and audit logs.
- No multi-role UI is required for v1. The system should support only one admin login.

## Navigation

Use a persistent left side navbar with these options:

- Dashboard
- Clients
- Subscriptions
- Plans
- Audit Log
- Settings

The sidebar should include the CaterPro logo, environment badge, logged-in admin email, and logout action.

## Dashboard

The dashboard is the landing page after login.

Required cards:

- Total users
- Active users
- Trial users
- Expired users
- Active subscriptions
- Monthly recurring revenue
- Total client businesses
- Total events/orders
- Total invoices/quotations
- Pending payment value
- Sync health: last sync time, failed sync count, stale users

Required widgets:

- Revenue trend chart by month
- New users chart
- Subscription status distribution
- Recently active users table
- Recent audit activity
- Users with sync/data issues

Dashboard actions:

- Create user
- Export users CSV
- Open audit log
- Open settings

## Clients Page

This page manages CaterPro app users/business clients. The table should support search, filters, sorting, pagination, bulk selection, export, and row actions.

Table columns:

- Business/client name
- Owner/user name
- Email
- Mobile
- City
- Plan
- Subscription status
- Trial/renewal/expiry date
- Event count
- Invoice count
- Total earnings
- Pending amount
- Last sync
- Last login
- Created date
- Status
- Actions

Filters:

- Search by business name, owner name, email, mobile
- Plan
- Subscription status
- Active/inactive
- Trial/paid/expired
- Last sync range
- Created date range
- City
- Has pending payments
- Has sync issues

Row actions:

- Info/open profile
- Edit user
- Change subscription
- Reset password/send reset link
- Disable/enable login
- Export user data
- Import user data
- View audit log for this user

Bulk actions:

- Export selected
- Change plan
- Disable selected
- Send notification/message

## Client Info Page

Clicking info on a client opens a detailed client/business page with full edit access.

Header:

- Business name
- Owner/user name
- Email
- Mobile
- Plan and subscription badge
- Last sync and last login
- Edit button
- More menu: export, import, reset password, disable user

Summary cards:

- Total earning
- Pending payment
- Monthly orders
- Total orders/events
- Quotations
- Invoices
- Employees
- Menu items
- Last 30 days revenue
- Data sync status

Tabs/sections:

### Client Details

Editable fields:

- User name
- Email
- Mobile
- Role/status
- Business name
- GSTIN
- GST type
- GST rate
- PAN
- Address
- Phone
- Business email
- A/c holder name
- A/c number
- Bank
- Branch
- IFSC
- Terms
- Logo
- Signature
- Payment QR
- Invoice template
- Invoice text scale
- PDF menu font size

### Events

Table with:

- Event name
- Client/contact
- Mobile
- Venue
- Dates
- Status
- Menu member mode
- Total amount
- Paid
- Pending
- Created/updated
- Actions

Actions:

- View/edit event
- Edit dates
- Edit menu slots
- Record payment
- Download quotation
- Download invoice
- Download event menu PDF
- Delete event, with confirmation

### Quotations/Invoices

Combined billing table with filters:

- Type: quotation, invoice, manual invoice
- Status: pending, paid, settled, overdue
- Date range
- Amount range

Columns:

- Document type
- Document number
- Event/client
- Date
- Total
- Paid
- Pending
- GST/tax
- Actions

Actions:

- View/edit
- Download PDF
- Share/send
- Record payment
- Delete/void

### Menu

Editable user-specific menu/catalog data.

Tables:

- Menu items
- Custom menus
- Raw materials
- Vegetables/fruits/produce
- Vessels/utensils
- Additional services/add-ons
- Requirement lists/material documents

Menu item fields:

- ID
- English name
- Kannada name
- Title
- Category
- Meal types
- Vegetarian flag
- Created/updated

Actions:

- Create
- Edit/rename
- Delete
- Bulk import
- Export
- Copy from universal catalog
- Restore deleted item if audit/history exists

### Employees

Table:

- Name
- Mobile
- Age
- Designation
- Pay per day
- Pay per hour
- Assigned events
- Attendance count
- Total payable
- Status

Actions:

- Create employee
- Edit employee
- Delete employee
- View attendance
- Export attendance/payroll

### Reports

Available reports:

- Monthly revenue
- Pending payments
- Event report
- Invoice/quotation report
- Consolidated menus
- Employee attendance/payroll
- Material requirement lists
- Sync/data integrity report

Each report should support:

- Date range
- Export PDF
- Export CSV/XLSX
- Print/download

### Audit Activity

Client-specific audit log:

- Timestamp
- Admin
- Action
- Entity
- Entity ID
- Before value
- After value
- IP/device
- Reason/note

## Subscriptions Page

Table columns:

- Subscription ID
- User/business
- Email
- Plan
- Status
- Billing cycle
- Amount
- Start date
- Renewal date
- Expiry date
- Trial end
- Payment method/reference
- Last payment
- Next payment
- Created/updated
- Actions

Filters:

- Search by user/business/email/mobile
- Plan
- Status: active, trial, paused, expired, cancelled
- Billing cycle
- Renewal date range
- Expiry date range
- Payment status

Actions:

- Create subscription
- Edit subscription
- Change plan
- Extend trial
- Pause/resume
- Cancel
- Mark payment received
- Add note
- View audit history

## Plans Page

Manage subscription plans.

Plan fields:

- Plan name
- Plan code
- Description
- Price
- Billing cycle: monthly, quarterly, yearly, lifetime
- Trial days
- Max users/businesses
- Max events/orders
- Max storage/assets
- Enabled features
- Active/inactive
- Sort order

Feature toggles:

- Clients
- Events
- Quotations
- Invoices
- Menu catalog
- Custom menus
- Employees
- Attendance
- Reports
- Export/import
- WhatsApp sharing
- PDF customization
- Business profile assets

Actions:

- Create plan
- Edit plan
- Duplicate plan
- Archive/deactivate plan
- Assign users to plan
- View plan subscribers

## Audit Log Page

Global immutable log of admin and system activity.

Table columns:

- Timestamp
- Actor/admin
- User affected
- Entity type
- Entity ID
- Action
- Summary
- Before
- After
- IP/device
- Result

Filters:

- Date range
- Actor
- User affected
- Entity type
- Action
- Result
- Search text

Actions:

- View details
- Export audit log
- Copy JSON diff

Audit must be written for:

- Login/logout
- Failed login
- User create/edit/delete/disable
- Subscription and plan changes
- Client/business profile edits
- Event edits
- Invoice/quotation edits
- Menu/catalog edits
- Employee edits
- Import/export
- Settings changes
- Destructive operations

## Settings Page

Sections:

- Admin account
- Security
- Database connection
- Sync controls
- Backup/export
- Branding
- Defaults
- Notifications

Required settings:

- Admin email/password change
- Session timeout
- Backup frequency
- Manual backup now
- Restore/import data
- Sync interval
- Data retention for audit logs
- Default trial days
- Default plan
- App maintenance mode
- Support contact
- Brand logo/color

## Data Model Coverage

The admin must be able to inspect and edit these current CaterPro data groups:

- Users
- Business profiles
- Clients
- Events
- Event dates
- Menu slots
- Event payments
- Manual invoices
- Manual invoice items
- Employees
- Attendance
- Employee assignments
- Additional services
- User menu items
- Custom menus
- Raw materials
- Produce/vegetable items
- Vessel/utensil items
- Requirement lists/material documents
- Universal catalog backup tables
- Subscriptions
- Plans
- Audit logs
- Settings

## Access And Safety Rules

- Only one admin login for v1.
- Every page has edit access.
- Every important edit must write an audit record.
- Destructive actions require confirmation.
- Bulk destructive actions require typed confirmation.
- Edits should be validated before save.
- Show unsaved changes warning.
- Store before/after JSON in audit log for critical edits.
- Never silently delete user data.
- Export/import must show preview and validation errors before applying.
- Client data edits should preserve IDs unless admin explicitly changes them.

## UI Requirements

Style:

- Professional SaaS admin dashboard.
- Dense but readable.
- Light theme preferred for admin; optional dark mode in settings.
- Use green CaterPro branding with restrained neutrals.
- Avoid marketing-style hero sections.

Layout:

- Fixed left sidebar.
- Top command bar with page title, global search, environment badge, admin menu.
- Main content area uses tables, cards, tabs, drawers, and modals.
- Tables must have sticky headers and pagination.
- Details pages should use card summaries plus tabs.
- Use clear primary buttons for create/save.
- Use icon buttons with tooltips for row actions.

States:

- Loading skeletons
- Empty states
- Error states
- Saving state
- Disabled state
- Dirty/unsaved state
- Confirmation dialogs
- Toast/snackbar feedback

## Stitch UI Prompt

Use this prompt in Stitch or another UI generator:

```text
Create a full-fledged responsive web admin dashboard UI for "CaterPro Admin", an internal SaaS operations dashboard for managing catering app users and their database records.

Brand and visual style:
- Product name: CaterPro Admin
- Use a clean enterprise SaaS style, not a landing page.
- Light theme by default with green branding.
- Primary color: deep green #2F7D46.
- Accent color: fresh green #52A85F.
- Background: #F7FBF2.
- Surface cards: #FFFFFF.
- Border: #D8DBD3.
- Text: #1F2A24.
- Muted text: #6C766F.
- Warning: #B7791F.
- Error: #B42318.
- Success: #287D3C.
- Use rounded 8px cards, compact spacing, readable tables, sticky headers, and professional admin density.

Global layout:
- Fixed left sidebar, 260px wide.
- Sidebar nav items with icons: Dashboard, Clients, Subscriptions, Plans, Audit Log, Settings.
- Sidebar top has CaterPro logo and "Admin Console".
- Sidebar bottom has admin email, environment badge "Production", and Logout.
- Top command bar in main area: page title, breadcrumb, global search, "Create" button, notifications icon, admin avatar.

Build these screens:

1. Login screen
- Centered login panel.
- CaterPro logo.
- Email and password fields.
- Login button.
- Forgot password link.
- Security note: "Admin access only".

2. Dashboard screen
- Metric cards: Total Users, Active Users, Trial Users, Expired Users, Active Subscriptions, Monthly Recurring Revenue, Total Events, Pending Payments, Last Sync Health.
- Charts: Monthly Revenue Trend, New Users by Month, Subscription Status Donut.
- Tables/cards: Recently Active Users, Users With Sync Issues, Recent Audit Activity.
- Actions: Create User, Export CSV, Open Audit Log.

3. Clients list screen
- Data table with search, filters, sorting, pagination, selectable rows.
- Columns: Business Name, Owner, Email, Mobile, City, Plan, Subscription Status, Events, Invoices, Total Earnings, Pending Amount, Last Sync, Last Login, Status, Actions.
- Filters: Plan, Status, Trial/Paid/Expired, City, Created Date Range, Last Sync Range, Has Pending Payments, Has Sync Issues.
- Row action icons: Info, Edit, Subscription, Reset Password, Disable, Export.
- Bulk actions bar when rows are selected.

4. Client info/detail screen
- Header: business name, owner, email, mobile, plan badge, subscription status badge, last sync, last login, Edit button, More menu.
- Summary cards: Total Earning, Pending Payment, Monthly Orders, Total Orders, Quotations, Invoices, Employees, Menu Items, Last 30 Days Revenue, Sync Status.
- Tabs: Client Details, Events, Quotations/Invoices, Menu, Employees, Reports, Audit Activity.

Client Details tab:
- Editable form cards for user profile and business profile.
- Fields: User Name, Email, Mobile, Business Name, GSTIN, GST Type, GST Rate, PAN, Address, Phone, Business Email, A/c Holder Name, A/c Number, Bank, Branch, IFSC, Terms, Logo, Signature, Payment QR, Invoice Template, Invoice Text Scale, PDF Menu Font Size.
- Save and Cancel buttons.

Events tab:
- Table columns: Event Name, Contact, Mobile, Venue, Dates, Status, Total, Paid, Pending, Created, Updated, Actions.
- Row actions: View/Edit Event, Edit Dates, Edit Menus, Record Payment, Download Quotation, Download Invoice, Download Menu PDF, Delete.
- Include date range and status filters.

Quotations/Invoices tab:
- Combined billing table.
- Filters: Document Type, Status, Date Range, Amount Range.
- Columns: Type, Document Number, Event/Client, Date, Total, Paid, Pending, GST/Tax, Actions.
- Actions: View/Edit, Download PDF, Share/Send, Record Payment, Void/Delete.

Menu tab:
- Nested sections with tables for Menu Items, Custom Menus, Raw Materials, Produce/Vegetables/Fruits, Vessels/Utensils, Additional Services, Requirement Lists.
- Menu item fields: ID, English Name, Kannada Name, Title, Category, Meal Types, Vegetarian, Created, Updated, Actions.
- Actions: Create, Edit, Rename, Delete, Bulk Import, Export, Copy From Universal Catalog.

Employees tab:
- Table columns: Name, Mobile, Age, Designation, Pay/Day, Pay/Hour, Assigned Events, Attendance Count, Total Payable, Status, Actions.
- Actions: Create, Edit, Delete, View Attendance, Export Payroll.

Reports tab:
- Report cards: Monthly Revenue, Pending Payments, Event Report, Invoice Report, Consolidated Menus, Employee Attendance, Material Requirement Lists, Sync/Data Integrity.
- Each report card has date range controls and Export PDF / Export CSV buttons.

Audit Activity tab:
- Table columns: Timestamp, Admin, Action, Entity, Entity ID, Summary, Before, After, IP/Device, Result.
- Include JSON diff drawer when clicking a row.

5. Subscriptions screen
- Table with search, filters, sorting, pagination.
- Columns: Subscription ID, User/Business, Email, Plan, Status, Billing Cycle, Amount, Start Date, Renewal Date, Expiry Date, Trial End, Last Payment, Next Payment, Created, Updated, Actions.
- Filters: Plan, Status, Billing Cycle, Renewal Date Range, Expiry Date Range, Payment Status.
- Actions: Create Subscription, Edit, Change Plan, Extend Trial, Pause/Resume, Cancel, Mark Payment Received, Add Note, View Audit.

6. Plans screen
- Grid/list of plan cards plus plan table.
- Plan fields: Plan Name, Plan Code, Description, Price, Billing Cycle, Trial Days, Max Users, Max Events, Max Storage, Feature Toggles, Status, Sort Order.
- Feature toggles: Clients, Events, Quotations, Invoices, Menu Catalog, Custom Menus, Employees, Attendance, Reports, Export/Import, WhatsApp Sharing, PDF Customization, Business Profile Assets.
- Actions: Create Plan, Edit Plan, Duplicate Plan, Archive, View Subscribers.

7. Audit Log screen
- Full table with filters.
- Columns: Timestamp, Actor/Admin, User Affected, Entity Type, Entity ID, Action, Summary, Before, After, IP/Device, Result.
- Filters: Date Range, Actor, User, Entity Type, Action, Result, Search.
- Row opens side drawer with before/after JSON diff.
- Export Audit Log button.

8. Settings screen
- Sections: Admin Account, Security, Database Connection, Sync Controls, Backup/Export, Branding, Defaults, Notifications.
- Fields/actions: Change Admin Email, Change Password, Session Timeout, Backup Frequency, Backup Now, Restore Import Data, Sync Interval, Audit Retention, Default Trial Days, Default Plan, Maintenance Mode, Support Contact, Brand Logo, Brand Colors.

Important interaction requirements:
- Every data table supports search, filter, sort, pagination, export, and row actions.
- All details pages have Edit access.
- Destructive actions require confirmation.
- Bulk destructive actions require typed confirmation.
- Show loading skeletons, empty states, error states, saving states, success snackbars, and unsaved changes warnings.
- Use slide-over drawers for detailed edits and JSON diff views.
- Use modals for confirmations and small create/edit forms.
- Tables should be dense, with sticky headers and clear action icons.
- Use realistic sample data from a catering SaaS: Malnad Kitchen, Mamatha, Venkatesh, Fresh Pure Food India Private Limited, Send Off, Pooje, Satyarayanana Pooje, invoices in INR, plans such as Trial, Basic, Pro, Enterprise.

Deliver the UI as high-fidelity admin dashboard screens with consistent components and responsive desktop/tablet behavior.
```


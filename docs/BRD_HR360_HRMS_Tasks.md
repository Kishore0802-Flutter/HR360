# HR#360 Mobile — HRMS + Task Management (BRD)

Version 1.0 · 22 Oct 2026 · Flutter (Android / iOS)

## 1. Goal

One mobile app for two products that share a single sign-in:

- **HRMS**: attendance with selfie and location, leave, approvals, people, holidays.
- **Tasks**: task dashboard, my tasks, issues, and a calendar.

What each person sees depends on their **role**, **permissions**, and **data scope**, all returned by the server at sign-in. The app never hardcodes a list of features per user.

## 2. Server

| Item | Value |
| --- | --- |
| Base URL | `https://hrms-demo-api.giraffai.in/api/v1` |
| API docs | `https://hrms-demo-api.giraffai.in/api/docs/` (OpenAPI: `/api/openapi.json`) |
| Response envelope | `{ "success": true, "data": … }` |
| Error envelope | `{ "success": false, "error": { "code", "message", "requestId" } }` |
| Lists | `data.items`, `data.page`, `data.pageSize`, `data.totalItems`, `data.totalPages` |
| Auth | `Authorization: Bearer <accessToken>` (15-minute lifetime) |
| Refresh | `hrms_rt` httpOnly cookie, rotated on every refresh |
| Timezone | `company.timezone` (Asia/Kolkata) |

The old base URL `https://hrms-api.giraffai.in/api` and its `/me/*`, `/leaves`, and `/masters/*` paths are retired. The app no longer calls them.

## 3. Roles and scope

| Server role code | App role | Scope | Home dashboard |
| --- | --- | --- | --- |
| `SUPER_ADMIN`, `ADMIN` | Admin | `ALL` | Organisation overview |
| any code containing `HR` | HR | `ALL` | People overview |
| `MANAGER` | Manager | `TEAM` | Team overview + my day |
| `EMPLOYEE` | Employee | `SELF` | My day (greeting, check-in, leave, requests) |

A custom role without one of those codes falls back to its scope: `ALL` gets the Admin view, `TEAM` gets the Manager view, and `SELF` gets the Employee view.

### Permission gates used by the app

| Permission | Unlocks |
| --- | --- |
| `hrms_dashboard:view` | HRMS dashboard metrics |
| `attendance:create` | Check in / check out |
| `attendance:review` | Team attendance board |
| `leave:create` | Apply leave |
| `leave:approve` | Approvals tab, approve / reject |
| `employees:view` | Employees directory |
| `holidays:view` | Holidays |
| `task_dashboard:view` / `tasks:view` | Tasks module and its bottom navigation |
| `issues:view` | Issues tab |
| `calendar:view` | Calendar tab |

## 4. Endpoints used by the app

### 4.1 Authentication

| Purpose | Method | URL | Notes |
| --- | --- | --- | --- |
| Sign in | POST | `/auth/login` | `{ email, password, remember: true }` → `data.accessToken`, `data.user` (roles, permissions, scope, employee, company). Stores `hrms_rt` from `Set-Cookie`. |
| Refresh | POST | `/auth/refresh` | Sends `Cookie: hrms_rt=…`. Returns a new access token and a rotated cookie. Runs automatically on a 401. |
| Current user | GET | `/auth/me` | Used when the app reopens. |
| Sign out | POST | `/auth/logout` | Revokes the refresh session. |
| Forgot password | POST | `/auth/forgot-password` | `{ email }`. Always 200. |

### 4.2 Home and dashboards

| Purpose | Method | URL |
| --- | --- | --- |
| Unread badge | GET | `/notifications/unread-count` |
| HRMS dashboard | GET | `/reports/hrms/dashboard?from=YYYY-MM-DD&to=YYYY-MM-DD` |
| Task dashboard | GET | `/reports/tasks/dashboard?from&to&granularity=day\|week\|month&mine=true` |
| Roles catalogue | GET | `/roles` (admin reference) |
| Permission catalogue | GET | `/permissions` (admin reference) |
| Public settings | GET | `/settings/public` (work start time, photo / location rules) |

### 4.3 Attendance

| Purpose | Method | URL | Notes |
| --- | --- | --- | --- |
| Today's state | GET | `/attendance/status` | `isCheckedIn`, `openSince`, `nextAction`, `canCheckIn`, `today`, `events`, `requirements` |
| Check in | POST | `/attendance/check-in` | multipart: `photo`, `latitude`, `longitude`, `accuracy`, `deviceTime`, `clientEventId` |
| Check out | POST | `/attendance/check-out` | same fields as check in |
| My history | GET | `/attendance/me?from&to` | `days[]` + `totals` |
| Team board | GET | `/attendance?date=YYYY-MM-DD&status=` | `counts` + `items[]`, scope-filtered |

### 4.4 Leave

| Purpose | Method | URL |
| --- | --- | --- |
| My balances | GET | `/leave-balances/me?year=YYYY` |
| Leave types | GET | `/leave-types` |
| My requests | GET | `/leave-requests?mine=true` |
| Approvals queue | GET | `/leave-requests?status=PENDING&actionable=true` |
| Decided history | GET | `/leave-requests?status=APPROVED\|REJECTED` |
| Detail | GET | `/leave-requests/{id}` |
| Apply | POST | `/leave-requests` (multipart: `leaveTypeId`, `startDate`, `endDate`, `startSession`, `endSession`, `reason`) |
| Approve | POST | `/leave-requests/{id}/approve` `{ comment }` |
| Reject | POST | `/leave-requests/{id}/reject` `{ comment }` (required) |
| Cancel | POST | `/leave-requests/{id}/cancel` `{ reason }` |

### 4.5 People and calendar

| Purpose | Method | URL |
| --- | --- | --- |
| Employees | GET | `/employees?q&departmentId&pageSize` |
| Holidays | GET | `/holidays?year=YYYY` |
| Notifications | GET | `/notifications` |
| Mark read | PATCH | `/notifications/{id}/read` `{ read: true }` |

### 4.6 Tasks

| Purpose | Method | URL |
| --- | --- | --- |
| My tasks | GET | `/tasks?mine=true&bucket=ongoing\|completed` |
| Task detail | GET | `/tasks/{id}` |
| Issues | GET | `/issues` |
| Calendar | GET | `/calendar/events?from=ISO&to=ISO` |

### 4.7 Later phases (on the server, not in this release)

Regularisation (`/regularisations*`), task create / edit / status (`/tasks*`), projects, outlets, schedules, templates, reports export, settings, and audit logs.

## 5. App structure

```
Splash → Stories (first launch) → Login → Shell
                                            ├── HRMS module   (green)
                                            │    Home · Attendance · Leave · Approvals* · Profile
                                            └── Tasks module  (amber)
                                                 Dashboard · My tasks · Issues* · Calendar* · Profile
* shown only with the matching permission
```

- **Networking**: Dio with interceptors for auth headers, envelope unwrapping, silent token refresh with request replay, ETag / 304 replay, and debug logging.
- **Routing**: go_router owns splash, stories, login, recovery, `/app`, `/team/employees`, `/team/attendance`, and `/holidays`.

## 6. Dashboards

All HRMS numbers come from `/reports/hrms/dashboard`. The server already filters it by scope, so a manager sees only their team.

| Block | Admin | HR | Manager | Employee |
| --- | --- | --- | --- | --- |
| Period switch (Today / Week / Month) | ✓ | ✓ | ✓ | — |
| My day check-in card | ✓ | ✓ | ✓ | ✓ (designed home) |
| Attendance today tiles (present, checked in, not checked in, absent, on leave, late) | ✓ | ✓ | ✓ team | — |
| Today donut | ✓ | ✓ | — | — |
| Daily attendance trend bars | ✓ | — | ✓ | — |
| Headcount, new joiners, department bars | ✓ | ✓ (hero) | — | — |
| Designation mix | — | ✓ | — | — |
| Working hours (total, average, overtime) | ✓ | — | ✓ | — |
| Exceptions (missing checkout, late, under hours, evidence review) | ✓ | ✓ | ✓ | — |
| Leave and regularisation pipeline | ✓ | ✓ | ✓ (action cards) | — |
| Upcoming leave | ✓ | ✓ | ✓ | — |
| Leave balances, month chart, pending strip | — | — | — | ✓ |

The task dashboard is shared across roles. Employees see their own tasks (`mine=true`), managers see their team, and admins see the organisation. It shows status counts, completion, overdue / due soon / at risk / unassigned, status distribution, priority, project, type, and issues.

## 7. Module switch

- A two-state pill in each module's header: **HRMS** (green, people icon) and **Tasks** (amber, checklist icon), with a sliding gradient thumb.
- Switching plays a circular colour reveal from the switch and swaps the bottom navigation to the other module's tabs and accent colour.
- The app remembers the last module per device.
- Users without task permissions do not see the switch.

## 8. Attendance capture rules

- Check in and check out both open the front camera and capture location together. The server requires `photo` and `location` (`requirements.photo`, `requirements.location`).
- A first location denial returns to the dashboard. A second denial shows the Settings dialog.
- `clientEventId` (a UUID) makes retries safe.
- The geofence applies only when `requirements.geofenceEnabled` is true. Otherwise the confirm screen says location is recorded.
- Multiple sessions per day are allowed when `allowMultipleSessions` is true, up to `maxSessionsPerDay`.

## 9. Session rules

- Tokens and the refresh cookie are stored in secure storage.
- On a 401, the app refreshes once and replays the request. If refresh fails, the user returns to sign in.
- Sign-out calls `/auth/logout` and clears local session data.

## 10. Out of scope for this release

Payslips (no server endpoint yet), biometric sign-in, and regularisation submission. Each shows a designed "coming soon" dialog.

# 💑 CoupleSync — Flutter + Supabase Implementation Plan

> **Purpose:** This document is a complete, step-by-step implementation blueprint for building a couples task & reminder app using Flutter (frontend) and Supabase (backend). Hand this directly to an AI coding assistant (e.g. Gemini) to begin implementation.

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Supabase Backend Setup](#3-supabase-backend-setup)
4. [Flutter Project Structure](#4-flutter-project-structure)
5. [Authentication Flow](#5-authentication-flow)
6. [Database Schema](#6-database-schema)
7. [Feature Implementation Plan](#7-feature-implementation-plan)
8. [UI/UX Screens](#8-uiux-screens)
9. [Theme System (Light & Dark)](#9-theme-system-light--dark)
10. [Notifications & Reminders](#10-notifications--reminders)
11. [State Management](#11-state-management)
12. [Implementation Order](#12-implementation-order)
13. [Environment & Config](#13-environment--config)

---

## 1. Project Overview

**App Name:** CoupleSync (or any name of your choice)

**Users:** Exactly 2 users — a couple (User A and User B), each with their own account.

### Core Features
- ✅ **Task Assignment** — either partner can create a task and assign it to the other (or themselves)
- ✅ **Personal Reminders** — each user can set private reminders only they see
- ✅ **Shared Reminders** — optional shared reminders visible to both
- ✅ **Task Status** — tasks can be marked pending / in-progress / done
- ✅ **Push Notifications** — local notifications for reminders and task due dates
- ✅ **Light / Dark Theme** — toggle switch in the app, preference persisted locally
- ✅ **Authentication** — email + password login stored in Supabase Auth

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart), targeting Android & iOS |
| Backend | Supabase (PostgreSQL + Auth + Realtime + Edge Functions) |
| State Management | Riverpod (recommended) or Provider |
| Local Notifications | `flutter_local_notifications` + `timezone` |
| Theme Persistence | `shared_preferences` |
| Realtime Sync | Supabase Realtime (websocket subscriptions) |
| Date/Time | `intl` package |

### Flutter Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  flutter_riverpod: ^2.4.0
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.0
  shared_preferences: ^2.2.0
  intl: ^0.19.0
  uuid: ^4.3.0
  go_router: ^13.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

---

## 3. Supabase Backend Setup

### 3.1 Create Supabase Project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Note down:
   - **Project URL** (`SUPABASE_URL`)
   - **Anon/Public Key** (`SUPABASE_ANON_KEY`)

### 3.2 Create Two User Accounts
In Supabase Dashboard → Authentication → Users → "Invite User":
- Create account for User A (you)
- Create account for User B (your girlfriend)

Both users use **email + password** authentication.

### 3.3 Enable Realtime
In Supabase Dashboard → Database → Replication:
- Enable replication for tables: `tasks`, `reminders`

---

## 4. Flutter Project Structure

```
lib/
├── main.dart
├── app.dart                         # MaterialApp, theme, router
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_strings.dart
│   ├── theme/
│   │   ├── app_theme.dart           # Light & dark ThemeData
│   │   └── theme_notifier.dart      # Riverpod notifier for theme toggle
│   ├── router/
│   │   └── app_router.dart          # GoRouter configuration
│   └── supabase/
│       └── supabase_client.dart     # Supabase initialization
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   └── auth_notifier.dart
│   ├── tasks/
│   │   ├── data/
│   │   │   ├── task_model.dart
│   │   │   └── task_repository.dart
│   │   ├── presentation/
│   │   │   ├── tasks_screen.dart
│   │   │   ├── task_detail_screen.dart
│   │   │   ├── create_task_screen.dart
│   │   │   └── tasks_notifier.dart
│   ├── reminders/
│   │   ├── data/
│   │   │   ├── reminder_model.dart
│   │   │   └── reminder_repository.dart
│   │   ├── presentation/
│   │   │   ├── reminders_screen.dart
│   │   │   ├── create_reminder_screen.dart
│   │   │   └── reminders_notifier.dart
│   └── home/
│       └── presentation/
│           └── home_screen.dart     # Bottom nav container
└── shared/
    ├── widgets/
    │   ├── app_button.dart
    │   ├── app_text_field.dart
    │   ├── task_card.dart
    │   ├── reminder_card.dart
    │   └── theme_toggle.dart
    └── services/
        └── notification_service.dart
```

---

## 5. Authentication Flow

### Flow Description
1. App launches → check Supabase session
2. If session exists → go to Home screen
3. If no session → go to Login screen
4. Login screen: email + password fields → call `supabase.auth.signInWithPassword()`
5. On success → store session (Supabase handles this automatically) → navigate to Home
6. Logout → `supabase.auth.signOut()` → navigate to Login

### Login Screen UI
- App logo / couple icon at top
- Email `TextField`
- Password `TextField` (obscured, with show/hide toggle)
- "Sign In" button
- No sign-up screen (accounts are pre-created in Supabase dashboard)

### `auth_repository.dart`
```dart
class AuthRepository {
  final supabase = Supabase.instance.client;

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
```

---

## 6. Database Schema

Run the following SQL in Supabase → SQL Editor:

```sql
-- ─────────────────────────────────────────────
-- PROFILES table (extends Supabase auth.users)
-- ─────────────────────────────────────────────
create table public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  display_name text not null,
  partner_id uuid references public.profiles(id),
  created_at timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─────────────────────────────────────────────
-- TASKS table
-- ─────────────────────────────────────────────
create table public.tasks (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  created_by uuid references public.profiles(id) not null,
  assigned_to uuid references public.profiles(id) not null,
  status text not null default 'pending'
    check (status in ('pending', 'in_progress', 'done')),
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high')),
  due_date timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ─────────────────────────────────────────────
-- REMINDERS table
-- ─────────────────────────────────────────────
create table public.reminders (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  note text,
  owner_id uuid references public.profiles(id) not null,
  is_shared boolean default false,
  remind_at timestamptz not null,
  is_completed boolean default false,
  created_at timestamptz default now()
);

-- ─────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.reminders enable row level security;

-- Profiles: users can read all profiles (needed to show partner name)
create policy "profiles_read" on public.profiles
  for select using (true);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Tasks: visible to creator or assignee
create policy "tasks_select" on public.tasks
  for select using (
    auth.uid() = created_by or auth.uid() = assigned_to
  );

create policy "tasks_insert" on public.tasks
  for insert with check (auth.uid() = created_by);

create policy "tasks_update" on public.tasks
  for update using (
    auth.uid() = created_by or auth.uid() = assigned_to
  );

create policy "tasks_delete" on public.tasks
  for delete using (auth.uid() = created_by);

-- Reminders: own reminders + shared reminders from partner
create policy "reminders_select" on public.reminders
  for select using (
    auth.uid() = owner_id
    or (
      is_shared = true
      and owner_id in (
        select partner_id from public.profiles where id = auth.uid()
      )
    )
  );

create policy "reminders_insert" on public.reminders
  for insert with check (auth.uid() = owner_id);

create policy "reminders_update" on public.reminders
  for update using (auth.uid() = owner_id);

create policy "reminders_delete" on public.reminders
  for delete using (auth.uid() = owner_id);
```

### After running SQL — manual step:
Update `partner_id` for both users in the `profiles` table so each points to the other's UUID. Do this once in the Supabase Table Editor.

---

## 7. Feature Implementation Plan

### 7.1 Tasks Feature

#### Task Model
```dart
class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String createdBy;
  final String assignedTo;
  final String status;       // 'pending' | 'in_progress' | 'done'
  final String priority;     // 'low' | 'medium' | 'high'
  final DateTime? dueDate;
  final DateTime createdAt;

  // fromJson / toJson / copyWith methods
}
```

#### Task Repository — key methods
```dart
// Fetch all tasks for current user (created by OR assigned to)
Future<List<TaskModel>> fetchTasks();

// Realtime stream
Stream<List<TaskModel>> watchTasks();

// Create task assigned to partner or self
Future<void> createTask(TaskModel task);

// Update status
Future<void> updateTaskStatus(String taskId, String status);

// Delete task
Future<void> deleteTask(String taskId);
```

#### Business Rules
- Either user can create a task and assign it to themselves OR their partner
- Only the creator can delete a task
- Both the creator and assignee can update the status
- Tasks show a colored priority badge: 🔴 High / 🟡 Medium / 🟢 Low
- Overdue tasks (past due date, not done) show a red indicator

---

### 7.2 Reminders Feature

#### Reminder Model
```dart
class ReminderModel {
  final String id;
  final String title;
  final String? note;
  final String ownerId;
  final bool isShared;
  final DateTime remindAt;
  final bool isCompleted;

  // fromJson / toJson / copyWith
}
```

#### Reminder Repository — key methods
```dart
// Fetch reminders visible to current user
Future<List<ReminderModel>> fetchReminders();

// Stream for realtime
Stream<List<ReminderModel>> watchReminders();

// Create reminder
Future<void> createReminder(ReminderModel reminder);

// Mark complete
Future<void> markComplete(String reminderId);

// Delete
Future<void> deleteReminder(String reminderId);
```

#### Business Rules
- Private reminders: only the owner sees them
- Shared reminders: partner can see (read-only) but only owner can edit/delete
- When a reminder is created/updated, schedule a local notification for `remindAt`
- Completed reminders are visually crossed out and moved to bottom of list

---

## 8. UI/UX Screens

### Screen List & Navigation

```
App
├── LoginScreen            (unauthenticated)
└── HomeScreen             (authenticated — bottom nav)
    ├── Tab 1: TasksScreen
    │   ├── Task list (assigned to me / created by me / all)
    │   ├── FAB → CreateTaskScreen
    │   └── Tap task → TaskDetailScreen
    ├── Tab 2: RemindersScreen
    │   ├── My reminders + shared reminders from partner
    │   └── FAB → CreateReminderScreen
    └── Tab 3: ProfileScreen
        ├── Display name
        ├── Partner name
        ├── Theme toggle (Light / Dark)
        └── Sign Out button
```

### Key UI Details

**HomeScreen (Bottom Navigation)**
- Tab icons: ✅ Tasks, 🔔 Reminders, 👤 Profile
- Show badge count on Tasks tab for pending tasks assigned to me
- App bar title changes per tab

**TasksScreen**
- Filter chips at top: "All" / "Assigned to Me" / "Created by Me"
- Task cards show: title, assignee avatar/name, priority badge, due date, status chip
- Swipe to delete (creator only)
- Long press → quick status update bottom sheet

**CreateTaskScreen**
- Title field (required)
- Description field (optional, multiline)
- "Assign to" toggle: [Me] [Partner]
- Priority selector: Low / Medium / High
- Due date + time picker (optional)
- Save button

**RemindersScreen**
- Sections: "My Reminders" and "Shared" (if any shared exist)
- Reminder card shows: title, date/time, shared badge if applicable
- Swipe to complete or delete

**CreateReminderScreen**
- Title field
- Note field (optional)
- Date + Time picker
- "Share with partner" toggle switch
- Save button

---

## 9. Theme System (Light & Dark)

### `theme_notifier.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

const _themeKey = 'theme_mode';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    if (saved == 'dark') state = ThemeMode.dark;
    else if (saved == 'light') state = ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      await prefs.setString(_themeKey, 'light');
    } else {
      state = ThemeMode.dark;
      await prefs.setString(_themeKey, 'dark');
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
```

### `app_theme.dart`
```dart
class AppTheme {
  static const _primaryColor = Color(0xFFE91E8C); // romantic pink/magenta

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: _primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: _primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
  );
}
```

### Theme Toggle Widget (in ProfileScreen)
```dart
Consumer(builder: (context, ref, _) {
  final mode = ref.watch(themeProvider);
  return SwitchListTile(
    title: const Text('Dark Mode'),
    secondary: Icon(mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
    value: mode == ThemeMode.dark,
    onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
  );
})
```

### Wire up in `app.dart`
```dart
MaterialApp.router(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ref.watch(themeProvider),
  routerConfig: AppRouter.router,
)
```

---

## 10. Notifications & Reminders

### `notification_service.dart`

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String? body,
    required DateTime scheduledAt,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          channelDescription: 'Reminder notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }
}
```

**Note:** Use the reminder's UUID hashCode as the notification `id`.

### Android Setup Required in `AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

---

## 11. State Management

Use **Riverpod** with `AsyncNotifier` for async data. Pattern:

```dart
// Example: Tasks notifier
class TasksNotifier extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    // Subscribe to realtime stream
    final repo = ref.watch(taskRepositoryProvider);
    ref.onDispose(() { /* cancel subscription */ });

    repo.watchTasks().listen((tasks) {
      state = AsyncData(tasks);
    });

    return repo.fetchTasks();
  }

  Future<void> createTask(TaskModel task) async {
    await ref.read(taskRepositoryProvider).createTask(task);
  }

  Future<void> updateStatus(String id, String status) async {
    await ref.read(taskRepositoryProvider).updateTaskStatus(id, status);
  }
}

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<TaskModel>>(
  TasksNotifier.new,
);
```

---

## 12. Implementation Order

Follow this order for a smooth build:

```
Phase 1 — Foundation
  [ ] Create Flutter project: flutter create couple_sync
  [ ] Add all dependencies to pubspec.yaml
  [ ] Set up Supabase project and copy URL + anon key
  [ ] Run SQL schema in Supabase SQL Editor
  [ ] Manually link partner_id for both user profiles
  [ ] Initialize Supabase in main.dart
  [ ] Set up GoRouter with auth guard
  [ ] Set up Riverpod ProviderScope in main.dart
  [ ] Implement AppTheme (light + dark)
  [ ] Implement ThemeNotifier and wire to MaterialApp

Phase 2 — Authentication
  [ ] Build LoginScreen UI
  [ ] Implement AuthRepository
  [ ] Implement AuthNotifier (Riverpod)
  [ ] Wire auth state → router redirect

Phase 3 — Tasks
  [ ] Implement TaskModel (fromJson / toJson)
  [ ] Implement TaskRepository (CRUD + realtime stream)
  [ ] Implement TasksNotifier
  [ ] Build TaskCard widget
  [ ] Build TasksScreen with filter chips
  [ ] Build CreateTaskScreen with all fields
  [ ] Build TaskDetailScreen with status update

Phase 4 — Reminders
  [ ] Initialize NotificationService in main.dart
  [ ] Request notification permissions on first launch
  [ ] Implement ReminderModel
  [ ] Implement ReminderRepository
  [ ] Implement RemindersNotifier
  [ ] Build ReminderCard widget
  [ ] Build RemindersScreen
  [ ] Build CreateReminderScreen with date/time picker
  [ ] Schedule/cancel local notifications on create/delete

Phase 5 — Profile & Polish
  [ ] Build ProfileScreen with theme toggle and sign out
  [ ] Add bottom navigation (HomeScreen)
  [ ] Add task badge count on Tasks tab
  [ ] Add empty state illustrations
  [ ] Add loading skeletons / shimmer
  [ ] Add error snackbars
  [ ] Test realtime sync between two devices/accounts
```

---

## 13. Environment & Config

### `lib/core/supabase/supabase_client.dart`
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = 'YOUR_SUPABASE_PROJECT_URL';
  static const anonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### `main.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase/supabase_client.dart';
import 'shared/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await NotificationService.init();

  runApp(const ProviderScope(child: App()));
}
```

---

## ⚠️ Important Notes for Gemini

1. **No public sign-up** — accounts are pre-created in Supabase dashboard. Remove any registration UI.
2. **Two users only** — the partner is always the single other user. Fetch the partner's profile using `partner_id` from the profiles table.
3. **RLS is required** — all database access must go through the Supabase client with the user's JWT; never bypass RLS.
4. **Realtime** — use Supabase realtime channel subscriptions for live task/reminder updates between both phones.
5. **Exact alarms on Android 12+** — the `SCHEDULE_EXACT_ALARM` permission requires special handling; implement a runtime permission request if targeting API 31+.
6. **Theme persistence** — use `shared_preferences`; do NOT store theme in Supabase (it's a per-device preference).
7. **Notification IDs** — convert UUID string to a stable int using `.hashCode` for notification IDs.
8. **Date/time** — always store in UTC in Supabase; convert to local time for display using the `intl` or `timezone` package.

---

*Generated implementation plan for CoupleSync — Flutter + Supabase*

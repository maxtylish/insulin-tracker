# 胰島素記錄表 — 每日功能完整性檢查報告

**日期：** 2026-06-06  
**版本：** v2.50.2  
**總結：** ✅ 全部通過

---

## 1. 檔案完整性

| 項目 | 狀態 |
|------|------|
| File size: 663,558 bytes (648.0 KB) | |
| Total lines: 15,531 | |
| ✅ DOCTYPE present | |
| ✅ <html> tag | |
| ✅ </html> closing tag | |
| ✅ <head> / </head> | |
| ✅ <body> tag | |
| ✅ </body> closing tag | |
| ✅ </script> closing tag | |
| ✅ </style> closing tag | |
| ✅ CSS style blocks: 1 | |
| ✅ <div> balance: 662 open / 662 close | |

## 2. JavaScript 語法驗證

- Inline `<script>` 行數：9,085
- `node --check`：✅ node --check passed

## 3. 核心函式完整性（16 個）

| 函式 | 狀態 |
|------|------|
| `getAllData` | ✅ |
| `setAllData` | ✅ |
| `savePeriod` | ✅ |
| `saveDayData` | ✅ |
| `loadFromCloud` | ✅ |
| `syncDayToCloud` | ✅ |
| `loadDayData` | ✅ |
| `initSupabase` | ✅ |
| `init` | ✅ |
| `getTodos` | ✅ |
| `setTodos` | ✅ |
| `getSupplies` | ✅ |
| `setSupplies` | ✅ |
| `loadSettings` | ✅ |
| `saveSettingsToStorage` | ✅ |
| `clearAllData` | ✅ |

## 4. 資料存儲安全規則

| 規則 | 狀態 |
|------|------|
| Rule 1 — `allDataCache` variable exists | ✅ |
| Rule 1 — `setAllData` writes cache + localStorage | ✅ |
| Rule 1 — `clearAllData` resets `allDataCache` | ✅ |
| Rule 3 — Cloud array merge uses length comparison | ✅ |
| Rule 4 — init() order: initSupabase → loadDayData → loadFromCloud | ✅ |
| Rule 4 — `loadDayData` called again after cloud sync | ✅ |

## 5. LocalStorage 鍵值（共 27 個）

`app_pwd`, `app_skin`, `app_skin_custom`, `ev_cache`, `ev_migrated_v1`, `ev_user_sub`, `insulin_card_collapsed`, `insulin_custom_supply_defs`, `insulin_last_corr_inject`, `insulin_meal_params`, `insulin_medications`, `insulin_records`, `insulin_section_collapsed`, `insulin_settings`, `insulin_settings_log`, `insulin_supplies`, `insulin_supply_audit_ver`, `insulin_todos`, `insulin_vials`, `notif_enabled`, `notif_sound`, `pip_alpha`, `pip_theme`, `sb_key`, `sb_url`, `supply_notif_last_date`, `user_id`

---

> 報告由 `insulin-integrity-check` skill 自動產生。
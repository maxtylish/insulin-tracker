# 胰島素記錄表 PWA — Codex 工作規則

## ⚠️ 最高優先：資料存儲安全性

**修改任何程式碼前，必須先確認不會破壞以下資料存儲路徑。**
資料一旦遺失無法復原，安全性高於功能、效能、任何其他考量。

---

## 資料存儲架構

```
使用者操作
    │
    ▼
savePeriod() / saveDayData()
    │  讀取 UI → 寫入 allDataCache → localStorage('insulin_records') → Supabase
    ▼
getAllData() / setAllData()        ← 所有讀寫必須經過這兩個函式
    │
    ├── allDataCache (in-memory)   ← 頁面生命週期內的唯一真實來源
    ├── localStorage               ← 本機持久化
    └── Supabase insulin_records   ← 雲端持久化（user_id + date 為 composite key）
```

### 關鍵 localStorage keys
| Key | 內容 | 操作函式 |
|-----|------|---------|
| `insulin_records` | 所有日期的注射/血糖紀錄 | `getAllData()` / `setAllData()` |
| `insulin_vials` | 胰島素藥瓶清單 | 直接讀寫 |
| `insulin_todos` | 待辦事項 | `getTodos()` / `setTodos()` |
| `insulin_settings` | 設定值 | `loadSettings()` / `saveSettingsToStorage()` |
| `insulin_supplies` | 耗材庫存 | `getSupplies()` / `setSupplies()` |

---

## 資料存儲安全規則（修改前必讀）

### 規則 1：`allDataCache` 是唯一真實來源
- 所有讀取歷史紀錄必須用 `getAllData()`，禁止直接讀 `localStorage.getItem('insulin_records')`
- 所有寫入必須用 `setAllData(data)`，它會同步更新 cache + localStorage
- 清除資料時必須同時清 cache：
  ```javascript
  localStorage.removeItem('insulin_records');
  allDataCache = {};  // ← 缺少這行會導致清除失效
  ```

### 規則 2：saveDayData() 的覆蓋風險
`saveDayData()` 會**無條件**以 UI 當前顯示內容覆蓋 `corrections`、`carbs`、所有 snack sections。
- **禁止**在 UI 尚未完整載入（`loadDayData()` 尚未執行）的情況下呼叫 `saveDayData()`
- 新增任何會觸發 `saveDayData()` 的自動化邏輯前，必須確認 UI 已完整渲染
- `savePeriod()` 個別儲存有時間欄位保護（`!time && existing.time`），但 `saveDayData()` 的補打區塊沒有，需特別注意

### 規則 3：cloud sync 合併邏輯
`loadFromCloud()` 的合併策略：
- **物件型欄位**（PERIODS：morning/noon/evening/bedtime）：有 `time` 的那筆贏
- **陣列型欄位**（corrections/carbs/snacks）：保留項目**較多**的版本
  ```javascript
  // 正確寫法（v2.20.0 之後）
  merged[key] = cv.length >= lv.length ? cv : lv;
  // ❌ 錯誤寫法（舊版 cloud wins，會覆蓋本機未 sync 的補打）
  merged[key] = cv;
  ```
- **primitives**：cloud wins

修改合併邏輯時，必須確保本機未 sync 的資料不會在重新整理後消失。

### 規則 4：init() 載入順序
```javascript
initSupabase()      // 1. 從 localStorage 載入 allDataCache
loadDayData()       // 2. 用 cache 渲染 UI
loadFromCloud()     // 3. async：合併 cloud 資料到 allDataCache
  .then(() => {
    loadDayData();  // 4. 一律重新渲染（確保 cloud 的補打/補糖顯示）
  })
```
**禁止**在步驟 4 加任何條件跳過重新渲染，否則跨裝置補打資料在儲存時會被 UI 空值覆蓋。

### 規則 5：syncDayToCloud() 失敗處理
目前 sync 失敗只顯示 badge，不重試。修改儲存流程時注意：
- 不可假設 cloud sync 一定成功
- 本機 `setAllData()` 必須在 `syncDayToCloud()` 之前完成，確保本機先有資料

---

## 修改程式碼的安全檢查清單

每次修改涉及以下任一項目，都必須過這份清單：

- [ ] **新增儲存邏輯**：有沒有同時更新 `allDataCache`？
- [ ] **新增清除邏輯**：有沒有同時清 `allDataCache = {}`？
- [ ] **修改 `loadFromCloud()`**：陣列合併是否保留較多資料的版本？
- [ ] **修改 `init()` 載入順序**：cloud sync 後是否仍呼叫 `loadDayData()`？
- [ ] **新增自動儲存**：觸發時 UI 是否已完整渲染？
- [ ] **修改 `saveDayData()`**：corrections/carbs/snacks 的覆蓋邏輯是否安全？
- [ ] **新增 localStorage key**：有沒有在 `clearAllData()` 中一併清除（如果應該清的話）？

---

## 操作規則（patch 流程）

1. **禁止**用 Edit tool 直接改大檔（`index.html` > 370KB，會截斷）
2. 所有修改用 **Python `str.replace()` patch 腳本**
3. 腳本執行後：抽取 `<script>` 內容執行 `node --check` 驗證 JS 語法
4. Git 指令在**本機**執行（Sandbox 無法操作 Windows NTFS 上的 .git）
5. **每次修改**（不論大小）都必須更新 `APP_VERSION` + changelog `<ul>`
   - 功能新增 → minor（v2.X.0）
   - 修正 → patch（v2.19.X）
6. GitHub Pages 從 `main` 自動部署，`git push` 即可

### Python patch 腳本注意事項
- `"""..."""` 字串內 `\'` 會被解釋為 `'`，JS 內單引號需用 `\\'`
- 每個 replace 只替換第一個出現（`str.replace(OLD, NEW, 1)`）
- 腳本最後印出每個 patch 的 ✅/❌ 狀態

---

## 已知待處理問題

1. **Supabase 待辦刪除不跨裝置同步**：無軟刪除機制，裝置 B 重開會「復活」已刪項目。
   修法：加 `deletedAt` 欄位，合併時以 `deletedAt` 優先；或以 `updated_at` 決定勝負。

2. **syncDayToCloud() 無重試機制**：網路短暫斷線時本機有資料但 cloud 沒更新，
   下次 cloud sync 時可能以舊版覆蓋本機（P1 的根源）。
   修法：失敗時加入 `_pendingSyncs` 佇列，下次成功連線後自動補推。

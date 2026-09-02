# 胰島素記錄表 PWA — Claude 工作規則

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
| `insulin_school_lunch` | 學校午餐份量調整（portions，最近 90 天） | `smStore()` / `smSaveStore()` |

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

## 學校午餐菜單（v2.59.0）

`SCHOOL_MENU` / `SCHOOL_STAPLE_C100` / `SCHOOL_STAPLE_G` 是**程式內參考常數**，位於 `TAIWAN_FOOD_DB` 之前。

- 菜單本身不進 localStorage，改菜單＝改常數＝要更新 `APP_VERSION`
- 主食碳水一律走 `smStapleC100(主食名) * SCHOOL_STAPLE_G / 100`，
  **禁止**把 110g 的醣量寫死成常數（麵食 / 米食 / 糯米類密度差很多）
- ⚠️ **估算原則（v2.61.0 起，使用者明確指示）：寧可低估。**
  高血糖可以補打，打太多造成的低血糖收不回來。所有醣量估算一律取低標。
  - 不確定的菜色（勾芡、醬汁、滷味、魚漿加工品）→ 取可能區間的下緣
  - 明確是澱粉的菜色（湯圓、河粉、冬粉、西米露、炊飯、雞肉飯、薯麵）→ 照實算，不再往下調
  - **調高任何 `c` 值或 `SCHOOL_STAPLE_C100` 之前必須先告知使用者影響的單位數**，
    這是直接影響孩童胰島素劑量的參數，不是一般 UI 常數
- 低 GI／高油主食日（`SCHOOL_STAPLE_SLOW`）會顯示低血糖提示：醣類吸收比胰島素慢，
  餐後 1～2 小時可能先偏低。施打時機的建議一律交給醫療團隊，程式不主動建議分次或延後
- 每道菜的 `h:1` 代表「隱藏醣」（配菜或湯本身就是澱粉／含糖），
  新增菜色時務必判斷：河粉、冬粉、湯圓、西米露、勾芡濃湯、炊飯、薯麵、關東煮都算
- 份量調整存在 `insulin_school_lunch.portions[date][rowIndex] = ratio`，
  `rowIndex 0` 固定是主食。此 key **不經過** `getAllData()` / `setAllData()` / `allDataCache`，
  也**不在** `clearAllData()` 內清除（它不是紀錄資料）
- 計算機的 `_smCalcCarbs` 與 `fdbTotal()` 同層級，在 `calcRecalc()` 內累加進 `totalCarbs`；
  `_calcResetFields()` 必須把它歸零

---

## 食物碳水值的鐵則（v2.62.0 事故後補上）

`CALC_CARB_FOODS` / `TAIWAN_FOOD_DB` / `SCHOOL_*` 的每 100 公克數值，**一律用煮熟後的重量**。

曾發生：`multigrain_rice` 填 68.9（生米乾重），夾在白飯 30、烏龍麵 24.6、義大利麵 27.4（皆熟重）之間，
選到就高估兩倍碳水，以 CIR 10 每 100 公克多打約 3.7 單位。

- 新增任何主食類食物前，先問「這個數字是生的還是煮好的」
- 生重的品項必須在 key 與 label 都標明（如 `multigrain_rice_raw` /「【生米未煮】」）
- 快速自檢：熟飯麵類每 100g 碳水應落在 22～40；出現 60 以上幾乎一定是生重或乾貨
- label 裡寫的克數必須等於 `CALC_CARB_FOODS` 的值，改一個要改兩處

---

## 已知待處理問題

1. **Supabase 待辦刪除不跨裝置同步**：無軟刪除機制，裝置 B 重開會「復活」已刪項目。
   修法：加 `deletedAt` 欄位，合併時以 `deletedAt` 優先；或以 `updated_at` 決定勝負。

2. **syncDayToCloud() 無重試機制**：網路短暫斷線時本機有資料但 cloud 沒更新，
   下次 cloud sync 時可能以舊版覆蓋本機（P1 的根源）。
   修法：失敗時加入 `_pendingSyncs` 佇列，下次成功連線後自動補推。

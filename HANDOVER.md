# 🩺 Ms.Aududu (胰島素記錄表 PWA) — 交接文件
> 最後更新：2026-05-22　當前版本：**v2.30.5**

---

## 📍 專案位置

| 項目 | 路徑 / URL |
|------|-----------|
| 本機檔案 | `D:\myapps\insulinrecorder\index.html` |
| GitHub | https://github.com/maxtylish/insulin-tracker |
| 線上 PWA | https://maxtylish.github.io/insulin-tracker/ |
| Nightscout CGM | https://0977771916.t1ns.tw |

---

## ⚙️ 技術架構

- **單一 HTML 檔**（index.html = 540KB，無 build 工具）
- **Supabase** 雲端同步 + **localStorage** 本機持久化
- **Chart.js 4.4.1** 繪圖
- **Service Worker** cache key：`insulin-tracker-v6`
- **Google Fonts Pacifico**：標題字體（CDN 載入）
- **Document Picture-in-Picture API**：PIP 浮動視窗功能

---

## ⚠️ 最高優先操作規則（必讀，禁止違反）

### 1. 絕對禁止直接 Edit index.html
檔案 >500KB，Edit tool 會截斷。**所有修改必須用 Python `str.replace()` patch 腳本**。

**Patch 腳本開頭固定用以下寫法自動偵測路徑**（不可硬寫 session-id，每次對話都會變）：

```python
import glob, sys

# 自動找掛載路徑，不依賴 session-id
_candidates = glob.glob('/sessions/*/mnt/insulinrecorder/index.html')
if not _candidates:
    print('❌ 找不到 index.html，請確認 workspace 已掛載'); sys.exit(1)
FILE = _candidates[0]
```

驗證 JS 語法（固定在 sandbox 執行）：
```bash
FILE=$(ls /sessions/*/mnt/insulinrecorder/index.html | head -1)
node -e "
const fs = require('fs');
const html = fs.readFileSync('$FILE', 'utf8');
const m = html.match(/<script>([\s\S]*?)<\/script>/g);
let js = '';
for (const block of m) { js += block.replace(/<\/?script>/g, '') + '\n'; }
fs.writeFileSync('/tmp/check.js', js);
" && node --check /tmp/check.js && echo "✅ OK"
```

### 2. 每次修改必須更新版本號 + Changelog
- 功能新增 → minor（v2.X.0）
- Bug 修正 / 小調整 → patch（v2.30.X）
- Changelog 區塊在 `<!-- v2.30.X -->` 位置插入

### 3. Git 指令必須分三行（PowerShell 5.x 不支援 &&）
```powershell
git add .
git commit -m "描述 (vX.X.X)"
git push
```

### 4. 路徑規則

| 用途 | 路徑 |
|------|------|
| Read / Write / Edit tool | `D:\myapps\insulinrecorder\index.html` |
| Bash sandbox（自動偵測） | `$(ls /sessions/*/mnt/insulinrecorder/index.html \| head -1)` |

> ⚠️ Bash sandbox 的 `/sessions/<session-id>/` 每次對話都不同，**永遠不要硬寫**。
> 使用上方 `glob` 或 shell glob 自動取得正確路徑。

---

## 📦 本次對話完成功能（v2.30.0 → v2.30.5）

| 版本 | 日期 | 內容 |
|------|------|------|
| v2.30.0 | 2026-05-22 | CGM 重要記事改為同時顯示前 3 筆（移除左右導覽） |
| v2.30.1 | 2026-05-22 | PIP 左上角透明度滑桿（存 localStorage） |
| v2.30.2 | 2026-05-22 | PIP 透明度改用 rgba() 直接設定 body；滑桿白色高明度設計；CGM carousel display bug 修正 |
| v2.30.3 | 2026-05-22 | 標題改為 Ms.Aududu + Pacifico 字體 |
| v2.30.4 | 2026-05-22 | 頁尾移除 "Powered by"，改為 Lukuarts Studio · 2026 |
| v2.30.5 | 2026-05-22 | Mini CGM X 軸時間刻度：1h 每 15 分 / 5h 每 30 分 / 今日每整點 |

### ⚠️ v2.30.5 狀態
- Patch 已執行：✅
- `node --check` 驗證：✅
- **Git commit 尚未執行** — 需手動在本機執行：
```powershell
git add .
git commit -m "feat: mini CGM 時間刻度 — 1h每15分/5h每30分/今日每整點 (v2.30.5)"
git push
```

---

## 🔑 關鍵程式碼位置

### APP_VERSION（JS）
```javascript
const APP_VERSION = 'v2.30.5';  // must be before init() to avoid TDZ
// 約在 index.html line 9170
```

### Header 標題
```html
<h1>Ms.Aududu</h1>
<!-- 位置：約 line 2499 -->
```
```css
header h1 {
  font-family: 'Pacifico', cursive;
  font-size: 1.35rem; font-weight: 400;
  letter-spacing: 0.5px;
  text-shadow: 0 1px 6px rgba(0,0,0,0.25);
}
```

### PIP 透明度架構（v2.30.2 重構後）
```javascript
// _hexToRgb() — 將 HEX 轉 [r,g,b] 陣列
// _getPipBgAlpha() — 從 localStorage 讀取 pip_alpha (0~1)
// _buildPipStyle() — rgba() 直接寫入 body.background（不用 #pip-bg div）
// _buildPipHTML() — input 帶 data-rgb 屬性，oninput 直接改 body.style.background
// ⚠️ PIP 視窗無法真正透視下層（Document PIP API 限制，瀏覽器 canvas 不透明）
```

### CGM Carousel（重要記事三列）
```javascript
// _renderCgmCarousel() — 設 display:'block' 而非 ''（CSS 預設 display:none 會蓋掉）
// 3 個 span#cgm-carousel-text-{0,1,2}，同時顯示前 3 筆待辦
```

### Mini CGM X 軸刻度（v2.30.5）
```javascript
callback: function(_, i) {
  var lbl = labels[i];
  if (!lbl) return null;
  var mins = parseInt(lbl.split(':')[1], 10);
  if (miniChartMode === '1h') return mins % 15 === 0 ? lbl : null;
  if (miniChartMode === '5h') return mins % 30 === 0 ? lbl : null;
  return mins === 0 ? lbl : null; // today: hourly
}
// miniChartMode 控制目前模式：'1h' / '5h' / 'today'
```

---

## 🐛 已知待處理問題

| 優先度 | 問題 | 說明 |
|--------|------|------|
| P1 | Supabase 待辦刪除不跨裝置同步 | 裝置 B 重開後已刪項目會「復活」。修法：加 `deletedAt` 欄位 |
| P2 | syncDayToCloud() 無重試機制 | 網路斷線時 local 有資料但 cloud 沒更新，下次 sync 可能以舊版覆蓋。修法：`_pendingSyncs` 佇列 |

---

## 🎨 下一步方向（使用者表示）

> 「主要功能都完成了，再來就是視覺外觀的美化了。」

目前尚未明確指定的下一個任務，等使用者提出具體需求後繼續。

---

## 🧠 Python Patch 腳本注意事項

```python
# ✅ 正確：JS 內單引號需雙重轉義
' oninput="var v=this.value/100;document.body.style.background=\\'rgba(\\'+c+\\',\\'+v+\\')\\'"'

# ❌ 錯誤：\' 在 Python """ 字串內被解釋為 '，不會輸出 \'
' oninput="...\'rgba(\'..."'

# 每個 replace 只替換第一次出現
src = src.replace(old, new, 1)

# patch 找不到字串時立即 sys.exit(1)，避免寫入錯誤結果
if old not in src: print('❌ Patch X'); sys.exit(1)
```

---

## 📁 localStorage 資料結構（核心）

| Key | 內容 | 操作函式 |
|-----|------|---------|
| `insulin_records` | 所有日期紀錄 | `getAllData()` / `setAllData()` |
| `insulin_vials` | 藥瓶清單 | 直接讀寫 |
| `insulin_todos` | 待辦事項 | `getTodos()` / `setTodos()` |
| `insulin_settings` | 設定值 | `loadSettings()` / `saveSettingsToStorage()` |
| `insulin_supplies` | 耗材庫存 | `getSupplies()` / `setSupplies()` |
| `pip_alpha` | PIP 透明度 (0~1) | `_getPipBgAlpha()` |
| `pip_theme` | PIP 主題 key | `_getPipTheme()` |

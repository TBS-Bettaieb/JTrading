# Deployment Script - Deploy-Ex5Files.ps1

Automated PowerShell script to deploy compiled `.ex5` files from `EA/_Release/` to `MQL5\Experts\EAsReleases`.

## 📋 Overview

This script automatically:

- Finds all `.ex5` files in `EA/_Release/`
- Detects the MT5 terminal path
- Creates the `EAsReleases` folder if needed
- Copies all `.ex5` files to `MQL5\Experts\EAsReleases`
- Provides colored output and status updates

## 🚀 Quick Start

### 📋 Quick Copy Commands

#### 1️⃣ **Basic Deployment**

Click to select, then copy (Ctrl+C):

```powershell
.\Deploy-Ex5Files.ps1
```

Deploys all `.ex5` files from `EA/_Release/` to the destination folder.

---

#### 2️⃣ **Preview Mode** (Recommended First)

Click to select, then copy (Ctrl+C):

```powershell
.\Deploy-Ex5Files.ps1 -WhatIf
```

Shows what would happen without making any changes.

---

#### 3️⃣ **Verbose Output**

Click to select, then copy (Ctrl+C):

```powershell
.\Deploy-Ex5Files.ps1 -Verbose
```

Shows detailed information during deployment including file sizes.

---

#### 4️⃣ **Verbose + Preview**

Click to select, then copy (Ctrl+C):

```powershell
.\Deploy-Ex5Files.ps1 -Verbose -WhatIf
```

Combines verbose output with preview mode - shows details without making changes.

## 📁 Directory Structure

### Source

```
JTrading/
└── EA/
    └── _Release/
        ├── BreakoutScalper.ex5
        └── *.ex5
```

### Destination

```
MQL5/
└── Experts/
    └── EAsReleases/
        ├── BreakoutScalper.ex5
        └── *.ex5
```

## 🔧 Features

- ✅ **Automatic Path Detection**: Automatically finds MT5 terminal path
- ✅ **Safe Preview**: `-WhatIf` mode to preview changes
- ✅ **Error Handling**: Continues on errors and reports results
- ✅ **Colored Output**: Easy-to-read status messages
- ✅ **File Info**: Shows file sizes during deployment
- ✅ **Auto-create**: Creates destination folder if missing

## 📊 Output Colors

- 🔵 **Cyan (Info)**: General information and paths
- 🟢 **Green (Success)**: Successfully deployed files
- 🟡 **Yellow (Warning)**: Warnings (e.g., no files found)
- 🔴 **Red (Error)**: Errors during deployment

## 📝 Example Output

```
================================================
    DEPLOY .EX5 FILES TO EAsReleases
================================================

Source: C:\...\JTrading\EA\_Release
Destination: C:\...\MQL5\Experts\EAsReleases

Found 1 .ex5 file(s):
  BreakoutScalper.ex5 (146.66 KB)

Created directory: C:\...\MQL5\Experts\EAsReleases
Deployed: BreakoutScalper.ex5

================================================
Deployment completed successfully!
Successfully deployed: 1 file(s)
================================================

Tip: Files are now available in MetaTrader 5
Navigate to: Experts\EAsReleases
```

## ⚙️ Parameters

| Parameter  | Type   | Description                               |
| ---------- | ------ | ----------------------------------------- |
| `-Verbose` | Switch | Show detailed output including file sizes |
| `-WhatIf`  | Switch | Preview mode - don't actually copy files  |

## 🛠️ Requirements

- PowerShell 5.0 or higher
- Windows OS
- MetaTrader 5 installed
- `.ex5` files must exist in `EA/_Release/`

## 📍 Path Resolution

The script automatically calculates paths:

```
Project Root: C:\Users\[user]\...\Terminal\[ID]\MQL5\Experts\JTrading
Terminal Path: C:\Users\[user]\...\Terminal\[ID]
Destination: C:\Users\[user]\...\Terminal\[ID]\MQL5\Experts\EAsReleases
```

## ✅ Verification

After deployment, verify in MetaTrader 5:

1. Open MetaEditor
2. Navigate to `Experts\EAsReleases`
3. Verify files are present

Or use PowerShell:

**Copy:** `Test-Path '..\..\Experts\EAsReleases\BreakoutScalper.ex5'`

## 🔍 Troubleshooting

### "Source directory not found"

- Check that `EA/_Release/` exists
- Ensure you're running from project root

### "No .ex5 files found"

- Compile your `.mq5` files first
- Check that `.ex5` files are in `EA/_Release/`

### "Failed to copy"

- Check file permissions
- Ensure MT5 is not running
- Verify destination path exists

## 🎯 Typical Workflow

1. **Compile** your EA in MetaEditor (F7)
2. **Test** the deployment: Copy `.\Deploy-Ex5Files.ps1 -WhatIf`
3. **Deploy**: Copy `.\Deploy-Ex5Files.ps1`
4. **Verify** in MT5 Navigator

## 📚 Related Files

- `EA/_Release/*.ex5` - Compiled Expert Advisors
- `EA/_Release/*.mq5` - Source files (reference only)
- `EA/_Release/CONFIGURATIONS_BY_GROUP.md` - Configuration guide

## 💡 Tips

- Use `-WhatIf` before actual deployment
- Always check output for errors
- Files are copied with `-Force` (overwrites existing)
- Script exits with code 0 on success, 1 on error

## 🎉 Success!

Files are now deployed and ready to use in MetaTrader 5!

---

**Last Updated**: 2025-01-27
**Version**: 1.0

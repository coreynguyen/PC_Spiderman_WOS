# Spider-Man: Web of Shadows Mesh Importer  
Import *Spider-Man: Web of Shadows* (`.component*.MESH`) models into **Blender 3.x** or **3ds Max 2016+**

![Blender 3.x](https://img.shields.io/badge/Blender-3.x_supported-orange)
![3ds Max 2016+](https://img.shields.io/badge/3ds_Max-2016%2B_supported-blue)
![License: Unlicense](https://img.shields.io/badge/License-Unlicense-lightgrey)


---

## ✨ What’s inside?
| Path | Description |
|------|-------------|
| `bpy_smwos_imp.py` | Blender add-on (install via **Edit ▸ Preferences ▸ Add-ons ▸ Install…**) |
| `mxs_smwos_imp.ms` | 3ds MaxScript loader (run with **MaxScript ▸ Run Script…**) |

> **Note** – At the moment the importer builds **vertices only**.  UVs, normals, weights, etc. are parsed but not yet connected.  PRs welcome!

---

## 🚀 Quick Start
### Blender 3.x
1. Copy `bpy_smwos_imp.py` somewhere handy.  
2. **Edit ▸ Preferences ▸ Add-ons ▸ Install…**, select the file, enable the checkbox.  
3. **File ▸ Import ▸ SMWOS (.component\*.MESH)**.  
4. Pick both the matching `component0.MESH` *and* `component1.MESH`.  
5. A coloured mesh appears in the viewport.

### 3ds Max 2016+
1. Download `mxs_smwos_imp.ms`.  
2. **MaxScript ▸ Run Script…**, select it.  
3. In the **SMWOS** dialog press **Open MESH**, choose a `component0.MESH`; the script locates the sibling `component1.MESH` automatically.

---

## 📂 Format Overview
* **component0.MESH** – header, mesh table, AABB, per-mesh metadata  
* **component1.MESH** – interleaved vertex blocks & triangle-strip indices  

See the heavily-commented MaxScript for byte-level details.

---

## 🔧 Roadmap
* Hook UVs, normals, vertex colours  
* Basic skeleton + skin weights  
* Material / texture auto-setup  
* Batch-import CLI  

---

## 🙏 Credits
* **Corey “mariokart64n” Van Nguyen** – reverse-engineering & tools  
* Discord community – sample files & format sleuthing  
* Blender Foundation / Autodesk – the essential DCCs

---

## ⚖️ License
Released under **[The Unlicense](https://unlicense.org/)** – this code is public domain.  
*Spider-Man: Web of Shadows* assets are © Activision & Marvel; use your own legally-obtained copies.

---


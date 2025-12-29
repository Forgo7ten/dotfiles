# core/ — Zsh 核心配置层规范

本目录定义 **Zsh 的最小、稳定、无插件依赖的核心运行环境**。

core 层的目标不是“好用”，而是：
- **可预测**
- **可推理**
- **长期稳定**

任何违反本规范的配置，都会被视为 *架构错误*。

---

## 一、core 层的职责边界

### core 层「必须」满足
- 不依赖任何插件（zinit / zimfw / oh-my-zsh 等）
- 不假设补全、高亮、autosuggest 已加载
- 不执行耗时或有副作用的操作
- 每次 shell 启动都可安全执行

### core 层「禁止」做的事
- 初始化插件
- clone / source 外部仓库
- 访问网络
- 执行 git / fzf / rg 等工具（函数定义除外）

---

## 二、加载顺序规范（强制）

core 层按 **阶段（stage）** 加载，顺序不可更改。

```text
00-bootstrap  →  10-env  →  20-options  →  30-keymap  →  40-behavior
```

任何文件只允许依赖 **位于其之前阶段** 的内容。

------

## 三、阶段划分与规则

### 00-bootstrap/ — Shell 基础语义

**目的**
建立最小、稳定的 Zsh 行为模型。

**允许**

-   `emulate -LR zsh`
-   `setopt` / `unsetopt`
-   `zmodload`

**禁止**

-   `PATH`
-   `export`
-   `alias`
-   `function`
-   `bindkey`

------

### 10-env/ — 环境变量层

**目的**
定义后续所有配置所依赖的环境。

**允许**

-   `export`
-   `typeset -gx`
-   PATH / MANPATH / FPATH 管理
-   XDG 变量定义

**禁止**

-   `alias`
-   `function`
-   `bindkey`
-   `setopt`

------

### 20-options/ — Zsh 行为层

**目的**
定义 Zsh 的工作方式。

**允许**

-   `setopt`
-   `unsetopt`

**禁止**

-   环境变量
-   `alias`
-   `function`
-   插件相关内容

------

### 30-keymap/ — 键位映射层

**目的**
定义键盘输入与 ZLE 行为。

**允许**

-   `bindkey`
-   keymap 切换（vi/emacs）

**禁止**

-   `alias`
-   `function`
-   插件 widget（除非延迟绑定）

------

### 40-behavior/ — 用户行为层

**目的**
定义人类直接使用的命令与函数。

**允许**

-   `alias`
-   `function`
-   轻量 wrapper（不执行耗时逻辑）

**禁止**

-   `setopt`
-   PATH 修改
-   插件初始化

------

## 四、目录结构约定

```text
core/
├── 00-bootstrap/
├── 10-env/
├── 20-options/
├── 30-keymap/
└── 40-behavior/
```

-   目录名中的数字决定加载顺序
-   子目录可自由扩展（如 aliases/、functions/）
-   文件名按字典序加载

------

## 五、命名与风格约定

-   所有文件必须以 `.zsh` 结尾
-   每个文件只做 **一类事情**
-   禁止“临时 hack”式代码
-   条件逻辑必须可解释（OS / hostname）

------

## 六、与其他层的关系

-   **core/**：定义 shell 的“物理定律”
-   **managers/**：插件管理与加载机制
-   **local/**：机器 / 环境差异

core 不允许引用：

-   managers
-   local

------

## 七、修改本目录前的自检清单

在提交任何 core 变更前，请确认：

-    是否放在正确的阶段目录？
-    是否只依赖前置阶段？
-    是否引入插件或外部依赖？
-    是否可能影响非交互 shell？
-    是否能在新机器上安全执行？

------

## 八、设计原则（一句话）

>   **core 层不是为了方便，而是为了保证一切都有“顺序”和“边界”。**


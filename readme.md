# Project Documentation (English / 中文)

## English Version

### Overview
This is a Godot-based 3D chessboard game project. It allows dynamic addition of chess pieces or dominos, drag‑and‑drop operations, color changes, and auxiliary information display. The architecture uses multithreading for level logic, includes a level selection system, and hides debug mode plus two test games as Easter eggs.

---

### Core Modules

#### 1. Board Control (`scripts/chess_board.gd`)
- Manages a 3D chessboard instance.
- Supports adding **chess pieces** or **dominos**.
- Supports **dragging** pieces/dominos.
- Supports **changing colors**.

#### 2. Auxiliary Display Functions (AI‑generated)
- **Show signposts** – displays extra information.
- **Highlight cuts** – highlights critical areas.
- Used to enhance interactive feedback on the board.

#### 3. Multithreaded Level Processing
- Uses an **independent thread** to start a level.
- User actions are abstracted into a `Move` struct.
- `Move` structs are sent to the **level thread** for processing, keeping the main thread responsive.

#### 4. Level Selection Control (`scripts/board_selector.gd`)
- Manages access rights for each level.
- Access data is stored as a **6×6 boolean array**.

#### 5. Utility Functions (`scripts/chess_utils.gd`)
- Provides various helper calculation methods for in‑game logic.

#### 6. Level Base Class (`level.gd`)
- All levels must inherit from `level.gd`.
- **Naming rule**: level class name must follow the format:  
    `Level_[row][col][name]`   

---

### Hidden Content
- A **debug mode** is hidden in the project.
- Two **test games** are included as Easter eggs for discovery.

---

### Technical Highlights
- Engine: Godot
- Language: GDScript (primary)
- Threading model: separate worker thread for game logic
- Data abstraction: `Move` struct for unified user input

---

*For detailed interfaces, please refer to the source code comments.*

---

## 中文版本

### 项目概述
这是一个基于 Godot 引擎的 3D 棋盘游戏项目，支持动态添加棋子/多米诺、拖拽操作、颜色修改，并提供辅助信息显示功能。项目采用多线程架构管理关卡逻辑，内置关卡选择系统和调试彩蛋。

---

### 核心功能模块

#### 1. 棋盘控制 (`scripts/chess_board.gd`)
- 控制 3D 棋盘实例
- 支持**添加棋子**或**多米诺骨牌**
- 支持**拖拽**棋子/多米诺
- 支持**修改颜色**

#### 2. 信息展示辅助（AI 生成函数）
- **显示倒三角标识** – 展示额外信息
- **高亮切割** – 突出显示关键区域
- 用于增强棋盘的交互反馈

#### 3. 多线程关卡处理
- 使用**独立线程**启动关卡
- 用户操作被抽象为 `Move` 结构体
- `Move` 结构体发送至**关卡线程**进行处理，保证主线程流畅

#### 4. 关卡选择控制 (`scripts/board_selector.gd`)
- 管理每个关卡的访问权限
- 权限数据存储为一个 **6×6 布尔数组**

#### 5. 通用工具函数 (`scripts/chess_utils.gd`)
- 提供各类辅助计算方法，便于游戏内逻辑运算

#### 6. 关卡基类 (`level.gd`)
- 所有关卡必须继承自 `level.gd`
- **命名规则**：关卡脚本类名必须按以下格式命名：  
  `Level_[row][col][name]`  
  程序会通过类名来关联关卡

---

### 隐藏内容
- 项目中隐藏了一个**调试模式**
- 包含**两个测试游戏**作为彩蛋，供探索发现

---

### 技术要点
- 引擎：Godot
- 语言：GDScript（主要）
- 线程模型：独立工作线程处理游戏逻辑
- 数据抽象：`Move` 结构体统一用户输入

---

*如需深入了解各模块接口，请查阅对应脚本源码注释。*
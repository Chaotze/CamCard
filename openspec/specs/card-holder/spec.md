# card-holder Specification

## Purpose

名片夹首页负责展示已保存的名片、在无数据时给出空状态与首要行动入口，并作为进入采集、搜索与管理流程的出发面。

## Requirements

### Requirement: Empty card holder state

当本地没有任何已保存名片时，名片夹 SHALL 显示空状态，包含标题、说明文案、"拍摄名片"与"从相册导入"两个入口，并且不显示任何名片行、分组头或统计数字。

#### Scenario: Fresh install shows empty card holder

- **WHEN** 用户在全新安装后首次进入名片夹
- **THEN** 页面显示空状态文案与"拍摄名片""从相册导入"两个入口，且名片行数量为 0

#### Scenario: Empty state hides list chrome

- **WHEN** 名片数量为 0
- **THEN** 不出现名片行、分组标题、计数标签或批量操作栏

#### Scenario: Last card deleted returns to empty state

- **WHEN** 用户删除名片夹中的最后一张名片
- **THEN** 页面在没有刷新或重启的情况下回到空状态

### Requirement: Card list presentation

名片夹 SHALL 以列表显示已保存名片，每行展示姓名字段的最终值、公司与职位摘要、首个电话或 Email 摘要，以及处理后图像的缩略图。

#### Scenario: Row shows final values

- **WHEN** 名片夹中存在至少一张名片
- **THEN** 每行展示该名片的姓名、公司摘要、职位摘要与首个可用联系方式

#### Scenario: Missing fields use neutral fallback

- **WHEN** 某张名片的姓名为空、公司或职位为空
- **THEN** 该行显示"未命名"占位标题，并只为有值的字段显示摘要，不显示推测值或空标签

#### Scenario: Summary prefers mobile then office then email

- **WHEN** 名片既有 Mobile 号码又有 Office 号码与 Email
- **THEN** 该行摘要优先显示 Mobile 号码

### Requirement: Card ordering

名片夹 SHALL 默认按创建时间倒序排列，最新保存的名片位于列表首位。

#### Scenario: Newest card is first

- **WHEN** 用户在已有三张名片的基础上保存一张新名片
- **THEN** 新名片出现在列表首位，其余名片的相对顺序不变

#### Scenario: Order survives relaunch

- **WHEN** 用户关闭并重新启动应用后打开名片夹
- **THEN** 列表顺序与关闭前一致

### Requirement: Card holder entry actions

名片夹 SHALL 提供"拍摄名片"与"从相册导入"入口，以及进入搜索与标签管理的入口。

#### Scenario: Entry actions are reachable

- **WHEN** 用户位于名片夹页面
- **THEN** 可触发拍摄、相册导入与搜索入口，且三者都不需要先选中某张名片

#### Scenario: Entry actions available with and without data

- **WHEN** 名片夹为空或已存在名片
- **THEN** 拍摄与相册导入入口在两种状态下都可用

### Requirement: Open a saved card from the card holder

名片夹 SHALL 允许用户点击任一名片行进入该名片的详情页面。

#### Scenario: Tapping a row opens detail

- **WHEN** 用户点击列表中的某张名片
- **THEN** 打开该名片对应的详情页面，显示的名片标识与所点击行一致

#### Scenario: Return from detail keeps context

- **WHEN** 用户从详情页面返回名片夹
- **THEN** 返回名片夹列表，且列表内容与刚才进入前一致

# Spec Delta

## Purpose

展示已保存名片的最终联系人信息与图像证据，提供编辑、删除与导出入口，并让用户随时回看整条识别与校正链路。

## ADDED Requirements

### Requirement: Detail shows final contact values

详情页 SHALL 展示该名片的最终字段值，并且只展示有值的字段；空字段不显示标签、不显示占位值，也不显示任何推测内容。

#### Scenario: Empty fields are hidden

- **WHEN** 名片没有网站、地址与备注
- **THEN** 详情页不出现网站、地址与备注条目，也不显示"未知"之类的占位文本

#### Scenario: Final values take precedence

- **WHEN** 用户曾把解析得到的职位改为另一个值并保存
- **THEN** 详情页显示人工修改后的职位

#### Scenario: Multiple phones grouped by category

- **WHEN** 名片含两个 Mobile 号码、一个 Office 号码与一个 Fax 号码
- **THEN** 详情页按 Mobile、Office、Fax 三组展示这四个号码

#### Scenario: Multiple emails shown in order

- **WHEN** 名片含两个 Email 地址
- **THEN** 详情页按保存顺序展示两个地址，并标明第一个为主动地址

#### Scenario: Optional fields shown only when present

- **WHEN** 名片填写了部门与邮编，但没有传真与备注
- **THEN** 详情页显示部门与邮编，不显示传真与备注条目

### Requirement: Detail shows card images

详情页 SHALL 提供该名片的原始图像与处理后图像，并标明当前查看的是哪一张；仅有一张可用时只展示可用的那张。

#### Scenario: Switch between original and processed

- **WHEN** 名片同时有原始图像与处理后图像
- **THEN** 用户可在两者之间切换查看，且界面标明当前图像类型

#### Scenario: Processed image unavailable

- **WHEN** 该名片在采集时检测失败、只保留原始图像
- **THEN** 详情页只展示原始图像，并说明未生成校正图像

### Requirement: Detail exposes the processing chain

详情页 SHALL 允许用户查看该名片的 OCR 原始文本与解析结构化字段，与最终联系人值一并对照。

#### Scenario: View raw text from detail

- **WHEN** 用户在详情页选择查看 OCR 原始文本
- **THEN** 显示该名片最近一次 OCR 的逐行文本，且内容与保存时一致

#### Scenario: Compare final and parsed values

- **WHEN** 用户对同一字段先后查看解析结构化结果与最终联系人值
- **THEN** 两者可分别展示，且解析结果未被最终值覆盖

### Requirement: Detail provides edit entry

详情页 SHALL 提供进入编辑的操作，编辑使用与人工校正相同的字段界面。

#### Scenario: Enter edit mode

- **WHEN** 用户在详情页点击编辑
- **THEN** 打开校正界面并预填该名片当前的最终值

### Requirement: Delete a card from detail

详情页 SHALL 提供删除操作，删除前要求用户确认；确认后删除该名片并返回名片夹。

#### Scenario: Confirm deletion

- **WHEN** 用户在详情页点击删除并在确认提示中选择确认
- **THEN** 名片被删除，界面返回名片夹，该名片不再出现在列表中

#### Scenario: Cancel deletion

- **WHEN** 用户在删除确认提示中选择取消
- **THEN** 名片保留，用户停留在详情页，名片夹内容不变

#### Scenario: Deleting the open card returns to holder

- **WHEN** 用户在详情页删除当前名片并确认
- **THEN** 不残留已删除名片的详情页面，返回名片夹

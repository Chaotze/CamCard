# card-detail-edit Specification

## Purpose

展示已保存名片的最终联系人信息与图像证据，提供编辑、删除与导出入口，并让用户随时回看整条识别与校正链路。

## Requirements

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

### Requirement: Detail shows a single card image

详情页 SHALL 只展示该名片唯一持久化的图像（优先校正图，缺失时使用原图），不提供原始图与校正图之间的切换控件。

#### Scenario: One image is shown

- **WHEN** 用户打开任意已保存名片的详情
- **THEN** 页面展示一张名片图像，且不出现"原始图像/处理后图像"分段切换控件

#### Scenario: Image unavailable

- **WHEN** 该名片的图像文件缺失或无法解码
- **THEN** 页面显示图像不可用占位，并保留全部文字字段

### Requirement: Detail follows the native iOS form style

详情页 SHALL 使用与人工校正页一致的 `Form` 分组列表风格，字段行展示轻量线形图标，图标在"字段标题 + 值"整体垂直居中，操作按钮使用系统默认样式且分隔线从行首开始。

#### Scenario: Field icons align with the whole row

- **WHEN** 详情页展示一个带标题和值的字段
- **THEN** 字段图标位于标题与值组成的整体高度中间，而不是只与标题对齐

#### Scenario: Native grouped list styling

- **WHEN** 用户浏览详情页
- **THEN** 内容以系统分组表单呈现，字段图标为线形 SF Symbol，导出与查看 OCR 文本按钮之间的分隔线从行首开始

### Requirement: Detail exposes the processing chain

详情页 SHALL 允许用户查看该名片的 OCR 原始文本与解析结构化字段，与最终联系人值一并对照。

#### Scenario: View raw text from detail

- **WHEN** 用户在详情页选择查看 OCR 原始文本
- **THEN** 显示该名片最近一次 OCR 的逐行文本，且内容与保存时一致

#### Scenario: Compare final and parsed values

- **WHEN** 用户对同一字段先后查看解析结构化结果与最终联系人值
- **THEN** 两者可分别展示，且解析结果未被最终值覆盖

### Requirement: Detail provides edit entry

详情页 SHALL 在右上角以图标按钮提供进入编辑的操作，编辑使用与人工校正相同的字段界面。

#### Scenario: Enter edit mode

- **WHEN** 用户在详情页点击右上角的编辑图标
- **THEN** 打开校正界面并预填该名片当前的最终值

#### Scenario: Edit from the card holder context menu

- **WHEN** 用户在名片夹长按某张名片并选择"编辑"
- **THEN** 直接进入该名片的详情并自动打开编辑界面

### Requirement: Delete a card from detail

详情页 SHALL 提供删除操作，删除前以系统 Alert 风格弹窗说明风险并展示被删除名片的人名，同时提供"删除"与"取消"；确认后删除该名片并返回名片夹。

#### Scenario: Confirm deletion

- **WHEN** 用户在详情页点击删除并在确认提示中选择"删除"
- **THEN** 弹窗文案包含该名片的人名与不可恢复说明，名片被删除，界面返回名片夹，该名片不再出现在列表中

#### Scenario: Cancel deletion

- **WHEN** 用户在删除确认提示中选择"取消"
- **THEN** 名片保留，用户停留在详情页，名片夹内容不变

#### Scenario: Deleting the open card returns to holder

- **WHEN** 用户在详情页删除当前名片并确认
- **THEN** 不残留已删除名片的详情页面，返回名片夹

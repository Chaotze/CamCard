# Spec Delta

## Purpose

在名片夹内提供搜索、标签、备注与排序能力，让用户能够在积累多张名片后快速定位与组织联系人，并支持搜索与标签筛选组合使用。

## ADDED Requirements

### Requirement: Search across contact fields

搜索 SHALL 在所有名片上匹配姓名、公司、职位、部门、全部电话号码（Mobile / Office / Fax）、全部 Email、网站、地址、邮编、备注与标签，采用不区分大小写的子串匹配。

#### Scenario: Match by name substring

- **WHEN** 用户输入姓名的一部分
- **THEN** 姓名包含该片段的名片出现在结果中，与片段大小写无关

#### Scenario: Match by company substring

- **WHEN** 用户输入公司名的一部分
- **THEN** 公司包含该片段的名片出现在结果中，与片段大小写无关

#### Scenario: Match by phone digits

- **WHEN** 用户输入电话号码中的连续数字片段
- **THEN** 包含该号码的名片出现在结果中，无论该号码属于 Mobile、Office 还是 Fax

#### Scenario: Match the second email

- **WHEN** 名片含两个 Email，用户输入第二个地址的片段
- **THEN** 该名片出现在结果中

#### Scenario: Match department or postal code

- **WHEN** 用户输入部门名或邮编片段
- **THEN** 部门或邮编包含该片段的名片出现在结果中

#### Scenario: Match Chinese text

- **WHEN** 用户输入中文公司名的一个字
- **THEN** 公司名包含该字的名片出现在结果中

#### Scenario: Match notes and tags

- **WHEN** 用户输入某个标签或备注中的词
- **THEN** 带该标签或备注包含该词的名片出现在结果中

### Requirement: Search clearing and empty results

清空搜索词后，系统 SHALL 恢复完整名片列表；当搜索无匹配时，系统 SHALL 显示与"名片夹为空"不同的无结果状态。

#### Scenario: Clear the search

- **WHEN** 用户清空搜索框
- **THEN** 列表恢复显示全部名片，且排序与搜索前一致

#### Scenario: No matching cards

- **WHEN** 搜索词不匹配任何名片，且名片夹中已有名片
- **THEN** 显示"无匹配结果"状态，不显示"名片夹为空"的空状态文案

### Requirement: Tag assignment

系统 SHALL 允许为名片添加与移除标签；标签在保存时去除首尾空白、忽略空标签，并按不区分大小写去重。

#### Scenario: Add a tag

- **WHEN** 用户为一张名片添加标签"客户"
- **THEN** 该名片详情显示"客户"，名片夹按标签筛选可命中该名片

#### Scenario: Duplicate tag ignored

- **WHEN** 用户为同一张名片再次添加"客户"或" 客户 "
- **THEN** 该名片仍只有一个"客户"标签

#### Scenario: Remove a tag

- **WHEN** 用户移除某张名片的标签
- **THEN** 该标签不再出现在该名片上，按该标签筛选时不再命中该名片

### Requirement: Tag filtering

名片夹 SHALL 支持按标签筛选名片；选中多个标签时，结果显示包含其中任一标签的名片。

#### Scenario: Filter by one tag

- **WHEN** 用户选中标签"客户"
- **THEN** 列表只显示带"客户"标签的名片

#### Scenario: Filter by multiple tags

- **WHEN** 用户同时选中标签"客户"与"供应商"
- **THEN** 列表显示带其中任一标签的名片，且不重复显示同时带两个标签的名片

#### Scenario: Clear tag filter

- **WHEN** 用户取消全部标签选择
- **THEN** 列表恢复显示全部名片

### Requirement: Notes editing

系统 SHALL 允许用户为名片添加、修改与删除备注，并完整保留备注中的换行与空白。

#### Scenario: Add a multiline note

- **WHEN** 用户输入包含两行的备注并保存
- **THEN** 详情页显示该备注，换行位置与输入时一致

#### Scenario: Delete a note

- **WHEN** 用户清空已有备注并保存
- **THEN** 该名片备注为空，详情页不显示备注条目

### Requirement: Sort options

名片夹 SHALL 支持按创建时间倒序（默认）、姓名升序与公司升序排序；排序结果在相同排序键下保持稳定。

#### Scenario: Sort by name

- **WHEN** 用户选择按姓名排序
- **THEN** 列表按姓名升序排列，姓名为空的名片排在末尾

#### Scenario: Switch back to default order

- **WHEN** 用户重新选择默认排序
- **THEN** 列表按创建时间倒序排列，最新名片位于首位

### Requirement: Combined search and tag filter

当搜索词与标签筛选同时生效时，系统 SHALL 返回同时满足两者的名片。

#### Scenario: Search within a tag

- **WHEN** 用户选中标签"客户"并输入某公司名片段
- **THEN** 结果只包含既带"客户"标签又匹配该片段的名片

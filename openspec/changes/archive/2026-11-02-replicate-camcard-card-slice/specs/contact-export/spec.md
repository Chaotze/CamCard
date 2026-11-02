# Spec Delta

## Purpose

把一张或多张名片导出为符合 vCard 3.0 的联系人文件，供系统通讯录或其他应用导入，并保证导出内容与名片最终值一一对应。

## ADDED Requirements

### Requirement: Export single or multiple cards

系统 SHALL 支持导出单张名片与多张选中名片；多张导出产出一个包含多条记录的文件。

#### Scenario: Export one card

- **WHEN** 用户对一张名片执行导出
- **THEN** 生成的文件包含一条 vCard 记录，其字段值与该名片最终值一致

#### Scenario: Export multiple cards

- **WHEN** 用户选中三张名片并执行导出
- **THEN** 生成的文件包含三条 vCard 记录，数量与所选名片一致

#### Scenario: Export empty selection is blocked

- **WHEN** 用户未选中任何名片时触发导出
- **THEN** 导出操作不可用，不生成空文件

### Requirement: vCard 3.0 file format

导出文件 SHALL 使用 vCard 3.0 格式，扩展名 `.vcf`，UTF-8 编码，换行使用 CRLF，每条记录以 `BEGIN:VCARD` 开始并以 `END:VCARD` 结束。

#### Scenario: File starts and ends with vCard markers

- **WHEN** 导出一张或多张名片
- **THEN** 文件以 `BEGIN:VCARD` 开头、以 `END:VCARD` 结尾，记录之间不夹带非 vCard 内容

#### Scenario: UTF-8 Chinese content

- **WHEN** 名片包含中文姓名与中文公司名
- **THEN** 导出文件以 UTF-8 编码保存这些文本，重新读取后中文内容不变

### Requirement: Field mapping

导出 SHALL 按固定映射写入 vCard：姓名写入 `N` 与 `FN`；公司写入 `ORG` 第一段、部门写入 `ORG` 第二段；职位写入 `TITLE`；Mobile 号码写入 `TEL;TYPE=CELL`；Office 号码写入 `TEL;TYPE=WORK`；Fax 号码写入 `TEL;TYPE=FAX`；全部 Email 写入 `EMAIL;TYPE=INTERNET` 且第一个附加 `PREF`；网站写入 `URL`；地址写入 `ADR` 街道组件、邮编写入 `ADR` 邮政编码组件；标签写入 `CATEGORIES`；备注写入 `NOTE`。

#### Scenario: Name and organization mapped

- **WHEN** 名片姓名、公司与部门均有值
- **THEN** 导出记录包含 `FN`、`N` 与 `ORG`，且 `ORG` 依次包含公司与部门

#### Scenario: Phone types preserved

- **WHEN** 名片含 Mobile、Office 与 Fax 号码各一个
- **THEN** 导出记录包含分别标记为 `CELL`、`WORK`、`FAX` 的三条 `TEL`

#### Scenario: Multiple emails exported

- **WHEN** 名片含两个 Email 地址
- **THEN** 导出记录包含两条 `EMAIL`，第一条带 `PREF` 标记，顺序与名片一致

#### Scenario: Tags and notes mapped

- **WHEN** 名片带两个标签与一段备注
- **THEN** 导出记录包含这两个标签的 `CATEGORIES` 与备注的 `NOTE`

### Requirement: Empty fields are omitted

导出 SHALL 跳过所有空字段，不写入只有属性名而没有值的条目，也不写入"未识别"等占位文本。

#### Scenario: Card without website

- **WHEN** 名片网站字段为空
- **THEN** 导出记录中不出现 `URL` 属性

#### Scenario: Card without email

- **WHEN** 名片 Email 字段为空
- **THEN** 导出记录中不出现 `EMAIL` 属性

### Requirement: Address mapping preserves original text

地址导出 SHALL 将名片地址的完整原文写入 `ADR` 的街道组件；有 `postalCode` 时写入 `ADR` 的邮政编码组件，其余组件留空，不拆分或推断省、市、国家。

#### Scenario: Unstructured address exported verbatim

- **WHEN** 名片地址为"北京市朝阳区建国路 88 号 3 层"且没有邮编
- **THEN** 导出记录的 `ADR` 保留该完整文本，且不出现推测出的邮编或国家字段

#### Scenario: Postal code mapped separately

- **WHEN** 名片地址与邮编分别有值
- **THEN** `ADR` 的街道组件为地址原文，邮政编码组件为邮编值，二者不被合并或互相改写

### Requirement: Special characters are escaped

导出 SHALL 按 vCard 规范转义文本中的反斜杠、分号、逗号与换行符，保证字段值不因特殊字符被截断。

#### Scenario: Comma in company name

- **WHEN** 公司名包含逗号
- **THEN** 导出后的公司名被转义，重新解析时仍为完整原始文本

#### Scenario: Multiline note

- **WHEN** 备注包含换行
- **THEN** 导出后换行以 vCard 转义形式保存，重新解析后备注仍保留换行

### Requirement: Export file naming and sharing

导出 SHALL 生成可识别的文件名并通过系统分享面板提供保存或发送；单张使用姓名派生的文件名，多张使用带时间戳的批量文件名。

#### Scenario: Single card filename

- **WHEN** 用户导出姓名为"张三"的名片
- **THEN** 生成文件名包含"张三"且以 `.vcf` 结尾，并去除路径分隔符等非法字符

#### Scenario: Multiple cards filename

- **WHEN** 用户导出多张名片
- **THEN** 生成文件名带时间戳标识，且不包含任何名片姓名

#### Scenario: Share sheet presented

- **WHEN** 导出文件生成成功
- **THEN** 呈现系统分享面板，用户可保存到文件或发送到其他应用

### Requirement: Export does not modify stored cards

导出 SHALL 只读取名片数据，不修改名片字段、标签、备注或创建时间，也不在名片夹中新增记录。

#### Scenario: Export leaves data unchanged

- **WHEN** 用户导出一张名片后返回名片夹
- **THEN** 该名片的字段值、标签、备注与创建时间与导出前一致

### Requirement: Round-trip fidelity

导出文件 SHALL 可被 vCard 解析器重新读取，并还原出与名片最终值一致的姓名、公司、部门、职位、Mobile/Office/Fax 号码、全部 Email、网站、地址、邮编、标签与备注。字段映射的验收 SHALL 以导出文件属性与最终值逐项比对、以及往返解析为依据；本能力不读取也不写入系统通讯录。

#### Scenario: Re-parse exported file

- **WHEN** 对导出的 `.vcf` 执行解析
- **THEN** 解析出的字段值与来源名片逐项一致，空字段仍然为空

#### Scenario: Multiple values survive round trip

- **WHEN** 名片含两个 Email 与三个不同类别的电话
- **THEN** 重新解析后仍得到两个 Email 与三个带类别的号码

#### Scenario: Mapping verified without contacts access

- **WHEN** 验收导出字段映射
- **THEN** 以导出 vCard 的属性值与名片最终值逐项比对并完成往返解析，且全过程不读取或写入系统通讯录

### Requirement: Export failure handling

当导出文件写入失败、磁盘空间不足或分享目标不可用时，系统 SHALL 提示导出失败并保留原名片数据，不得生成不完整或空文件。

#### Scenario: Write failure

- **WHEN** 写临时 `.vcf` 文件失败
- **THEN** 界面提示导出失败，不呈现分享面板，名片夹内容不变

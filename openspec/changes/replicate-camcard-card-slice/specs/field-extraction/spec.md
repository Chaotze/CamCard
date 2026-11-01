# Spec Delta

## Purpose

将 OCR Raw Text 解析为十二个固定字段（八个必填、四个可选），缺失即返回 nil，并保留字段级来源与置信度，作为人工校正与最终联系人的唯一结构来源。

## ADDED Requirements

### Requirement: Twelve structured fields

解析 SHALL 产出固定十二个字段：必填 `name`、`company`、`jobTitle`、`mobile`、`officePhone`、`email`、`website`、`address`，可选 `department`、`fax`、`postalCode`、`notes`；不得新增未在规格中定义的推断字段。

#### Scenario: All twelve fields present in the output

- **WHEN** 解析器处理任意一次 OCR 结果
- **THEN** 输出对象包含这十二个字段名，缺失的字段以 `nil` 或空集合表示

#### Scenario: Optional fields may stay empty

- **WHEN** 名片上没有部门、传真、邮编与备注信息
- **THEN** `department`、`fax`、`postalCode`、`notes` 均为空值，不影响其余字段的解析结果

#### Scenario: Field values come from raw text

- **WHEN** 解析器为一个字段产出非空值
- **THEN** 该值与原始文本中的某个连续或按规则拼接的片段一致

### Requirement: Missing fields return nil

当原始文本中不存在可确认的字段信息时，解析 SHALL 返回 `nil` 或空集合，禁止依据语义、常识或字段关联补充原图不存在的内容。

#### Scenario: No website on the card

- **WHEN** 名片原始文本中没有网址或域名信息
- **THEN** `website` 为 `nil`，即使该名片的 Email 带有域名也不得据此生成网址

#### Scenario: No email on the card

- **WHEN** 名片原始文本中没有 Email 地址
- **THEN** `email` 为空集合，不得拼造或补全用户名与域名

#### Scenario: No address on the card

- **WHEN** 名片原始文本中没有地址信息
- **THEN** `address` 为 `nil`，不得根据公司名或电话区号推断地址

#### Scenario: No postal code on the card

- **WHEN** 名片地址存在但没有邮编文本
- **THEN** `postalCode` 为 `nil`，不得从地址或区号推算邮编

#### Scenario: No company on the card

- **WHEN** 名片原始文本中只有姓名与电话
- **THEN** `company`、`jobTitle` 与 `department` 均为 `nil`

### Requirement: No semantic completion or rewriting

解析 SHALL 保留原文字面形式；不得翻译、纠正拼写、补全协议前缀、扩写缩写或把中文标签改写为其他语言。

#### Scenario: Website prefix preserved

- **WHEN** 原始文本中的网址写作 `www.example.com`
- **THEN** `website` 的值为 `www.example.com`，不自动改写为 `https://www.example.com`

#### Scenario: Company name stays verbatim

- **WHEN** 公司名在名片上为全大写形式
- **THEN** `company` 保持该全大写形式，不做大小写规范化

#### Scenario: No translated fields

- **WHEN** 名片上的职位写作"总经理"
- **THEN** `jobTitle` 为"总经理"，不转换为英文职位名

### Requirement: Phone classification into three fields

解析 SHALL 将每个电话号码归类为 Mobile、Office 或 Fax，并分别写入 `mobile`、`officePhone`、`fax` 三个字段；同类号码全部保留，不丢弃任何一个。

#### Scenario: Labeled phone numbers

- **WHEN** 名片分别标注"手机""Office""Fax"三个号码
- **THEN** 手机号写入 `mobile`，Office 号码写入 `officePhone`，传真号码写入 `fax`

#### Scenario: Multiple numbers of the same type

- **WHEN** 名片上有两个 Mobile 号码与两个 Office 号码
- **THEN** `mobile` 保留两个号码，`officePhone` 保留两个号码，数量不减少

#### Scenario: Unlabeled number defaults to mobile

- **WHEN** 一个号码没有任何类别标签且不是明显的 Office 或 Fax 格式
- **THEN** 该号码归入 `mobile`，并在来源信息中标记类别为推定

#### Scenario: Fax keyword detection

- **WHEN** 号码旁标注"Fax""传真"或 `F`
- **THEN** 该号码写入 `fax`，不写入 `mobile` 或 `officePhone`

### Requirement: Multiple email addresses

解析 SHALL 保留原始文本中出现的全部 Email 地址，按出现顺序排列，并把第一个作为主 Email；不得丢弃重复格式之外的其他地址。

#### Scenario: Two email addresses

- **WHEN** 名片上出现两个不同的 Email 地址
- **THEN** `email` 同时包含这两个地址，第一个为主 Email

#### Scenario: Duplicate email deduplicated

- **WHEN** 同一个 Email 在名片上以相同大小写出现两次
- **THEN** `email` 只保留一条，顺序不变

#### Scenario: Email case preserved

- **WHEN** 名片上的 Email 为全大写形式
- **THEN** `email` 保留该大小写形式，不做小写规范化

### Requirement: Department extraction

当原始文本包含部门或团队标签（如"Department""Dept""Division""部门"）时，解析 SHALL 把对应值写入 `department`；没有此类信息时保持 `nil`。

#### Scenario: Department with label

- **WHEN** 名片标注"部门：市场部"
- **THEN** `department` 为"市场部"

#### Scenario: Department inferred from job title is forbidden

- **WHEN** 名片只有职位"销售经理"而没有部门信息
- **THEN** `department` 为 `nil`，不得把职位拆成部门

### Requirement: Field ambiguity policy

当同一文本片段可能既是公司又是产品名时，解析 SHALL 按确定性规则判定：优先匹配 Email 域名或网址主机名；仍无法唯一确定时，将 `company` 与 `jobTitle` 置为 `nil` 并标记为歧义，交由人工校正。

#### Scenario: Company matches email domain

- **WHEN** 名片的 Email 域名为 `apple.com`，且文本中同时出现 "Apple" 与 "iPhone"
- **THEN** `company` 为 `Apple`，`jobTitle` 不取 "iPhone"

#### Scenario: Unresolvable ambiguity stays empty

- **WHEN** 文本片段既无域名佐证也无法通过版式或标签区分公司与职位
- **THEN** `company` 与 `jobTitle` 均为 `nil`，并且解析记录标记该处为歧义

### Requirement: Address preserved as written

`address` SHALL 保留原始文本的多行地址内容，按原文顺序拼接，不拆分省市区，不补全省市或国家。

#### Scenario: Multi-line address preserved

- **WHEN** 名片地址分为三行书写
- **THEN** `address` 保留这三行内容与顺序，不合并为推测的省市区结构

#### Scenario: Partial address not completed

- **WHEN** 名片只写了"朝阳区"而未写城市
- **THEN** `address` 仅为"朝阳区"，不补全城市或国家

### Requirement: Field provenance and confidence

解析 SHALL 为每个非空字段记录字段级置信度与来源文本行（含该行的坐标引用），供人工校正与准确率评估使用。

#### Scenario: Every populated field has provenance

- **WHEN** 解析产出任一非空字段
- **THEN** 该字段带有置信度与至少一条来源文本行引用

#### Scenario: Empty field has no fabricated provenance

- **WHEN** 某字段为空
- **THEN** 该字段不关联任何来源行，也不携带虚构的置信度

### Requirement: Deterministic extraction

对同一份 OCR Raw Text 与同一解析版本，解析 SHALL 产出完全相同的结构化字段与置信度，不依赖随机数、时间或设备区域设置。

#### Scenario: Same input produces same output

- **WHEN** 同一份原始文本被解析两次
- **THEN** 两次输出的字段值、空值位置与置信度完全一致

#### Scenario: Locale does not change results

- **WHEN** 设备区域设置从简体中文切换为英文后重新解析同一份原始文本
- **THEN** 解析结果与切换前一致

### Requirement: Structured output always produced

解析 SHALL 在 OCR 为空、失败或原始文本过短时仍产出一份结构化结果，全部字段为空并标记解析输入为空，而不是跳过解析或抛出未处理错误。

#### Scenario: Empty raw text yields empty structure

- **WHEN** OCR 返回空文本行集合
- **THEN** 解析产出十二个字段均为空的结构化结果，并标记输入为空

#### Scenario: Structured output survives manual correction

- **WHEN** 用户完成人工校正并保存名片
- **THEN** 该名片仍保留解析阶段的结构化结果，与最终联系人的值分别可访问

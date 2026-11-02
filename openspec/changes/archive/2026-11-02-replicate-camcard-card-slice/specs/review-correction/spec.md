# Spec Delta

## Purpose

在保存前提供人工校正界面，让用户逐字段核对与修改解析结果，记录每处修改的来源，并作为新建与编辑名片的统一入口。

## ADDED Requirements

### Requirement: Review shows all twelve fields

人工校正界面 SHALL 展示十二个字段（`name`、`company`、`jobTitle`、`mobile`、`officePhone`、`email`、`website`、`address`、`department`、`fax`、`postalCode`、`notes`）的当前值、对应的原始图像与处理后图像、以及 OCR Raw Text；空字段显示"未识别"状态，不得显示占位猜测值。

#### Scenario: Empty fields show unidentified state

- **WHEN** 姓名、公司、网站、部门、邮编等字段的解析结果为空
- **THEN** 对应字段显示"未识别"，输入框为空白，不预填任何推测文本

#### Scenario: Raw text and images reachable

- **WHEN** 用户进入人工校正界面
- **THEN** 可查看原始图像、处理后图像与该次 OCR 的原始文本

#### Scenario: Long address stays fully editable

- **WHEN** 解析出的地址包含多行文本
- **THEN** 地址字段以多行可编辑形式展示完整内容

#### Scenario: Optional fields do not block the form

- **WHEN** 部门、传真、邮编字段为空
- **THEN** 这些字段以空状态显示，不阻止用户继续编辑其他字段

### Requirement: Field-level manual correction

用户 SHALL 能够逐个编辑十二个字段中的任意字段，包括增删电话号码、增删 Email、修改电话类别，且修改不会影响 OCR Raw Text 与解析阶段的结构化记录。

#### Scenario: Edit a name

- **WHEN** 用户在姓名字段输入新值
- **THEN** 该字段显示新值，且 OCR Raw Text 保持不变

#### Scenario: Change phone category

- **WHEN** 用户把某个号码从 Office 改为 Mobile
- **THEN** 该号码从 `officePhone` 移除并出现在 `mobile`，其余号码不变

#### Scenario: Remove a phone number

- **WHEN** 用户删除某个电话号码
- **THEN** 该号码从校正界面消失，同类型的其他号码保持不变

#### Scenario: Add a second email

- **WHEN** 用户在 Email 字段追加第二个地址
- **THEN** 该字段保留两个地址，顺序与输入顺序一致，第一个仍为主动地址

#### Scenario: Edit a postal code

- **WHEN** 用户在邮编字段输入新值
- **THEN** 该字段显示新值，且不会因此改写地址字段

### Requirement: Field source marking

每个字段 SHALL 标明其当前值的来源：解析、人工修改，或未识别；字段被修改后立即由解析来源变为人工修改。

#### Scenario: Edited field is marked manual

- **WHEN** 用户修改某个原本由解析得到的字段
- **THEN** 该字段的来源标记显示为人工修改

#### Scenario: Untouched field stays parsed

- **WHEN** 用户只修改姓名，未改动其他字段
- **THEN** 其余有值字段的来源标记仍为解析，空字段标记为未识别

### Requirement: Restore parsed value

对任一被人工修改的字段，系统 SHALL 提供恢复为解析原值的操作。

#### Scenario: Restore a modified field

- **WHEN** 用户对已修改的姓名字段执行"恢复"
- **THEN** 姓名字段回到解析原值，来源标记回到解析；若原值为空则回到"未识别"并清空输入

#### Scenario: Restore is offered only for changed fields

- **WHEN** 字段从未被修改
- **THEN** 该字段不显示恢复操作，或该操作不可用

### Requirement: Save validation

当十二个字段与标签全部为空时，系统 SHALL 禁止保存并说明原因；只要有任一字段有值即可保存。

#### Scenario: All fields empty blocks saving

- **WHEN** 用户未填写任何字段并点击保存
- **THEN** 保存被阻止，界面提示至少填写一项信息，名片夹计数不变

#### Scenario: Single contact value allows saving

- **WHEN** 用户只填写了一个 Email，其余字段为空
- **THEN** 保存成功，名片以该 Email 作为唯一联系方式进入名片夹

#### Scenario: Optional-only data allows saving

- **WHEN** 用户只填写了部门与备注，其余字段为空
- **THEN** 保存成功，名片进入名片夹

### Requirement: Tags and notes during review

人工校正界面 SHALL 允许用户在保存前添加或移除标签、编辑备注。

#### Scenario: Add tags before saving

- **WHEN** 用户在校正界面添加两个标签并保存
- **THEN** 保存后的名片包含这两个标签

#### Scenario: Empty notes are allowed

- **WHEN** 用户不填写备注
- **THEN** 保存成功，名片备注为空，不写入占位文本

### Requirement: Save result and navigation

保存成功后，系统 SHALL 关闭校正界面，返回名片夹并把该名片插入到正确排序位置；同时保留解析链路与人工修改记录。

#### Scenario: Save returns to card holder

- **WHEN** 用户点击保存且校验通过
- **THEN** 返回名片夹，新名片出现在按创建时间倒序的正确位置

#### Scenario: Save keeps the full chain

- **WHEN** 名片保存完成后打开其详情
- **THEN** 可分别查看原始图像、处理后图像、OCR Raw Text、解析结构化字段与人工校正后的最终值

### Requirement: Review as the edit entry

已保存名片通过详情页进入编辑时，系统 SHALL 复用同一人工校正界面，并以该名片当前最终值作为初始状态。

#### Scenario: Edit existing card

- **WHEN** 用户从详情页进入编辑
- **THEN** 校正界面显示该名片当前值，来源标记为人工修改或解析，空字段显示"未识别"

#### Scenario: Editing does not change card count

- **WHEN** 用户编辑并保存一张已有名片
- **THEN** 名片数量不变，该名片内容被更新，其创建时间保持不变

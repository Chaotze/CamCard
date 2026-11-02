# persistence Specification

## Purpose

将名片元数据与图像可靠地保存在设备本地，保证应用重启后数据一致可读，并对 schema 版本、缺失文件与删除清理给出确定行为。

## Requirements

### Requirement: Local-only storage

名片数据与图像 SHALL 仅保存在应用沙盒内，不写入系统通讯录，不上传网络；无网络时全部读写能力保持可用。

#### Scenario: Offline save and reopen

- **WHEN** 设备处于飞行模式时用户保存名片并重启应用
- **THEN** 名片仍可读取、展示与编辑

#### Scenario: Storage writes do not touch contacts

- **WHEN** 用户保存或编辑名片
- **THEN** 系统通讯录中不新增或修改任何联系人

### Requirement: Atomic save

保存名片 SHALL 以单次原子操作完成；保存失败时不得留下部分写入的名片、图像或索引条目。

#### Scenario: Successful atomic save

- **WHEN** 用户在校正界面点击保存且存储可用
- **THEN** 名片元数据与两张图像同时可读，列表立即可见该名片

#### Scenario: Save failure leaves no partial card

- **WHEN** 保存过程中存储写入失败
- **THEN** 名片夹不出现该名片，且不残留该名片独占的图像文件

### Requirement: Images stored separately from metadata

图像 SHALL 以独立文件保存，名单元数据仅保存文件引用与图像类型；读取名片时按引用加载对应图像。

#### Scenario: Metadata and files both required

- **WHEN** 系统读取一张名片
- **THEN** 元数据来自索引存储，原始图像与处理后图像按引用分别加载

#### Scenario: Image file path is stable

- **WHEN** 用户编辑名片并保存
- **THEN** 该名片的图像引用仍指向同一组图像文件，不产生重复文件

### Requirement: Data survives kill and relaunch

用户创建、编辑、打标签、改备注或删除名片后，强制结束进程并重新启动应用，数据 SHALL 反映最后一次已保存的操作。

#### Scenario: Created card survives relaunch

- **WHEN** 用户保存一张新名片后强制结束应用并重新启动
- **THEN** 名片夹中出现该名片，字段值、标签与备注与保存时一致

#### Scenario: Edit survives relaunch

- **WHEN** 用户修改已有名片的姓名并保存，随后强制结束并重启应用
- **THEN** 该名片显示修改后的姓名，OCR 原始文本与解析结果仍可访问

#### Scenario: Deletion survives relaunch

- **WHEN** 用户删除一张名片后强制结束并重启应用
- **THEN** 该名片不再出现，其图像文件也不再占用存储

### Requirement: Missing or corrupt image handling

当名片的图像文件丢失或损坏时，系统 SHALL 仍展示该名片的文本信息并标注图像不可用，应用不得崩溃或清空整张名片。

#### Scenario: Missing original image

- **WHEN** 某名片的原始图像文件在沙盒中被移除后重新打开该名片
- **THEN** 详情页显示全部文本字段，并提示原始图像不可用

#### Scenario: Corrupt image file

- **WHEN** 图像文件存在但无法解码
- **THEN** 该名片仍出现在列表与详情中，缩略图显示占位，应用不崩溃

### Requirement: Storage schema versioning

持久化 SHALL 记录 schema 版本；读取时可识别旧版本并按已定义迁移读取，遇到未知或更高版本时拒绝写入并提示，不得静默覆盖数据。

#### Scenario: Known older version migrates

- **WHEN** 应用读取由较旧 schema 版本写入的名片数据
- **THEN** 名片被正常加载，字段与图像保持一致

#### Scenario: Unknown newer version is rejected

- **WHEN** 存储中的 schema 版本高于当前应用支持的版本
- **THEN** 系统拒绝写入并显示兼容性提示，原有数据不被改写

### Requirement: Deletion cleans up owned files

删除名片 SHALL 同时移除该名片独占的图像文件与相关记录，不留下孤立文件。

#### Scenario: Files removed with card

- **WHEN** 用户确认删除一张名片
- **THEN** 该名片的原始图像、处理后图像与索引记录一并移除

#### Scenario: Shared files are not deleted

- **WHEN** 两张名片引用同一图像文件，其中一张被删除
- **THEN** 另一张名片的图像仍可正常读取

### Requirement: Audit chain persisted with the card

持久化 SHALL 为每张名片保存 originalImage、processedImage、OCR Raw Text、Structured Fields、Manual Correction 与 Final Contact，并在重启后分别可读，供差异分析使用。

#### Scenario: Six-stage chain readable after relaunch

- **WHEN** 用户保存一张经过人工校正的名片并强制结束应用后重启
- **THEN** 该名片的六段记录均可分别读取，且 Structured Fields 与 Final Contact 的差异仍存在

#### Scenario: Final values never overwrite raw stages

- **WHEN** 用户多次编辑同一张名片并保存
- **THEN** OCR Raw Text 与 Structured Fields 的持久化内容保持首次解析时的值，仅 Manual Correction 与 Final Contact 随编辑更新

# Spec Delta

## Purpose

在设备本地识别名片图像中的文字，产出不可变的 OCR 原始文本及每行元数据，作为字段解析与错误追溯的唯一文字来源。

## ADDED Requirements

### Requirement: On-device OCR only

OCR SHALL 完全在设备本地执行；在任何情况下都不得把名片图像或识别文本发送到网络服务。

#### Scenario: Offline device performs OCR

- **WHEN** 设备处于飞行模式时用户采集名片并进入处理流程
- **THEN** OCR 正常完成，且不产生任何网络请求或网络错误提示

#### Scenario: No remote fallback

- **WHEN** 本地 OCR 失败
- **THEN** 系统报告本地失败状态，不尝试云端 OCR，也不上传图像

### Requirement: Raw text output structure

OCR SHALL 输出按阅读顺序排列的文本行集合，每行包含文本内容、识别置信度、在源图像中的归一化矩形坐标，并记录识别所用的图像来源（处理后图像或原始图像）。

#### Scenario: Lines carry text, confidence and position

- **WHEN** OCR 成功识别出名片上的多行文字
- **THEN** 每行结果都带有文本内容、置信度数值和归一化坐标，且坐标落在 0～1 范围内

#### Scenario: Reading order is preserved

- **WHEN** 名片的文字按从上到下、从左到右排布
- **THEN** 输出的文本行顺序与这一排布一致

#### Scenario: Source image is recorded

- **WHEN** OCR 使用处理后图像完成识别
- **THEN** 该次 OCR 记录标明来源为处理后图像

### Requirement: Raw text is immutable

OCR 原始文本 SHALL 一经产出即不可改写；人工校正、字段解析和最终联系人保存都不得覆盖或删除原始文本。

#### Scenario: Manual edit does not touch raw text

- **WHEN** 用户在人工校正界面修改姓名或电话
- **THEN** OCR 原始文本仍保留校正前的内容，且与校正前逐行一致

#### Scenario: Final save preserves raw text

- **WHEN** 用户保存名片并在详情页再次查看
- **THEN** 该名片的 OCR 原始文本仍可访问，内容与前一次记录一致

### Requirement: Re-run OCR appends a new record

重新执行 OCR 时，系统 SHALL 生成新的 OCR 记录并与既有记录并列保存，而不是覆盖既有记录。

#### Scenario: Second OCR run keeps history

- **WHEN** 用户对同一张名片重新执行一次 OCR
- **THEN** 该名片关联两条 OCR 记录，界面可区分其顺序，先前记录内容未改变

### Requirement: Empty or failed OCR handling

当 OCR 未能识别出任何文本或执行失败时，系统 SHALL 记录失败状态与原因，允许用户重拍、重新识别或以空字段进入人工校正。

#### Scenario: Blank or unreadable image

- **WHEN** 输入图像中没有可识别文字
- **THEN** OCR 返回空文本行集合与失败状态，且不生成任何猜测文本

#### Scenario: Continue to manual entry

- **WHEN** OCR 失败后用户选择继续
- **THEN** 进入人工校正界面，所有字段为空并标记为"未识别"，用户可手动填写

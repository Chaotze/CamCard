# scanner-capture Specification

## Purpose

采集名片图像，来源为相机实时拍摄或系统相册导入，并为权限拒绝、取消与采集失败提供明确的处理路径。该能力保证草稿在保存前不进入名片夹。

## Requirements

### Requirement: Camera capture entry

名片夹 SHALL 允许用户通过"拍摄名片"入口直接打开系统相机界面，拍摄一张名片照片并交给后续处理流程。

#### Scenario: Capture a card with the camera

- **WHEN** 用户点击"拍摄名片"，授予相机权限并完成一次拍摄
- **THEN** 系统以该拍摄图像作为本次采集结果，进入名片处理流程

#### Scenario: Camera opens directly without an intermediate page

- **WHEN** 用户点击"拍摄名片"或底部搜索栏的"扫描名片"
- **THEN** 系统相机界面直接弹出，不出现独立的拍摄选择页面；只有取得图像后才进入框选与校正流程

#### Scenario: Capture opens the camera only once per tap

- **WHEN** 用户点击一次"拍摄名片"
- **THEN** 只呈现一个相机界面，不重复叠加相机层

### Requirement: Photo library import entry

名片夹 SHALL 允许用户通过"从相册导入"入口直接从系统相册选择一张图片作为采集结果。

#### Scenario: Import a photo from the library

- **WHEN** 用户在相册中选择一张图片并确认
- **THEN** 系统以该图片作为本次采集结果，进入名片处理流程

#### Scenario: Photo picker opens directly without an intermediate page

- **WHEN** 用户点击"从相册导入"或底部搜索栏的"从相册导入"
- **THEN** 系统相册选择器直接弹出；取得图片后才进入框选与校正流程

#### Scenario: Single image per import

- **WHEN** 用户一次相册导入同时选中多张图片
- **THEN** 本次仅采用第一张已选图片，其余图片不进入处理队列，也不生成名片

### Requirement: Camera permission denial

当相机权限被拒绝或受限时，系统 SHALL 显示可解释的提示，并提供"请求相机权限"、"从相册导入"与"取消"三个操作；请求权限 SHALL 直接调用系统相机授权，而不是替用户打开系统设置。

#### Scenario: Denied camera permission

- **WHEN** 用户在权限弹窗中拒绝相机访问，或此前已关闭相机权限
- **THEN** 用户看到说明文案，以及"请求相机权限""从相册导入""取消"三个操作，且"从相册导入"仍然可用

#### Scenario: Request permission from the alert

- **WHEN** 用户在权限提示中点击"请求相机权限"
- **THEN** 系统直接发起相机授权请求；授权成功后打开相机，失败时说明原因且不跳转系统设置

#### Scenario: Limited camera access on first use

- **WHEN** 相机权限为首次请求且用户尚未作出选择
- **THEN** 在用户作出选择前不显示拒绝提示

### Requirement: Cancel or dismiss a capture

用户在采集过程中取消或关闭相机、相册 SHALL 返回名片夹，且不产生草稿、不新增名片。

#### Scenario: Cancel camera capture

- **WHEN** 用户在相机界面点击取消
- **THEN** 返回名片夹，名片数量不变，且不出现任何待处理的草稿界面

#### Scenario: Dismiss photo picker

- **WHEN** 用户关闭相册选择界面且未选择图片
- **THEN** 返回名片夹，名片数量不变

### Requirement: Capture failure handling

当相机不可用、图片无法读取或写入临时文件失败时，系统 SHALL 显示失败提示并停留在名片夹，且不新增名片。

#### Scenario: Camera unavailable

- **WHEN** 参考设备没有可用相机，或相机初始化失败
- **THEN** 系统显示失败提示，用户仍可通过相册导入继续，名片数量不变

#### Scenario: Unreadable image

- **WHEN** 用户导入的图片无法解码
- **THEN** 系统显示失败提示，不创建草稿，名片数量不变

### Requirement: Captured image stays out of the card holder until saved

采集得到的图像 SHALL 只作为未保存草稿进入处理与校正流程；在用户明确保存前，名片夹的列表与计数不包含该草稿。

#### Scenario: Draft is absent from the card holder

- **WHEN** 用户完成拍摄或导入，但尚未在人工校正界面点击保存
- **THEN** 名片夹列表与计数不包含该草稿

#### Scenario: Abandoning a draft leaves no trace

- **WHEN** 用户在处理或校正流程中放弃并返回名片夹
- **THEN** 名片夹列表与计数不变，且不保留该草稿

### Requirement: Retake from the processing flow

无法识别页面 SHALL 提供重新拍摄入口；重拍 SHALL 开启新的采集会话并丢弃当前草稿，不把旧草稿并入新名片。

#### Scenario: Retake replaces the draft

- **WHEN** 用户在校正界面选择重拍并完成一次新的相册导入
- **THEN** 界面显示新草稿的处理结果，旧草稿的字段与图像不再可访问

#### Scenario: Cancel a retake

- **WHEN** 用户在选择重拍后取消新的采集
- **THEN** 返回原流程状态，当前草稿保持不变，名片夹计数不变

### Requirement: Unrecognizable image handling

当采集图像经用户确认框选后仍无法识别出名片文本时，系统 SHALL 明确提示无法识别，并只提供重新拍摄与手动填写两条路径，不得以空字段静默进入保存。

#### Scenario: No text recognized

- **WHEN** 采集图像经框选与 OCR 后没有任何可识别文本
- **THEN** 界面提示无法识别，并提供"重新拍摄"与"手动填写"，不提供直接保存

#### Scenario: User proceeds with empty fields

- **WHEN** 用户从无法识别状态选择手动填写
- **THEN** 进入校正界面且所有字段为"未识别"，保存仍受"至少一项有值"校验约束

#### Scenario: Retake after unrecognizable image

- **WHEN** 用户在无法识别提示中选择重拍并完成新采集
- **THEN** 系统以新图像重新执行检测与 OCR，旧草稿被丢弃

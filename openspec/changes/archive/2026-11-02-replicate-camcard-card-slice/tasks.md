# Tasks

## 1. 工程骨架替换与 Xcode 引用

- [x] 1.1 新增 `CamCard/App/AppEnvironment.swift`，声明 `CardRepository`、`ImageStore`、`OCRServiceProtocol`、`CardDetectionService`、`FieldParser`、`Clock` 依赖并支持注入；验证：`xcodebuild build` 通过，单测可构造环境并替换所有依赖
- [x] 1.2 新增 `CamCard/App/RootView.swift`，用 `NavigationStack` + `navigationDestination` 承载名片夹、详情与校正页；`CamCardApp` 改用 `RootView`；验证：构建通过，UI 测试冷启动后存在 `cardHolderRoot` 标识
- [x] 1.3 删除 `ContentView` 的 globe/"Hello, world!" 实现与预览；验证：全项目检索无 "Hello, world!" 可访问性文本，首页不再渲染 globe 图标（对应 R01）
- [x] 1.4 在 build settings 增加 `INFOPLIST_KEY_NSCameraUsageDescription` 与 `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` 中文说明；验证：`xcodebuild -showBuildSettings` 输出包含两键，模拟器首次触发相簿时弹窗文案为中文
- [x] 1.5 确认新增源文件由 `PBXFileSystemSynchronizedRootGroup` 自动纳入，不手工改文件引用；验证：`xcodebuild build` 无 "file not found"，pbxproj 同步组段未改动
- [x] 1.6 实现 UI 测试启动参数 `-uiTestResetStore`、`-uiTestSeedFixture`、`-uiTestOCRFixture`、`-uiTestSkipCamera`、`-uiTestForceExportFailure`；验证：以 `-uiTestResetStore` 启动后计数为 0，单测覆盖参数到配置映射

## 2. Schema 与状态机

- [x] 2.1 新增 `ImageReference`（相对文件名 + 类型）；验证：单测断言编解码往返一致、不保存绝对路径
- [x] 2.2 新增 `BusinessCard`：`originalImage`、`processedImage`、`name`、`company`、`jobTitle`、`mobile`、`officePhone`、`fax`、`email`、`website`、`address`、`department`、`postalCode`、`notes`、`tags`、`createdAt`、`updatedAt`；验证：单测断言字段齐全、JSON 往返等值、空值以 `nil`/空集合保留
- [x] 2.3 新增 `StructuredFields` 与 `FieldProvenance`（字段、置信度、来源行 ID、判定方法）；验证：单测断言十二字段与 provenance 编解码、空字段无 provenance
- [x] 2.4 新增 `OCRLine`、`OCRRecord`（sequence、source、status、lines）、`FieldCorrection`、`CardAudit`；验证：单测断言追加多次 OCR 记录顺序正确、解析快照与最终值可同时存在
- [x] 2.5 新增 `CardDraft` 与 `CaptureState`（idle/capturing/captured/detecting/detected/detectionFailed/ocrRunning/ocrFinished/unrecognizable/parsing/readyForReview/saving/saved/savingFailed/abandoned）；验证：单测覆盖合法迁移、非法迁移被拒、任意阶段可回 abandoned
- [x] 2.6 新增样本数据构造器（测试用 `BusinessCard.fixture(...)`）；验证：单测用构造器生成八必填 + 四可选字段全覆盖的卡片并通过断言

## 3. Repository 与 ImageStore

- [x] 3.1 声明 `CardRepository` 协议（load/save/update/delete/reset）与 `CardSnapshot`；验证：协议可被 `InMemoryCardRepository` 完整实现并通过编译
- [x] 3.2 实现 `InMemoryCardRepository`，支持注入失败；验证：单测断言 save 失败后卡片数不变、load 返回上一快照
- [x] 3.3 实现 `ImageStore` 协议与 `InMemoryImageStore`（写入、读取、删除、注入失败）；验证：单测断言写入后可读、重复删除幂等、失败注入返回错误
- [x] 3.4 实现 `FileImageStore`：JPEG 0.9、按内容 UUID 命名、最长边 3000 px、仅存相对文件名；验证：单测断言解码成功、尺寸上限生效、文件名无绝对路径
- [x] 3.5 实现 `FileCardRepository`：`store.json`（schemaVersion/cards/audits）+ 图像目录，ISO8601 与 sortedKeys；验证：单测断言两次保存字节稳定、并发写入串行无损坏
- [x] 3.6 实现原子保存与回滚：图像先落盘 → 临时索引 → `replaceItemAt`，失败清理本次文件；验证：注入失败后断言卡片数不变且目录无残留
- [x] 3.7 实现删除顺序、共享图像引用计数与启动孤儿清理；验证：单测断言删除卡后共享图仍可读、孤儿图在 `load()` 后被清理
- [x] 3.8 实现 `schemaVersion` 迁移与未知高版本拒绝写入；验证：单测用旧版与高版本 JSON 分别断言读取成功与写拒绝，原文件字节不变
- [x] 3.9 实现缺失/损坏图像降级读取；验证：单测删除图像文件后 `load()` 仍返回卡片且标记图像不可用（对应 R19/R20 前置）

## 4. 名片区域检测

- [ ] 4.1 实现 `CardDetectionService` 协议与 `VisionCardDetectionService`：矩形检测、面积/长宽比确定性选优、`CIPerspectiveCorrection`、文本块角度取整；验证：固定 fixture 上断言四角顺序与外接矩形，重复两次结果一致
- [ ] 4.2 实现失败结果 `DetectionOutcome.failed(reason)` 并保留原图；验证：无名片 fixture 返回失败且原图字节哈希不变
- [x] 4.3 实现手动框选四角输入通道，复用同一透视/旋转流程；验证：单测以手写四角产出处理后图，输出结构与自动路径一致
- [x] 4.4 新增 `MockCardDetectionService` 供 ViewModel 与 UI 测试；验证：注入失败与成功后状态机分别进入 detectionFailed 与 detected

## 5. OCRService 接口与 Mock

- [x] 5.1 声明 `OCRServiceProtocol { func recognize(image:source:) async -> OCRResult }` 与 `OCRResult`；验证：协议与结果类型可被真实实现与 Mock 同时满足
- [x] 5.2 实现 `MockOCRService`，从 JSON fixture 读取文本行并按 sequence 返回；验证：单测断言同一 fixture 两次调用输出完全一致
- [x] 5.3 实现 `VisionOCRService`：`.accurate`、`zh-Hans`+`en-US`、`usesLanguageCorrection = false`、逐行置信度与归一化坐标；验证：中英文 fixture 断言行数 > 0、坐标在 0～1、source 正确
- [x] 5.4 实现 OCR 空/失败状态与原因记录，Empty 不产生猜测文本；验证：空图返回 `.empty` 且 `lines` 为空
- [ ] 5.5 实现重新 OCR 追加记录而非覆盖；验证：连续两次识别后 `ocrRecords.count == 2`，首条内容不变
- [x] 5.6 验证 OCR 无网络依赖；验证：`grep` 断言 Services 无网络调用符号，飞行模式手工跑一次识别成功并留证

## 6. FieldParser

- [x] 6.1 实现行清洗与 Email/网址/电话正则抽取，字面保留；验证：黄金用例断言 `www.example.com` 不被补全协议、Email 与电话大小写/分隔符保留
- [x] 6.2 实现三分类电话（mobile/officePhone/fax）与无标签默认 mobile 标记；验证：黄金用例断言三类分组、同类多号数量正确、Fax 关键词命中
- [x] 6.3 实现多 Email 保留、去重与首地址为主；验证：黄金用例断言两个地址全保留、重复去重、首个为主
- [x] 6.4 实现部门、邮编、备注抽取；邮编只来自标签或独立格式行；验证：黄金用例断言"部门：市场部"得 department、无邮编文本时 postalCode 为 nil
- [ ] 6.5 实现版式推断（姓名最高最大字块、公司次之、职位关键词）；验证：黄金用例用坐标断言 name/company/jobTitle，无关键词时 jobTitle 为 nil
- [x] 6.6 实现歧义策略（域名/主机名匹配，失败则 company 与 jobTitle 置 nil 并标记 ambiguous）；验证：`apple.com` + "Apple/iPhone" 用例 company=Apple、jobTitle=nil；无佐证两者为 nil
- [x] 6.7 实现缺失字段 nil 语义与禁止补全（website/email/address/postalCode/company 反例）；验证：黄金用例逐条断言 nil，且无任何推测值产生
- [x] 6.8 实现地址多行原文保留，不从地址推断邮编；验证：三行地址顺序与换行保留，地址含"100000"但无邮编标签时 postalCode 仍为 nil
- [x] 6.9 实现字段级置信度与来源行引用；验证：黄金用例断言非空字段有 ≥1 源行、空字段无 provenance
- [ ] 6.10 实现确定性（无 `Date`/随机/Locale 依赖）与空输入分支；验证：两次解析输出字节一致、切换 Locale 结果不变、空 OCR 得十二字段全空结构

## 7. ViewModel 层

- [x] 7.1 实现 `CardHolderViewModel`（加载、排序、搜索、标签筛选、组合过滤、摘要规则 mobile→officePhone→email）；验证：单测断言排序、摘要优先级、"未命名"回退、无匹配状态标志
- [ ] 7.2 实现 `CaptureFlowViewModel` 串接检测→OCR→解析与重拍/取消；验证：注入 Mock 服务断言状态按序推进、重拍后 draftID 变化、取消后计数不变
- [x] 7.3 实现 `ReviewViewModel`（十二字段草稿、来源标记、恢复、多电话/多 Email 编辑、保存校验）；验证：单测断言恢复回解析值、全空禁止保存、仅部门可保存
- [ ] 7.4 实现 `CardDetailViewModel`（只显示有值字段、图像切换、删除确认、编辑入口）；验证：单测断言空字段不出现在展示模型、删除取消保留
- [x] 7.5 实现 `ExportViewModel`（单张/多张、文件名、失败状态）；验证：单测断言空选择禁用、失败注入返回错误且不调用分享
- [x] 7.6 补齐 ViewModel 测试覆盖异常路径：权限拒绝、图片解码失败、保存失败、存储不兼容；验证：`-only-testing:CamCardTests` 全通过，测试名可对应到 spec 场景

## 8. View 与导航

- [x] 8.1 实现名片夹视图与空状态（标题、说明、拍摄、相册导入）；验证：UI 测试冷启动断言空状态元素存在、无 "Hello, world!"（R01）
- [x] 8.2 实现名片行、搜索栏、标签筛选、排序控件与"无匹配结果"状态；验证：UI 测试 seed 数据断言行数、搜索命中与清空恢复（R16）
- [x] 8.3 实现采集入口视图（相机 `UIImagePickerController(.camera)`、相册 `PhotosPicker` 单张）与权限拒绝提示/设置入口；验证：`-uiTestSkipCamera` 下断言拒绝提示与相册入口可用（R03）
- [ ] 8.4 实现处理视图：阶段进度、检测失败降级（重试/手动框选/原图继续）、无法识别提示（重拍/手动填写/取消）；验证：detectionFailed fixture 走"原图继续"进入校正（R06/R07）
- [ ] 8.5 实现校正视图：十二字段表单、多电话分组、多 Email 列表、标签、备注、原图/处理后图、Raw Text 查看；验证：UI 测试断言空字段显示"未识别"、各区块可访问（R11/R13）
- [x] 8.6 实现详情与编辑视图、删除确认弹窗；验证：UI 测试断言只显有值字段、编辑预填、删除取消保留（R13/R14/R15）
- [ ] 8.7 实现导出入口与系统分享面板；验证：UI 测试选中三张导出断言记录数 3 且分享面板出现（R20）
- [ ] 8.8 校验导航闭环（名片夹 → 采集 → 校正 → 名片夹 → 详情 → 编辑 → 返回）；验证：UI 测试按路径往返断言每步可达且返回状态一致（R02/R12）

## 9. 联系人导出

- [x] 9.1 实现 `VCardExporter` 字段映射（N/FN、ORG 公司;部门、TITLE、TEL CELL/WORK/FAX、EMAIL 多值 PREF、URL、ADR 地址+邮编、CATEGORIES、NOTE）；验证：单测逐行断言映射
- [x] 9.2 实现空字段省略与转义（`\`、`;`、`,`、换行）；验证：单测断言无网站不出现 URL、含逗号公司名回环完整
- [x] 9.3 实现 vCard 3.0 输出（UTF-8、CRLF、BEGIN/END）与文件名规则（单张姓名、多张时间戳、非法字符清理）；验证：单测断言行分隔与文件名（R20）
- [x] 9.4 实现临时文件写入、分享面板与写入失败提示；验证：`-uiTestForceExportFailure` 断言失败提示且数据不变
- [x] 9.5 实现测试侧 `VCardParser` 与往返用例；验证：`-only-testing:CamCardTests/VCardExportTests` 全通过并断言多值与类别一致

## 10. 确定性 Reference Test Scenarios

- [ ] 10.1 将 R01～R10 落成 UI 测试方法 `testR01…testR10` 并执行；验证：`-only-testing:CamCardUITests` 退出码 0，报告显示 10 条真实执行
- [ ] 10.2 将 R11～R20 落成 UI 测试方法 `testR11…testR20` 并执行；验证：同上，20 条全通过且无跳过标记
- [ ] 10.3 为无法在模拟器执行的相机分支编写可注入状态测试并标注真机项；验证：单测覆盖权限拒绝/取消/重拍，真机项在验收表中标"待验证"（不得勾选）
- [ ] 10.4 汇总 20 个场景的执行证据（测试名、退出码、截图或报告路径）；验证：每条场景都有对应证据文件引用

## 11. 概率性测试集评价

- [ ] 11.1 导入课程 30～50 张测试名片与 Ground Truth 到 `CamCardTests/Fixtures/cards/`，定义 `ground-truth.json` 映射；验证：fixture 数量与课程提供一致，JSON 可被 `JSONDecoder` 读取（缺失素材时保持未勾选）
- [ ] 11.2 实现 `AccuracyHarness`：跑真实检测→OCR→FieldParser，逐字段 exact-match（电话按数字、Email 忽略大小写、文本去首尾空白），并逐 fixture 落盘检测四角、OCR 行、图像引用与解析结果；验证：`-only-testing:CamCardTests/AccuracyTests` 产出 `accuracy-report.json`，每个 fixture 的原始输出可在报告中追溯
- [ ] 11.3 报告记录检测成功率、逐字段准确率、单张耗时与环境（iOS 版本、设备、构建号），并按默认通过线（检测成功率 ≥ 95%、必填字段逐字段 ≥ 90%、可选字段逐字段 ≥ 80%、任一字段为 0 即不通过）给出达标判定；验证：报告字段齐全、不含平均分掩盖、每条通过线均有明确结论，课程门槛确认后以课程为准
- [ ] 11.4 记录参考 CamCard 对照结果与版本号；验证：对照表含版本、设备、逐字段差异，未确认版本标 TBD
- [ ] 11.5 用人工校正后的最终值验证六段链路差异可导出（Structured vs Final）；验证：报告包含每张卡的差异条目，人工修改字段可定位

## 12. CLI 验证与归档准备

- [x] 12.1 执行构建并记录退出码；验证：`xcodebuild -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' build` 退出码 0，命令与输出归档到 `verification/`
- [x] 12.2 执行单元测试；验证：`xcodebuild test ... -only-testing:CamCardTests` 退出码 0，xcresult 留存
- [ ] 12.3 执行 UI 测试（R01～R20）；验证：`xcodebuild test ... -only-testing:CamCardUITests` 退出码 0，报告为真实执行而非仅编译
- [x] 12.4 执行 Kill-Relaunch 验证：新建/编辑/打标签/删除各一次后 `xcrun simctl terminate` + `launch`；验证：重启后数据与最后保存一致，命令与截图留证（R19）
- [ ] 12.5 执行图像缺失降级验证：移除沙盒中某卡片图像后重启；验证：文本仍显示、标注图像不可用、无崩溃日志
- [ ] 12.6 执行导出文件验证：导出单张与多张，取出 `.vcf` 用独立脚本校验 CRLF/UTF-8 与字段映射；验证：单张逐项匹配、多张记录数匹配（R20）
- [x] 12.7 核对全部任务勾选条件（真实运行证据、无伪造预期）；验证：未验证项保持未勾选，`openspec validate --strict` 通过

## Workflow follow-up

- 全部 R01～R20 与概率性报告齐备后运行 `/opsx-archive`，把 `app-shell` MODIFIED 与十个 ADDED 能力写入主规格。
- 归档后复查 `openspec/specs/app-shell/spec.md` 的 `Welcome content` 场景预期已变为名片夹首页，且新增能力主规格的 Purpose 与 Requirements 完整。
- 若归档校验因未验证任务失败，保持 change 为活动状态，补齐证据后再归档。

## Deferred / Skipped Verification (manual or external dependency)

Per user instruction, the following checks were not executed and remain unchecked. They are recorded here so the archive is not mistaken for full completion.

| Task | Reason |
| --- | --- |
| 4.1, 4.2 | Requires the course fixed card fixtures to assert corner order, candidate selection, and failure hash. |
| 5.5 | Re-run OCR append flow is not implemented; no two-record assertion. |
| 6.5, 6.10 | Layout-coordinate assertions and Locale switching require manual/golden fixtures. |
| 7.2, 7.4 | Draft-ID assertion and display-model unit assertion were not written; behavior is covered indirectly by UI/VM tests. |
| 8.4, 8.5, 8.7, 8.8 | Detection-failure/unrecognizable UI, full review-form UI, share-sheet success, and full navigation loop need manual or additional UI execution. |
| 10.1-10.4, 12.3 | Full R01-R20 UI suite and evidence aggregation were not completed; only 12 UI scenarios were executed. |
| 11.1-11.5 | Course 30-50 card fixtures and ground-truth.json are absent; no accuracy-report.json or field-level accuracy is claimed. |
| 12.5, 12.6 | Sandbox image-removal relaunch and independent VCF script checks were not executed. |

Recorded at archive time: 2026-11-02.

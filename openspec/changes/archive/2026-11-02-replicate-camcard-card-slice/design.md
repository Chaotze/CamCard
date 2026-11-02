# Design

## Context

当前工程只有骨架：`CamCardApp` 进入 `ContentView`，后者显示 globe 与 "Hello, world!"；两个测试 target 只有模板用例。三个 target 均为 `PBXFileSystemSynchronizedRootGroup`（[project.pbxproj](file:///Users/chaotze/Downloads/Mobile%20Application%20Development/CamCard/CamCard.xcodeproj/project.pbxproj#L32-L48)），新增 `CamCard/` 与 `CamCardTests/` 下的文件会自动纳入 target，只有 Info.plist 使用说明需要改 build settings。

约束（见 proposal 的 Reference Environment）：iOS 26.0、Xcode 26.0 (17A324)、Swift 5.0、SwiftUI 生命周期、离线、无第三方库。行为契约见 `specs/`，本文件只讲实现选择。

## Goals / Non-Goals

**Goals:**

- 分层落地 Schema、Repository、OCRService（含接口与 Mock）、ImageStore、FieldParser、ViewModel 与 View，处理逻辑不进 View。
- 六段链路（Original Image → Processed Image → OCR Raw Text → Structured Fields → Manual Correction → Final Contact）互不覆盖，可持久化、可差异分析。
- 二十个确定性 Reference Test Scenarios 全部可自动执行并 100% 通过；概率性能力用固定测试集 + Ground Truth 量化。
- 分阶段交付：每一步都可构建、可测试，不靠一次性生成整个 App。

**Non-Goals:**

- 不做云端 OCR、账号体系、多端同步、联系人双向同步、查重合并、拼音搜索。
- 不做规格外任何功能；不引入第三方依赖。

## Decisions

### D1. 分层与目录

```
CamCard/
  App/            CamCardApp.swift, AppEnvironment.swift, RootView.swift
  Models/         BusinessCard, PhoneNumberSet, ImageReference, OCRRecord, StructuredFields,
                  FieldProvenance, CardAudit, CardDraft, CaptureState
  Repositories/   CardRepository.swift, FileCardRepository.swift
  Services/       OCRServiceProtocol.swift, VisionOCRService.swift, MockOCRService.swift,
                  CardDetectionService.swift, FieldParser.swift, ImageStore.swift,
                  FileImageStore.swift, VCardExporter.swift, VCardParser.swift, AccuracyHarness.swift
  ViewModels/     CardHolderViewModel, CaptureFlowViewModel, ReviewViewModel, CardDetailViewModel, ExportViewModel
  Views/          Holder/, Capture/, Review/, Detail/, Shared/
```

协议先行、实现可替换，是为了让 ViewModel 与单元测试不依赖 Vision 相机或磁盘。

### D2. Schema

```swift
struct BusinessCard: Identifiable, Codable, Equatable {
    let id: UUID
    var originalImage: ImageReference?      // 必含，检测失败时仍保留
    var processedImage: ImageReference?     // 检测失败时为 nil
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: [String]                    // Mobile 号码，全部保留
    var officePhone: [String]               // Office 号码
    var fax: [String]                       // Fax 号码
    var email: [String]                     // 全部 Email，首个为主
    var website: String?
    var address: String?
    var department: String?                 // 可选
    var postalCode: String?                 // 可选
    var notes: String?                      // 可选
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date
}
```

- 必填八字段指"结构上必须存在"，值可为 `nil`/空集合；可选四字段同样允许为空，缺失不视为错误。
- 电话拆成三个集合而非带 kind 的单一集合，直接对应 `mobile` / `officePhone` / `fax` 三个字段，避免 UI 与导出做二次映射。
- 号码与 Email 保留字面格式（分隔符、大小写），不做 E.164 归一化，保证"原文字面"口径；搜索与导出比较时才做数字/小写归一。
- Email 首元素为主地址；顺序来自原始文本出现顺序或人工输入顺序。

六段链路以伴随记录存放，不塞进可变字段：

```swift
struct CardAudit: Codable {
    var ocrRecords: [OCRRecord]          // 追加式；含 source、lines、status
    var parsedFields: StructuredFields    // 解析快照，只写一次
    var corrections: [FieldCorrection]    // 人工修改日志（字段、前值、新值、时间）
}
struct StructuredFields: Codable, Equatable {
    var name, company, jobTitle, website, address, department, postalCode: String?
    var mobile, officePhone, fax, email: [String]
    var notes: String?
}
```

### D3. 采集状态机

```
idle → capturing → captured(image)
     → detecting → detected(processed) | detectionFailed(reason, original)
     → ocrRunning → ocrFinished(record) | unrecognizable
     → parsing → readyForReview → saving → saved | savingFailed
     任意阶段 → abandoned（丢草稿、计数不变）
```

`CaptureFlowViewModel` 是唯一推进状态的地方；`CapturedImage` 与 `CardDraft` 均为纯值类型。重拍会新建一次 `captureSessionID`，旧草稿连同其临时文件一并丢弃。

### D4. 检测与方向校正

- `VNDetectRectanglesRequest`（`minimumConfidence = 0.5`、长宽比 1.4～1.8、`maximumObservations = 4`），按面积降序、再按与 1.58 的差值升序取唯一结果。
- `CIPerspectiveCorrection` 固定四角顺序（左上→右上→右下→左下）；方向用 `VNDetectTextRectanglesRequest` 的文本块角度中位数取最近的 90° 倍数，无文本块时取 0°，不猜测。
- 预处理将最长边限制在 3000 px；持久化统一 JPEG 0.9。
- 失败返回 `DetectionOutcome.failed(reason)`，UI 提供重试、手动框选、以原图继续三种分支。

### D5. OCR

`OCRServiceProtocol` 形如：

```swift
protocol OCRServiceProtocol {
    func recognize(image: CapturedImage, source: OCRSource) async -> OCRResult
}
```

- 真实实现 `VisionOCRService`：`.accurate`、`["zh-Hans","en-US"]`、`usesLanguageCorrection = false`（避免改写原文字面），逐行输出 text/confidence/normalizedBoundingBox。
- `MockOCRService` 以 JSON 文本行 fixture 返回固定结果，供 ViewModel 与 UI 测试注入，保证确定性。
- 每次执行追加 `OCRRecord(sequence:)`；输入优先 processedImage，缺失时用 originalImage 并记录 `source`。
- 空文本或失败返回 `.empty` / `.failed(reason)`，不产生任何猜测文本。

### D6. FieldParser（确定性）

`FieldParser.parse(_ record: OCRRecord) -> ParseResult` 是纯函数，固定顺序：

1. 行清洗：去首尾空白、丢弃纯标点噪声行，不改写字符。
2. 正则命中：Email（RFC 5322 子集）、网址（含 `www.` 与裸域名）、电话（含国家码与分隔符）。
3. 标签判定：`手机/Mobile/M/Cell` → mobile；`电话/Tel/T/Office/O/座机` → office；`Fax/传真/F` → fax；`Email/邮箱` → email；`Web/网址/URL` → website；`地址/Address` → address；`部门/Dept/Division` → department；`邮编/Zip/Postal Code` → postalCode。
4. 版式推断：最高且字号最大的非噪声行为 `name` 候选；其下第二组大字块为 `company` 候选；职位关键词（总经理/经理/总监/CEO/CTO/创始人/Engineer/Manager/Director）为 `jobTitle`。
5. 歧义：`company` 候选与 Email 域名或网址主机名做忽略大小写、忽略 `www.` 的包含匹配；失败则 `company` 与 `jobTitle` 置 `nil` 并标记 ambiguous。
6. 地址：地址标签行及其后连续且不含电话/Email/URL/邮编的行，按原顺序换行拼接；**不从地址推断邮编**，邮编只来自标签或独立邮编格式行。
7. 去重：同值 Email 仅保留一条（保留首次大小写），同值电话仅保留一条；顺序稳定。
8. 输出：十二字段 + 每个非空字段的 `FieldProvenance(confidence, sourceLineIDs, method)`；空字段无 provenance。

置信度是规则分值：标签+格式双命中 0.9，纯格式 0.85，版式推断 0.6，歧义 0.0 且值置空。实现中禁止 `Date`、随机数与 `Locale` 依赖，同输入同输出。

### D7. Review 与保存

- `ReviewViewModel` 维护 `[FieldKey: FieldDraft(value, source, parsedSnapshot)]`，电话与 Email 为可增删的数组条目。
- 来源枚举 `parsed / manual / unidentified`；编辑即置 manual，"恢复"读 `parsedSnapshot`，空快照回 `unidentified`。
- 保存校验：十二字段与标签全空则禁止保存；只填部门/备注也可保存。
- 保存时写 `FieldCorrection`、更新 `updatedAt`，保留 `createdAt` 与 `CardAudit.parsedFields`。
- 新建与编辑复用同一 `ReviewView` 与 `ReviewViewModel`。

### D8. Repository 与 ImageStore

```swift
protocol CardRepository {
    func load() async throws -> CardSnapshot
    func save(_ card: BusinessCard, audit: CardAudit, draft: CardDraft) async throws
    func update(_ card: BusinessCard, corrections: [FieldCorrection]) async throws
    func delete(id: UUID) async throws
    func reset() async throws
}
protocol ImageStore {
    func write(_ image: CapturedImage, id: UUID, kind: ImageKind) async throws -> ImageReference
    func read(_ ref: ImageReference) async throws -> Data?
    func delete(_ ref: ImageReference) async throws
}
```

- 真实实现 `FileCardRepository` 用 `store.json`（`schemaVersion`、cards、audits）与 `images/` 目录；`JSONEncoder` 固定 ISO8601、sortedKeys。
- 原子保存：图像先落盘 → 写 `store.json.tmp` → `replaceItemAt`；任一步失败清理本次新建文件，不产生半张名片。
- 删除：先提交不含该卡的索引，再删独占图像；`load()` 时清理孤儿文件，共享图像按引用计数保留。
- 路径存相对文件名，不存绝对路径。
- `InMemoryCardRepository` / `InMemoryImageStore` 供 ViewModel 与 UI 测试使用，并可注入写入失败以测试异常路径。

### D9. 导出

- `VCardExporter.export([BusinessCard]) -> String` 纯函数：`BEGIN:VCARD` / `VERSION:3.0` / `N`+`FN` / `ORG:公司;部门` / `TITLE` / `TEL;TYPE=CELL|WORK|FAX`（每类多值逐条）/ `EMAIL;TYPE=INTERNET`（首个加 `PREF`）/ `URL` / `ADR:;;地址原文;;;邮编;` / `CATEGORIES` / `NOTE`。
- 转义：`\`→`\\`、`;`→`\;`、`,`→`\,`、换行→`\n`；CRLF 行分隔，UTF-8 编码。
- 文件名：单张 `<姓名>.vcf`（清理 `/ : \ ? * " < > |`，空名回退 `名片.vcf`）；多张 `CamCard-Contacts-<yyyyMMdd-HHmmss>.vcf`。
- 写入临时文件 → `UIActivityViewController`；写入失败提示且不弹分享；空选择禁用导出；导出不触碰 Repository。
- `VCardParser` 仅在测试 target 使用，构成往返回归。

### D10. 依赖注入与可测试性

- `AppEnvironment` 持 `CardRepository`、`ImageStore`、`OCRServiceProtocol`、`CardDetectionService`、`FieldParser`、`Clock`，在 `CamCardApp` 创建并注入。
- 启动参数：`-uiTestResetStore`、`-uiTestSeedFixture <name>`、`-uiTestOCRFixture <name>`、`-uiTestSkipCamera`、`-uiTestForceExportFailure`。UI 测试用 Mock OCR 与注入 fixture 获得确定性，不依赖系统相机。
- 相机用 `UIImagePickerController(.camera)`，相册用 `PhotosPicker`（单张，忽略多选）。模拟器无相机，权限与取消路径用 `-uiTestSkipCamera` + 可注入的权限状态实现。

### D11. 测试口径

**确定性 20 个 Reference Test Scenarios（R01～R20，100% 必须通过）**

| ID | 场景 |
| --- | --- |
| R01 | 冷启动显示空名片夹（`Welcome content` 预期为名片夹首页，无 "Hello, world!"） |
| R02 | 相册导入成功进入处理流程，草稿不入夹 |
| R03 | 相机权限拒绝显示提示与"打开设置"，相册入口仍可用 |
| R04 | 取消采集返回名片夹且无草稿、计数不变 |
| R05 | 重拍丢弃旧草稿并重新检测 |
| R06 | 无法识别提示只给重拍/手动填写/取消，且不可直接保存 |
| R07 | 检测失败以原图继续，标记未校正 |
| R08 | 无 Website 时 `website == nil`，不得由 Email 域名虚构 |
| R09 | 多电话分类 Mobile/Office/Fax 且同类全部保留 |
| R10 | 多 Email 全部保留、首个为主 |
| R11 | 人工修改字段后来源变人工，恢复后回解析值 |
| R12 | 保存后名片夹首位出现且计数 +1 |
| R13 | 详情只显示有值字段，电话三组展示 |
| R14 | 编辑保存后计数不变、`createdAt` 不变 |
| R15 | 删除需确认；取消保留，确认后返回名片夹 |
| R16 | 搜索命中姓名/电话/Email/部门/邮编，清空恢复，无匹配显示独立状态 |
| R17 | 标签去重（trim、忽略空、大小写不敏感）与多标签 OR 筛选 |
| R18 | 多行备注保留换行；排序切换与恢复默认 |
| R19 | Kill-Relaunch 后六段链路完整且最终值不被覆盖 |
| R20 | 单张/多张 VCF 导出回环一致；空选择禁用；写入失败提示且不改数据 |

**概率性评价**

- `AccuracyHarness` 读取 `CamCardTests/Fixtures/cards/` 图像与 `ground-truth.json`，跑真实检测→OCR→FieldParser，输出 `accuracy-report.json`：逐字段 exact-match（电话按数字比较、Email 忽略大小写、文本去首尾空白）、检测成功率、单张耗时与环境信息（iOS 版本、设备、构建号）。
- 报告按字段列出，不用平均准确率掩盖任一字段的 0 分；与参考 App 的对照结果单独记录。
- OCR 不硬编码期望文本，只断言结构不变量（行数、坐标范围、source）。
- 每个 fixture 的原始输出 SHALL 落盘并随报告可追溯：检测四角、OCR 逐行文本/置信度/归一化坐标、处理图与原始图引用、解析十二字段；写入 `accuracy-report.json` 内嵌或引用 `CamCardTests/Fixtures/reports/` 下受版本控制的产物。
- 默认通过线（课程未给出门槛时使用，评审可调整）：检测成功率 ≥ 95%；八个必填字段逐字段 ≥ 90%；四个可选字段逐字段 ≥ 80%；任一字段准确率为 0 即判不通过。课程提供明确门槛时以课程为准。
- 概率性验收禁止使用"看起来合理"或与 CamCard 逐字符相等作为判据，只以固定测试集 Ground Truth 的字段级比对结果判定。

### D12. 工程配置

- 新增文件由同步组自动纳入；build settings 增加 `INFOPLIST_KEY_NSCameraUsageDescription` 与 `INFOPLIST_KEY_NSPhotoLibraryUsageDescription`。
- fixture 放 `CamCardTests/Fixtures/`，随同步组作为资源打包。
- 构建：`xcodebuild -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' build`。
- 测试：`xcodebuild test -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -only-testing:CamCardTests`；UI 场景用 `-only-testing:CamCardUITests`。

## Risks / Trade-offs

- **Vision 跨 OS 版本漂移** → 阈值与结构断言，不硬编码 OCR 文本；报告记录环境与版本。
- **模拟器无相机** → 权限/取消/重拍用可注入状态与 Mock 覆盖，真机项单独验收，未验证不勾选。
- **确定性解析召回有限** → 宁可 `nil` 交人工，用准确率报告量化召回缺口。
- **单 JSON 索引并发** → 所有写走同一 actor；UI 串行保存；临时文件替换避免半写。
- **图像内存** → 最长边 3000 px、JPEG 0.9、按需解码。
- **导出异常路径** → 注入失败 `VCardWriter` 与空选择 UI 测试覆盖。

## Migration Plan

- 新功能，`schemaVersion = 1`，无历史数据迁移；迁移分支仅为后续版本预留并有单测。
- 回滚：删除新增目录并还原 `ContentView` 注入即可；`store.json` 随 App 卸载清除。
- 主规格基线已存在（`openspec/specs/app-shell/spec.md` 仅描述 Hello World 骨架）；全部 R01～R20 与准确率报告齐备后才归档，届时 MODIFIED 才把名片夹首页写入主规格。

## Open Questions

- 课程测试集目录结构与 `ground-truth.json` schema 未提供：`AccuracyHarness` 需按实际格式适配，不影响契约与任务拆分。
- 参考 CamCard 版本号/构建号未确认：仅影响人工对照记录。
- 真机型号与 iOS 26 真机可用性未确认：影响相机相关验收，模拟器分支可先行。

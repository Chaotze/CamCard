# Proposal

## Why

当前工作区只有 Xcode 工程骨架：`CamCardApp` 进入单个 `ContentView`，页面内容是 "Hello, world!" 占位；`openspec/specs/` 为空，没有 OCR 服务、`BusinessCard` 模型、字段解析器、持久化层或 Reference Test Suite。需要从这一真实起点交付 CamCard「名片数字化与联系人管理」的完整闭环切片，而不是"拍照 → OCR → 显示一段文字"的演示。

现在进入提案阶段，是因为参考环境已按下表锁定（数值可复核），骨架可构建，后续契约可以建立在实际代码之上。

## Reference Environment（参考环境锁定记录）

| 项目 | 锁定值 | 依据 / 状态 |
| --- | --- | --- |
| 参考应用 | CamCard（名片全能王），仅对照名片数字化与联系人管理主链路 | 课程指定；**参考版本号/构建号待确认** |
| iOS 部署目标 | iOS 26.0 | [project.pbxproj](file:///Users/chaotze/Downloads/Mobile%20Application%20Development/CamCard/CamCard.xcodeproj/project.pbxproj#L324) `IPHONEOS_DEPLOYMENT_TARGET = 26.0` |
| 工具链 | Xcode 26.0 (17A324)，Swift 5.0，SwiftUI 生命周期 | 本机 `xcodebuild -version`；pbxproj `SWIFT_VERSION = 5.0` |
| 运行设备 | iPhone 17 Pro 模拟器（iOS 26.0） | `xcrun simctl list devices available`；**具体真机规格待确认** |
| Bundle ID | `cn.chaotze.CamCard` | pbxproj `PRODUCT_BUNDLE_IDENTIFIER` |
| 界面语言 | 简体中文；日期与数字按系统区域格式 | 课程默认；**如要求英文需确认** |
| 登录状态 | 免登录，无账号体系 | 本版不做注册/登录 |
| 免费功能范围 | 十项核心功能（见下）；付费功能一律不进入本版 | 课程第十五节 |
| 相机与相册权限 | 首次使用时弹系统授权；拒绝后提供手动输入/相册降级路径 | iOS 系统行为 |
| 测试素材 | 课程提供 30～50 张测试名片 + Ground Truth | **外部依赖，当前工作区缺失，需导入 `CamCardTests/Fixtures/`** |
| 网络 | 全程离线，不调用云 OCR、云同步或 CRM API | 本版范围 |

未确认项集中在参考 App 版本号与真机规格，不影响切片契约；在评审时一次性确认后再进入实施。

## What Changes

- 新增名片夹首页：初始为空名片夹（空状态 + 引导文案 + 拍摄/导入入口），替换现有 "Hello, world!" 空白首页。
- 新增相机拍摄与相册导入，拍/选后进入处理流水线；覆盖权限拒绝、取消、重拍、无法识别与导入失败。
- 新增名片区域检测：矩形区域定位、透视校正、方向校正，产出 `processedImage`；检测失败保留 `originalImage` 并允许重拍、重试或手动框选。
- 新增 OCR：在设备本地用 Vision 文本识别，产出不可变的 OCR Raw Text（保留每行文本、置信度、归一化坐标、源图像与失败状态）。
- 新增结构化解析：必填八字段 `name`、`company`、`jobTitle`、`mobile`、`officePhone`、`email`、`website`、`address`，可选四字段 `department`、`fax`、`postalCode`、`notes`；无法确认的字段返回 `nil`，禁止依据语义补全；多电话按 Mobile / Office / Fax 分字段承载且同类全部保留；多 Email 全部保留并标明首选项。
- 新增人工校正：逐字段编辑、字段级来源标记（解析 / 人工 / 未识别）、恢复解析原值、多电话与多 Email 增删、保存前校验。
- 新增保存与详情编辑：`BusinessCard` 落地本地存储，详情页展示原图与处理后图并只展示有值字段，支持进入编辑与删除。
- 新增搜索、标签与备注：按姓名/公司/职位/各类电话/Email/网站/地址/备注/标签搜索，标签去重与筛选，备注增删改。
- 新增本地持久化：App 重启（含 Kill-Relaunch）后列表、详情、标签、备注、图像完整保留；覆盖图像缺失、损坏、schema 版本与保存失败。
- 新增联系人导出：单张/多张名片导出为 `.vcf`（vCard 3.0），覆盖空选择、转义、非法文件名与写入失败等异常路径。
- 完整链路留痕：Original Image → Processed Image → OCR Raw Text → Structured Fields → Manual Correction → Final Contact，任一环节的产出不被后续环节覆盖。
- **不在本版范围**：注册/登录、会员、支付、广告、云同步、团队库、CRM/Salesforce 同步、数字名片模板设计、QR 交换、Email Signature、AI 企业情报、会议录音或总结。

## Capabilities

### New Capabilities

- `card-holder`: 名片夹首页、列表、空状态、排序与摘要。
- `scanner-capture`: 相机拍摄与相册导入的取图来源、权限拒绝、取消、重拍、无法识别与失败处理。
- `card-detection`: 名片区域检测、透视校正、方向校正、处理后图像产出与失败降级。
- `ocr-raw`: 设备端 OCR，产出不可变 Raw Text（文本行、置信度、归一化坐标）与源图像、失败记录。
- `field-extraction`: 八必填 + 四可选字段解析、字段级置信度、`nil` 缺失语义、多电话与多 Email、字段歧义策略与解析追溯。
- `review-correction`: 人工校正界面、字段来源标记、原始值恢复、多值与保存前校验。
- `card-detail-edit`: 保存后的名片详情、原图/处理后图查看、编辑入口与删除入口。
- `search-tag-notes`: 搜索、标签、备注、排序与多选。
- `persistence`: 本地存储 schema、图片文件存储、原子保存、Kill-Relaunch 一致性、迁移与损坏处理。
- `contact-export`: 单张/多张 vCard 3.0 导出、字段映射、系统分享、文件命名与导出异常处理。

### Modified Capabilities

- `app-shell`: Home screen 由 "Hello, world!" 骨架占位改为空名片夹首页，保留 `Cold launch`、`Relaunch`、`Welcome content`、`Navigation affordances`、`Rotation keeps content visible` 原场景标题并把预期更新为名片夹首页；`App shell navigation scope` 同步收紧为仅名片切片可达，`Supported orientations` 扩展为采集、校正、详情页均保持可用。

## Impact

- **代码**：新增 `CamCard/Models`、`CamCard/Repositories`、`CamCard/Services`（Detection/OCR/FieldParser/Export/ImageStore）、`CamCard/ViewModels`、`CamCard/Views`；替换 [ContentView.swift](file:///Users/chaotze/Downloads/Mobile%20Application%20Development/CamCard/CamCard/ContentView.swift)；扩展 [CamCardApp.swift](file:///Users/chaotze/Downloads/Mobile%20Application%20Development/CamCard/CamCard/CamCardApp.swift) 注入依赖容器。
- **工程文件**：三个 target 均为文件夹同步组，新增 Swift 文件与 fixture 自动纳入；只需在 build settings 增加 `INFOPLIST_KEY_NSCameraUsageDescription`、`INFOPLIST_KEY_NSPhotoLibraryUsageDescription`。
- **测试**：`CamCardTests` 新增 Schema/Repository/OCRService Mock/ImageStore/FieldParser/导出单测与 20 个确定性 Reference Test Scenarios；`CamCardUITests` 新增 20 条 UI 场景；`CamCardTests/Fixtures` 放入课程测试集与 Ground Truth。
- **依赖**：仅使用系统框架 Vision、AVFoundation、PhotosUI、CoreImage、UniformTypeIdentifiers、SwiftUI；不引入第三方库，不新增网络调用。
- **持久化**：应用沙盒内的本地索引 + 图像文件，不含云同步；卸载即清除。
- **验证口径**：确定性功能要求 20 个 Reference Test Scenarios 100% 通过；概率性能力用固定测试集 + Ground Truth 计算字段级准确率并保留六段链路供差异分析。

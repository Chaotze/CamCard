# 项目规则

1. 本次从真实起点开始：进入项目时应当只有 Xcode 工程骨架（App 入口 + 空白首页）与课程提供的 30～50 张测试名片及 Ground Truth；没有 OCRService、BusinessCard 模型、字段解析器、持久化层或 Reference Test Suite 实现。
2. 先读现行 app-shell 主规格与参考环境锁定记录（CamCard 版本、iOS 版本、设备规格、语言、登录状态、免费功能范围），再为"名片数字化与联系人管理"切片生成提案、Delta、设计和任务。未锁定参考环境不得进入提案阶段。
3. 新 capability（card-holder、card-capture、card-detection、card-ocr、card-field-extraction、card-verification、card-detail、card-management、card-persistence、card-export）一律用 ADDED Requirements；现有 Home / 空状态等 app-shell 行为用 MODIFIED，并携带完整场景。
4. 本版只复刻十项核心功能：名片夹首页、拍摄与图片导入、区域检测与校正、OCR、字段结构化、人工校正、保存与详情、搜索与标签备注、本地持久化、联系人导出。不实现注册、会员、订阅、广告、云同步、团队库、CRM/Salesforce 同步、数字名片设计、QR 交换、Email Signature、AI 企业情报、会议录音等第十五节列出的功能。
5. 必须形成端到端闭环：进入名片夹 → 拍摄/导入 → 区域识别与校正 → OCR → 字段结构化 → 人工校正 → 保存 → 详情 → 搜索/管理 → 重新打开 → 导出。禁止只交付"拍照 → OCR → 显示一段文字"的演示实现。
6. AI 不得虚构名片上不存在的信息。字段无法确认必须返回 nil 或空，不允许依据语义"合理补全" Website、电话、Email 等。多电话号码必须区分 Mobile / Office / Fax；字段歧义（如 Apple 是公司还是产品）必须按规格处理。
7. 必须保留完整数据链路：原始名片 → OCR Raw Text → Structured Fields → Manual Correction → Final Contact，供错误分析与量化评价使用。OCR 与字段解析的原始输出不得被最终结果覆盖。
8. 新建 Model / Repository / Service / ViewModel / View，核心数据模型与字段解析逻辑独立于 SwiftUI；OCR、检测、解析逻辑不得写进 View。BusinessCard Schema 至少包含 originalImage、processedImage、name、company、jobTitle、mobile、phone、email、website、address、tags、notes、createdAt。
9. 概率性功能（OCR、姓名/公司/职位/电话/Email/地址识别）用教师固定测试集 + Ground Truth 评价，计算字段级准确率并与参考 App 结果比较；确定性功能（UI、导航、状态、保存、编辑、删除、搜索、标签、导出）要求 Reference Test Suite 100% 通过。不得用平均准确率掩盖确定性用例失败。
10. 归档前主规格只能代表现有骨架与空状态；活动 Delta 给出待交付切片的契约。未归档前不得把 OCR、字段解析或持久化写入主规格。
11. 按任务和场景验证，禁止只生成界面、空返回值、伪造 OCR 结果或改测试预期掩盖问题。T01～T20 必须逐条有真实运行证据。
12. 真实运行的测试和构建才能勾选；核心 XCTest、iOS 构建、实际 UI 测试、手工验收、持久化 Kill-Relaunch 验证、导出字段映射验证分别记录命令与退出码。CLI 与 UI 验证受阻必须留待验证，不提前归档；不得因 UI 测试已编译而声称 UI 测试已执行。

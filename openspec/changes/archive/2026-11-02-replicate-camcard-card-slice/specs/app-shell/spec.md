# Spec Delta

## MODIFIED Requirements

### Requirement: App launches into the Home surface

应用 SHALL 启动进入单一 Home 界面，该界面占据整个应用窗口并展示名片夹。

#### Scenario: Cold launch

- **WHEN** 应用在全新安装且没有已保存名片的情况下启动
- **THEN** Home 界面为名片夹并显示其空状态，不呈现任何模态、sheet、引导或权限提示

#### Scenario: Relaunch

- **WHEN** 应用在名片已保存后被终止并再次启动
- **THEN** Home 界面显示名片夹，其中包含这些已保存名片，顺序与终止前相同

### Requirement: Home surface content

Home 界面 SHALL 展示名片夹：有名片时展示名片列表；没有名片时展示空状态，包含标题、说明以及“拍摄名片”和“从相册导入”操作。占位地球图标和“Hello, world!”文本 SHALL 不再出现。

#### Scenario: Welcome content

- **WHEN** 用户在没有已保存名片时打开 Home 界面
- **THEN** 显示空名片夹，且不显示地球图标或文本“Hello, world!”

#### Scenario: Welcome content with saved cards

- **WHEN** 用户在已有已保存名片时打开 Home 界面
- **THEN** 显示名片列表而非空状态，列表中没有混入占位内容

### Requirement: App shell navigation scope

应用外壳 SHALL 提供仅限于名片切片的导航：名片夹、拍摄入口、处理与校正流程，以及名片详情与编辑界面。它 SHALL NOT 暴露用于注册、会员、订阅、广告、云同步、团队库、CRM 同步、数字名片设计、二维码交换、电子邮件签名、AI 公司情报或会议录制的标签页、面板或路由。

#### Scenario: Navigation affordances

- **WHEN** 用户与 Home 界面交互
- **THEN** 搜索、标签筛选、排序、拍摄和照片导入均可到达，同时没有范围外功能入口可用

#### Scenario: Slice-only navigation

- **WHEN** 用户从启动导航到导出
- **THEN** 每个可到达界面都属于十项功能的名片切片

#### Scenario: Capture flow is reachable from Home

- **WHEN** 用户从 Home 界面触发拍摄或照片导入
- **THEN** 处理再校正流程作为导航目标呈现在名片夹之上，用户在保存或放弃后返回名片夹

#### Scenario: Detail opens over the card holder

- **WHEN** 用户点击名片行
- **THEN** 详情界面被推入覆盖在名片夹之上，返回导航回到同一列表状态

### Requirement: Supported orientations

应用 SHALL 支持 iPhone 上的竖屏、左横屏和右横屏，以及 iPad 上的全部四种方向，包括在拍摄、校正、详情和名片夹使用期间。

#### Scenario: Rotation keeps content visible

- **WHEN** 设备在名片夹、校正或详情界面打开时旋转到受支持方向
- **THEN** 当前界面保持可见，其内容在屏幕内布局

#### Scenario: Capture uses the camera orientation

- **WHEN** 用户在受支持的横屏方向拍摄名片
- **THEN** 生成的图像处理时不会丢失方向，且详情界面在旋转后仍可用

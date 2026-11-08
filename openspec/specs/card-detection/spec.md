# card-detection Specification

## Purpose

从采集图像中定位名片矩形区域，完成透视与方向校正，产出用于 OCR 的处理后图像，并在检测失败时给出可继续的降级路径。

## Requirements

### Requirement: Card region detection

对每一张采集图像，系统 SHALL 执行名片区域检测，并给出检测结果：成功时返回名片四角坐标，失败时返回明确的失败状态而不是空区域。检测成功后，处理界面 SHALL 在原图上展示检测到的四角区域，供用户确认检测是否正确。

#### Scenario: Single card detected

- **WHEN** 采集图像中只包含一张占比足够、边界完整的名片
- **THEN** 检测成功，返回四个角点，且四角围成的区域覆盖名片本体

#### Scenario: Detected region is shown

- **WHEN** 检测成功并进入处理界面
- **THEN** 处理界面在原图上显示由四个角点围成的名片区域，用户可据此判断检测结果是否正确

#### Scenario: No card found

- **WHEN** 采集图像中没有可识别的名片矩形
- **THEN** 检测返回失败状态，且不返回伪造的角点或全图区域

### Requirement: Multiple candidate selection

当检测到多个候选矩形时，系统 SHALL 以确定性规则选择一个结果：优先面积最大者；面积接近时选择长宽比最接近标准名片比例（约 1.58）的候选。

#### Scenario: Two cards in one photo

- **WHEN** 采集图像中同时存在两张清晰名片
- **THEN** 系统选中面积更大的那一张，而不是同时输出两个结果

#### Scenario: Repeated detection is stable

- **WHEN** 同一张采集图像被重复检测两次
- **THEN** 两次返回的角点与处理结果相同

### Requirement: Perspective correction

检测成功后，系统 SHALL 将名片四角映射到正面矩形，消除透视畸变，产出处理后图像。

#### Scenario: Skewed photo is rectified

- **WHEN** 名片以倾斜角度拍摄，四边形边界已成功检测
- **THEN** 处理后图像的上下边与左右边分别平行于图像边缘

#### Scenario: Rectified image keeps content

- **WHEN** 透视校正完成
- **THEN** 处理后图像包含名片全部内容，没有被裁掉的有效文本区域

### Requirement: Orientation correction

系统 SHALL 根据名片文字的排布方向将处理后图像旋转到正向，使文本基线水平、文字正立。

#### Scenario: Upside-down capture

- **WHEN** 名片在拍摄或导入时相对正向旋转 180 度
- **THEN** 处理后图像中的文字呈现正立方向

#### Scenario: Portrait-oriented capture

- **WHEN** 名片相对正向旋转 90 度或 270 度
- **THEN** 处理后图像被旋转回正向，文字从左到右可读

### Requirement: Only the final image is persisted

系统 SHALL 只持久化一张名片图像：校正成功时保存校正后的图像，校正失败或用户未执行区域校正时保存原始图像；草稿阶段可以同时持有原始图像与临时校正图像，但保存后不得同时保留两张。

#### Scenario: Rectified image is the saved image

- **WHEN** 检测与透视校正成功且用户保存名片
- **THEN** 名片只引用校正后的图像，不再单独持久化原始图像

#### Scenario: Correction failure saves the original

- **WHEN** 透视校正失败或用户以原图继续
- **THEN** 名片只引用原始图像，不产生第二张图像文件

### Requirement: Crop confirmation is always the first post-capture step

无论自动检测是否成功，采集图像 SHALL 先进入标题为"框选名片"的框选页面；自动检测成功时预填自动检测的四角，检测失败时预填默认四边形，用户确认后才执行校正与 OCR。

#### Scenario: Auto-detected corners are prefilled

- **WHEN** 采集图像后自动检测到名片区域
- **THEN** 系统直接打开"框选名片"页面，并以检测到的四角作为初始框选结果

#### Scenario: Detection failure still opens crop

- **WHEN** 采集图像后未能检测到名片区域
- **THEN** 系统仍打开"框选名片"页面，并以默认四边形作为初始框选结果，不显示多按钮的检测失败选择页

#### Scenario: Confirmed crop drives OCR

- **WHEN** 用户在"框选名片"页面调整四角并点击"下一步"
- **THEN** 系统以用户确认的四角执行透视校正，校正失败时回退为原图继续 OCR

### Requirement: Crop overlay uses a quadrilateral

框选页面 SHALL 使用按顺时针连接四个角点的四边形边框，不得出现交叉连线；边框与角点使用系统强调色，角点可拖动调整。

#### Scenario: Corners are drawn clockwise

- **WHEN** 框选页面显示自动检测或默认的四角
- **THEN** 四个角点按左上、右上、右下、左下顺序连接成闭合四边形，不出现对角线交叉

#### Scenario: Drag a corner

- **WHEN** 用户拖动任一角点
- **THEN** 该角点跟随手指移动，四边形实时更新，且坐标被限制在名片图像范围内

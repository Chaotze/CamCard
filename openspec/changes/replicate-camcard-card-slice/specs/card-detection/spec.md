# Spec Delta

## Purpose

从采集图像中定位名片矩形区域，完成透视与方向校正，产出用于 OCR 的处理后图像，并在检测失败时给出可继续的降级路径。

## ADDED Requirements

### Requirement: Card region detection

对每一张采集图像，系统 SHALL 执行名片区域检测，并给出检测结果：成功时返回名片四角坐标，失败时返回明确的失败状态而不是空区域。

#### Scenario: Single card detected

- **WHEN** 采集图像中只包含一张占比足够、边界完整的名片
- **THEN** 检测成功，返回四个角点，且四角围成的区域覆盖名片本体

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

### Requirement: Original and processed images are both retained

系统 SHALL 同时保留采集的原始图像与处理后图像，并在后续流程中允许两者分别访问；处理后图像不得替换原始图像。

#### Scenario: Both images available after detection

- **WHEN** 检测与校正完成
- **THEN** 该草稿同时可访问原始图像与处理后图像，且原始图像未被修改

#### Scenario: Detection failure keeps original only

- **WHEN** 检测失败
- **THEN** 草稿仍保留原始图像，并将处理后图像标记为不可用

### Requirement: Detection failure fallback

检测失败时，系统 SHALL 标记该草稿为检测失败，允许用户重试检测或手动框选名片区域，并允许以原始图像继续 OCR。

#### Scenario: Continue with original image

- **WHEN** 检测失败且用户选择继续
- **THEN** OCR 使用原始图像作为输入，界面明确提示未执行区域校正

#### Scenario: Retry detection

- **WHEN** 检测失败后用户选择重试
- **THEN** 系统对同一原始图像重新执行检测，且不覆盖先前的失败记录

#### Scenario: Manual crop

- **WHEN** 检测失败后用户手动框选名片区域
- **THEN** 系统以用户框选的四角作为检测结果，并产出对应的处理后图像

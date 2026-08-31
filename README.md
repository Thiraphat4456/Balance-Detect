# Balance Detect

Balance Detect เป็นแอป Flutter สำหรับประเมินการทรงตัวและคัดกรองความเสี่ยงต่อการล้มเบื้องต้นบน Android ผ่านแบบทดสอบ 3 แบบ:

- Functional Reach Test — กล้อง + pose landmarks + anthropometric height calibration
- Fullerton Advanced Balance Scale (MVP reach task) — กล้อง + temporal step detection
- Timed Up and Go (TUG) — accelerometer + gyroscope + motion state machine

แอปไม่สร้างผลจำลอง ผลที่บันทึกต้องมาจาก camera/sensor workflow จริง และผลที่ขาดความสมบูรณ์จะถูกหยุดพร้อมเหตุผลโดยไม่บันทึกเป็นผลสุขภาพปกติ

## สถานะโครงการ

โค้ดเป็น Android MVP/prototype ที่เชื่อม native camera, ML Kit, accelerometer, gyroscope และ SQLite จริงแล้ว Business logic ผ่าน automated tests และ Android build สามารถตรวจได้ด้วยคำสั่งด้านล่าง แต่ความแม่นยำของ computer vision และ motion thresholds ยังต้องทดสอบ/เก็บข้อมูลบนโทรศัพท์จริงหลายรุ่นและ validate เทียบ protocol มาตรฐานก่อนใช้งานภาคสนาม

## Toolchain

- Flutter 3.44.0 stable
- Dart 3.12.0
- Android minSdk 24
- Android application ID: `com.balancedetect.app`
- JDK 17+ (environment ที่ใช้พัฒนาใช้ Android Studio JDK 21)

## Architecture

โปรเจกต์ใช้ feature-first architecture โดยแยก UI, domain logic, hardware integration และ persistence:

```text
lib/
  app/                         MaterialApp/router entry
  core/
    constants/                 threshold และ algorithm configuration
    database/                  SQLite schema/opening
    domain/                    shared enums และ validity states
    errors/                    user-facing error boundary
    logging/                   structured event logs
    providers/                 Riverpod dependency/state boundary
    routing/                   GoRouter + bottom navigation 3 แท็บ
    theme/                     healthcare accessibility theme
    utils/                     units, IDs, date formatting
    widgets/                   reusable UI/accessibility components
  features/
    assessment/                sessions, calibration, repository contract
    assessment_summary/
    functional_reach/          calibration, reach measurement, state/UI
    fullerton/                 step detection, scoring, state/UI
    tug/                       sensors, calibration, filtering, analyzer, state/UI
    pose/                      pose domain, validation, Camera/ML Kit adapter
    home/ history/ profile/
```

Business rules ไม่อยู่ใน Widget และ state transition ถูกจำกัดด้วย state machine ที่ test แยกได้ Hardware services มี interface boundary เพื่อรองรับ implementation สำหรับ iOS หรือ detector อื่นในอนาคต

## Dependencies และเหตุผลที่เลือก

ตรวจ compatibility กับ Flutter/Dart toolchain ก่อนเพิ่ม และเลือก package ที่ยัง active ณ วันที่สร้างโปรเจกต์:

- `camera` — official Flutter plugin; camera preview และ image stream พร้อม CameraX บน Android
- `google_mlkit_pose_detection` — pose landmarks แบบ realtime ผ่าน native ML Kit; ทำงาน native ไม่ block Dart UI thread
- `sensors_plus` — maintained Flutter Community plugin สำหรับ accelerometer/gyroscope stream พร้อม timestamp และ sampling period
- `sqflite` — local SQLite ที่เสถียรสำหรับ Android/iOS; data ยังคงอยู่หลังปิดแอป
- `flutter_riverpod` — dependency/state boundary ที่ test ได้และเหมาะกับ feature-first project
- `go_router` — official Flutter declarative router และ indexed shell สำหรับ bottom navigation
- `flutter_tts` — maintained cross-platform Text-to-Speech plugin ใช้ประกาศคำแนะนำภาษาไทยระหว่างจัดตำแหน่งกล้องและนับถอยหลัง hands-free; เลือกแทนการเขียน Android platform channel เองเพื่อรองรับ iOS/แพลตฟอร์มอื่นภายหลัง
- `permission_handler` 12.0.3 — runtime camera permission, permanent-denial handling และเปิด app settings; pin รุ่นนี้เพราะ 13.x ที่เพิ่งออกต้อง compileSdk 37 ขณะที่ Flutter 3.44 template/AGP 9.0.1 รองรับ compileSdk แนะนำสูงสุด 36
- `path` — ประกอบ database path โดยไม่อาศัย transitive import

Exact resolved versions อยู่ใน `pubspec.lock` การอัปเกรด camera/ML Kit/sensor package ต้อง build และทดสอบบนอุปกรณ์จริงใหม่เสมอ เพราะ native image format, orientation และ sensor behavior อาจเปลี่ยนได้

## Setup และ Run Android

1. ติดตั้ง Flutter stable, Android Studio/Android SDK และ JDK ที่ Flutter รองรับ
2. ตรวจ environment:

   ```powershell
   flutter doctor -v
   flutter doctor --android-licenses
   ```

3. ติดตั้ง dependencies:

   ```powershell
   flutter pub get
   ```

4. เชื่อม Android phone ที่เปิด USB debugging แล้วตรวจว่าเห็น device:

   ```powershell
   flutter devices
   ```

5. Run:

   ```powershell
   flutter run -d <device-id>
   ```

6. Build APK:

   ```powershell
   flutter build apk --debug
   ```

Release block ปัจจุบันใช้ debug signing เพื่อ controlled prototype testing เท่านั้น ต้องตั้ง private release keystore และนโยบายข้อมูลก่อน distribution

## Permissions และ Hardware

Android manifest ประกาศ `CAMERA` permission และระบุ camera, accelerometer, gyroscope เป็น optional hardware feature เพื่อให้แอปติดตั้งได้แม้อุปกรณ์ขาด sensor บางตัว จากนั้น workflow ตรวจ availability จริงและแจ้งข้อผิดพลาดภาษาไทยแทนการ crash

- Camera ถูกขอเมื่อเริ่ม camera assessment หาก deny จะแสดงเหตุผลและปุ่มลองใหม่
- หาก deny แบบถาวร จะแสดงปุ่มเปิด app settings
- Accelerometer/gyroscope บน Android ไม่ต้อง runtime permission แต่ระบบ probe stream จริงก่อนเริ่ม TUG
- หน้าจอจะไม่ดับตั้งแต่เข้าหน้าทดสอบจริง ระหว่างจัดตำแหน่ง ปรับเทียบ นับถอยหลัง และวัดผลของทั้ง 3 แบบ จากนั้นคืนค่าปกติเมื่อเสร็จสิ้น ผลเป็น invalid/error หรือออกจากหน้า
- ทุก camera/sensor subscription, image stream และ native pose detector ถูกหยุด/ปิดเมื่อจบ ออกจากหน้า เกิด error หรือ app ถูกพัก
- หาก app pause, screen lock หรือ interruption เกิดระหว่าง assessment ระบบ mark attempt เป็น invalid และไม่ทำต่อเงียบ ๆ

สำหรับ iOS ในอนาคต ให้ generate iOS platform บน macOS, เพิ่ม `NSCameraUsageDescription` และ `NSMotionUsageDescription`, ตรวจ image rotation/BGRA mapping และ validate sensor thresholds แยกตามอุปกรณ์ โครงสร้าง domain/service ไม่ผูกกับ Android แต่ repository นี้ generate platform Android เท่านั้นใน MVP ปัจจุบัน

## Functional Reach Algorithm

Workflow:

```text
positioning → calibrating → baseline → ready → reaching → completed
                                  ↘ invalid/error
```

1. CameraX ส่ง NV21 medium-resolution image stream เข้า ML Kit base pose model
2. มี backpressure: ประมวลผลทีละเฟรม และ throttle ตามค่ากลางใน `AssessmentConfig`
3. Pose validation ตรวจ shoulder, elbow, wrist, hip, knee, ankle, heel, foot index, confidence และ side-view geometry; ใน Functional Reach ด่านจัดตำแหน่งใช้ไหล่–ข้อศอกเป็นหลัก และข้อมือจะถูกขอเฉพาะก่อนวัดระยะจริง
4. Intro ขอส่วนสูงผู้ทดสอบเป็นเซนติเมตรก่อนเปิดกล้อง
5. หลังจัดตำแหน่ง ระบบเก็บ shoulder-to-ankle span หลายเฟรม แล้วใช้ anthropometric prior ใน `AnthropometricHeightCalibrationService` ประมาณสเกลจากส่วนสูงที่กรอก พร้อมชดเชยอัตราส่วนกว้าง/สูงของภาพก่อนนำสเกลแนวตั้งมาใช้กับระยะเอื้อมแนวนอน
6. `CalibrationRecord` เก็บ `anthropometricBodyHeight`, ส่วนสูงอ้างอิง, scale, timestamp และ confidence; `ExplicitDistanceCalibrationService` ยังอยู่ใน domain สำหรับ fallback/การทดลองที่ต้องการวัตถุอ้างอิง
7. ก่อนเก็บ baseline ผู้ทดสอบยกเฉพาะแขนฝั่งกล้อง กำมือ และปล่อยแขนอีกข้างไว้ข้างลำตัว ระบบตรวจไหล่–ข้อศอกเพื่อจัดท่าก่อน และเมื่อเริ่มวัดจะขอให้ข้อมือฝั่งกล้องอยู่ในกรอบเพื่อคำนวณระยะ จากนั้นคำนวณมุม hip-shoulder-elbow และ shoulder-elbow-wrist โดยชดเชยอัตราส่วนภาพ รอให้ต้นแขนอยู่ใกล้ 90 องศาและข้อศอกเหยียด พร้อม checklist/เสียงบอกให้ยกแขน ลดแขน หรือเหยียดข้อศอก (โมเดล pose ไม่มีจุดนิ้วมือและไม่ใช้แขนฝั่งถูกบัง จึงแนะนำแต่ไม่อ้างว่าตรวจสองเงื่อนไขนั้นได้)
8. ล็อกข้างของแขนที่ใช้วัดจากเฟรมแรกที่ท่าผ่าน แล้วใช้ข้อมือข้างเดิมตลอด baseline และช่วงเอื้อม เพื่อไม่ให้ confidence ที่สลับซ้าย/ขวาทำให้ตำแหน่งกระโดด
9. เก็บ wrist/feet baseline หลายเฟรมมากกว่า 2 วินาที ตรวจ maximum jitter ก่อนยอมรับ หากท่าแขนหลุดระหว่างเก็บ baseline จะล้างตัวอย่างเดิมและเริ่มเก็บใหม่
10. ช่วง reach ใช้ moving average ของ wrist และคำนวณ horizontal displacement จาก baseline ผ่าน calibration scale
11. เก็บค่าสูงสุดตลอด assessment window ไม่ใช้ค่าของเฟรมสุดท้าย
12. ติดตาม midpoint ของ heel + foot index ซึ่งเป็น planted-foot anchor ที่มีองค์ประกอบคงที่ ไม่นำ ankle joint ที่เคลื่อนตามการเอนตัวมานับเป็นการก้าวเพียงลำพัง จากนั้นทำ smoothing ใช้ noise floor ที่ปรับตามสเกลภาพ ชดเชยการเลื่อนทั้งโครงด้วยสะโพก และต้องมีการเคลื่อนของข้อเท้ารองรับ heel/toe ต่อเนื่องหลายเฟรมจึงเป็น invalid จึงไม่ตัดสินจาก pose drift ของจุดเดียว
13. เก็บ metric (`distanceCm`) เป็นหลัก แล้วค่อยแปลง `inch = cm / 2.54`
14. Classification: `< 7.0 inch = warning`, `>= 7.0 inch = normal`
15. ระหว่าง positioning ระบบพูดคำสั่งที่เปลี่ยนตาม validation (เช่น ถอยออก, ขยับกล้องลง, หันด้านข้าง) โดย throttle ไม่ให้พูดซ้ำถี่เกินไป เมื่อพร้อมแล้วจะแจ้งเสียงและนับ 3–2–1 เพื่อเข้าสู่ขั้นตอนถัดไปเอง ไม่ต้องกดปุ่มเริ่ม

Explicit reference calibration ยังมี perspective/parallax error ได้ วัตถุอ้างอิงต้องอยู่ระนาบเดียวกับร่างกายและห้ามขยับกล้องหลัง calibration

## Fullerton MVP Algorithm

MVP ครอบคลุม reach task ตาม scoring ที่กำหนด ไม่ใช่ Fullerton scale ทุก item

1. ตรวจ body/arm/feet landmarks และเก็บ foot baseline หลายเฟรม
2. `StepDetectionService` ใช้ foot center จาก ankle + heel + foot index
3. Threshold ปรับตาม foot length โดยมี minimum normalized displacement
4. ต้องเคลื่อนต่อเนื่องหลายเฟรมจึงยืนยัน step และมี refractory/debounce period เพื่อไม่ให้นับ step เดียวซ้ำ
5. เมื่อ `stepCount == 0` แอปถามผู้ประเมินเรื่อง supervision แทนให้กล้องตัดสิน
6. หลังจัดตำแหน่งและหลังเก็บ baseline ระบบใช้เสียง + countdown เพื่อเริ่มขั้นถัดไปเอง ลดการต้องกดปุ่มขณะผู้ทดสอบอยู่ห่างจากโทรศัพท์

Pure scoring function:

```text
0 steps + no supervision → 4
0 steps + supervision    → 3
1 step                    → 2
2 steps                   → 1
>2 steps                  → 0
```

ถ้า pose lost หรือ temporal confidence ต่ำจะเป็น invalid และไม่บันทึกเป็นผลปกติ

## TUG Sensor Pipeline

```text
Raw accelerometer + gyroscope
  → timestamp synchronization (≤100 ms gap)
  → 3-second resting calibration
  → gravity vector / gyro bias / noise validation
  → exponential noise filtering
  → dynamic acceleration + angular features
  → temporal motion detection
  → TUG state machine
  → monotonic elapsed timestamps
```

State sequence:

```text
idle → calibrating → ready → sitting → standingUp → walkingOut
     → turning → walkingBack → sittingDown → completed
```

- Sit-to-stand ใช้ acceleration และ angular velocity หลาย sample/window ไม่ใช้ sample เดียว
- Walking ใช้ filtered dynamic acceleration หลัง stand transition
- Turn ใช้ angular velocity รอบแกน gravity และ integration ตามเวลา ก่อนเปลี่ยนเป็น walking back
- Sit-down ต้องพบ motion transition หลัง return phase แล้วตามด้วย quiet window และ gravity magnitude ที่สมเหตุสมผล
- Timer เริ่มหลัง countdown ที่ sensor sample แรกและหยุดอัตโนมัติเมื่อ state `completed`; ใช้ `Stopwatch`/event elapsed duration ไม่ใช้ UI frames
- หลังผู้ใช้กดปรับเทียบครั้งเดียว ระบบพูดขั้นตอน TUG ภาษาไทย รอช่วงอธิบาย นับถอยหลัง 3–2–1 และเริ่ม sensor stream อัตโนมัติ จากนั้นประกาศเมื่อพบการลุก เดินออก หมุน เดินกลับ นั่งลง ผลรวม และเหตุที่ต้องหยุด โดยมีปุ่มเปิด–ปิดเสียงทุกหน้า
- มี timeout 60 วินาทีและปุ่มยกเลิกฉุกเฉิน ทั้งสองกรณีไม่สร้างผลปกติ
- Classification: `> 13.5 seconds = risk`, `<= 13.5 seconds = normal`
- Phase durations จะแสดงและบันทึกเฉพาะเมื่อ confidence ถึงเกณฑ์ หากไม่ถึงจะแสดงเฉพาะ total time โดยไม่สร้างค่า phase ปลอม

Threshold เหล่านี้เป็น prototype configuration ไม่ใช่โมเดลที่ผ่าน clinical validation

## Persistence

SQLite schema มี:

- `patient_profiles`
- `assessment_sessions`
- `calibration_records`
- `functional_reach_results`
- `fullerton_results`
- `tug_results`

ใช้ foreign keys และ cascade cleanup ระหว่าง session/result ข้อมูล `DateTime` เก็บเป็น epoch milliseconds และ boolean เก็บเป็น SQLite integer ตามชนิดข้อมูลที่ SQLite รองรับ History เรียงล่าสุดก่อนและ detail/summary อ่านจาก repository จริง

## Validity และ Error Handling

แต่ละ result model มี `valid`, `invalidReason`, `confidence` และ threshold/method ที่เกี่ยวข้อง Error ที่ครอบคลุมได้แก่ pose lost, calibration failed, foot moved, step confidence low, sensor unavailable, unexpected motion, interruption, invalid state sequence และ timeout UI ไม่แสดง stack trace และ invalid attempt ไม่ถูกสรุปเป็น “ปกติ”

Structured logs ใช้ event JSON ผ่าน `dart:developer` เช่น `pose_acquired`, `calibration_success`, `reach_started`, `reach_peak`, `foot_movement_detected`, `fullerton_step_detected`, `tug_*_detected` โดยไม่ log ชื่อ อายุ หรือหมายเหตุของผู้ทดสอบ

## Debug Mode

ใน debug build หน้า Profile มี switch เปิด developer overlay:

- Camera: FPS, pose confidence, wrist/foot movement, calibrated reach
- TUG: raw accelerometer/gyroscope, current state, dynamic acceleration, angular velocity

Overlay ปิดเป็นค่าเริ่มต้น และ control นี้ไม่แสดงใน production build (`kDebugMode`)

## Accessibility

- ปุ่มหลักสูงอย่างน้อย 56 logical pixels
- body text 16–18 px และ heading 21–28 px
- Material text scaling ทำงานตาม system setting
- high-contrast status colors มี icon และข้อความกำกับเสมอ
- semantic labels สำหรับ illustration, status และ threshold visualization
- ไม่มี gesture ซับซ้อน การ calibration, baseline และ countdown ทำงานต่อเนื่องโดยไม่ต้องเดินกลับมากดเริ่ม
- live test ลดข้อมูลเหลือ state, เวลา/ระยะ และ emergency action

## Tests และ Quality Commands

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Automated tests ครอบคลุม:

- centimeter ↔ inch conversion
- Functional Reach boundary 6.99 / 7.00 / 8.00
- Fullerton score ทุก case ที่กำหนดและ evaluator requirement
- TUG boundary 13.4 / 13.5 / 13.6 / 20.0
- Functional Reach, Fullerton และ TUG state transitions/invalid transitions
- stable multi-frame reach baseline, aspect-ratio correction, landmark-jitter rejection และ sustained foot invalidation
- temporal step confirmation
- sensor resting calibration และ insufficient samples
- invalid session summary
- app splash smoke test

## Known Limitations / Medical and Research Notice

- แอปนี้เป็น prototype / screening tool ไม่ใช่อุปกรณ์การแพทย์และไม่วินิจฉัยโรค
- ค่า threshold 7 นิ้วและ 13.5 วินาทีมาจาก requirement ของโครงการ ไม่ได้ทำให้อัลกอริทึมนี้เป็น clinically validated implementation โดยอัตโนมัติ
- ML Kit landmark accuracy แปรตามแสง เสื้อผ้า มุมกล้อง body occlusion และรุ่นอุปกรณ์
- Explicit reference calibration แปรตาม perspective, reference placement และการขยับกล้อง ต้องพัฒนาวิธี calibration/validation ที่ควบคุมมากขึ้นสำหรับงานวิจัย
- Anthropometric height calibration ใน MVP ใช้ shoulder-to-ankle span และ fraction ที่กำหนดใน `AssessmentConfig` เป็น prior ไม่ใช่การวัดส่วนสูงโดยตรง จึงยังมี error จากสัดส่วนบุคคล มุมกล้อง การเอนตัว และการบัง landmark; ต้อง validate เทียบกับไม้บรรทัด, RGB-D หรือ motion-capture ก่อนใช้แทน explicit reference ในงานคลินิก
- Functional Reach foot detector ตั้งใจยืนยันเฉพาะการเคลื่อนที่ที่ชัดและต่อเนื่องเพื่อทนต่อ ML Kit landmark jitter จึงต้องเก็บข้อมูลจริงเพื่อประเมินทั้ง false-positive และ false-negative ก่อนกำหนด threshold ทางคลินิก
- เกณฑ์ท่าเริ่มต้น 75-105 องศาที่หัวไหล่และอย่างน้อย 150 องศาที่ข้อศอกเป็น tolerance สำหรับ computer vision ไม่ใช่ clinical cutoff ต้อง validate กับวิดีโอที่มีผู้เชี่ยวชาญกำกับก่อนใช้คัดกรองจริง รายละเอียดการทบทวน prior art อยู่ใน `docs/external-implementation-review.md`
- Fullerton step detector เป็น temporal prototype และ MVP นี้ประเมิน reach task เดียว ไม่ใช่ Fullerton Advanced Balance Scale ฉบับเต็ม
- TUG motion detector ต้องเก็บ labeled sensor data จากผู้ใช้จริงหลายรูปร่าง รูปแบบการเดิน ตำแหน่งโทรศัพท์ และรุ่นอุปกรณ์ เพื่อ tune/validate sensitivity และ specificity
- Automated tests ยืนยัน business rules และ deterministic algorithms แต่ไม่ทดแทน camera/sensor integration test บน physical phone
- ก่อนใช้ทางคลินิกต้องทำ protocol validation, usability/safety review, data governance/privacy review และ regulatory assessment ที่เกี่ยวข้อง

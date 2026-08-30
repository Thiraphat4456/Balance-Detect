abstract final class FunctionalReachInstructions {
  static const positioningVoice =
      'ตั้งโทรศัพท์ให้เห็นร่างกายตั้งแต่ศีรษะถึงเท้าทั้งสองข้าง '
      'แล้วหันลำตัวด้านข้างเข้าหากล้อง '
      'เมื่อถึงขั้นจัดท่า ให้ยกเฉพาะแขนฝั่งที่หันเข้ากล้องไปด้านหน้า '
      'กำมือ เหยียดข้อศอก และปล่อยแขนอีกข้างไว้ข้างลำตัว '
      'ช่วงจัดท่าระบบตรวจไหล่ถึงข้อศอกก่อน';

  static const calibratedVoice =
      'คำนวณสเกลแล้ว ยกเฉพาะแขนฝั่งที่หันเข้ากล้องไปด้านหน้า '
      'ให้ต้นแขนตั้งฉากกับลำตัว กำมือ เหยียดข้อศอก และอยู่นิ่ง '
      'ปล่อยแขนอีกข้างไว้ข้างลำตัว ช่วงวัดจริงให้ข้อมือฝั่งกล้องอยู่ในกรอบ';

  static const introSetup =
      'ยืนด้านข้างกล้อง ให้แขนข้างที่จะใช้ทดสอบอยู่ฝั่งกล้อง '
      'ยกแขนข้างนั้นไปด้านหน้าให้ต้นแขนตั้งฉากกับลำตัว '
      'กำมือ และปล่อยแขนอีกข้างไว้ข้างลำตัว '
      'การจัดท่าใช้จุดไหล่ถึงข้อศอก ส่วนช่วงวัดต้องเห็นข้อมือ';

  static const baselineDetail =
      'ยกเฉพาะแขนฝั่งกล้องไปด้านหน้า อีกแขนปล่อยไว้ข้างลำตัว';

  static const baselinePrompt =
      'ยกเฉพาะแขนฝั่งกล้องไปด้านหน้า ให้ต้นแขนตั้งฉากกับลำตัว '
      'กำมือ เหยียดข้อศอก และปล่อยแขนอีกข้างไว้ข้างลำตัว '
      'ให้ข้อมือฝั่งกล้องอยู่ในกรอบเพื่อวัดระยะ';

  static const readyPrompt =
      'ยกเฉพาะแขนฝั่งกล้องไปด้านหน้า ระบบตรวจแขนข้างนี้เพียงข้างเดียว';

  static const setupLandmarksPrompt =
      'จัดให้กล้องเห็นหัวไหล่และข้อศอกฝั่งกล้องให้ชัด';

  static const reachPointPrompt =
      'ท่าแขนถูกแล้ว ให้ข้อมือฝั่งกล้องอยู่ในกรอบเพื่อคำนวณระยะเอื้อม';

  static const raiseTrackedArm =
      'ยกแขนฝั่งกล้องไปด้านหน้า ให้ต้นแขนตั้งฉากกับลำตัว '
      'ไม่ต้องยกสูงกว่าระดับไหล่';

  static const lowerTrackedArm =
      'ลดแขนฝั่งกล้องลงเล็กน้อย ให้ต้นแขนตั้งฉากกับลำตัว';

  static const extendTrackedElbow = 'เหยียดข้อศอกฝั่งกล้องให้ตรง แล้วอยู่นิ่ง';

  static const trackedArmReady =
      'ท่าแขนฝั่งกล้องพร้อมแล้ว อยู่นิ่ง ระบบกำลังเก็บตำแหน่งเริ่มต้น';

  static const allSingleArmPrompts = <String>[
    positioningVoice,
    calibratedVoice,
    introSetup,
    baselineDetail,
    baselinePrompt,
    readyPrompt,
    setupLandmarksPrompt,
    reachPointPrompt,
    raiseTrackedArm,
    lowerTrackedArm,
    extendTrackedElbow,
    trackedArmReady,
  ];
}

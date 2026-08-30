abstract final class FunctionalReachInstructions {
  static const positioningVoice =
      'ตั้งโทรศัพท์ให้เห็นร่างกายตั้งแต่ศีรษะถึงเท้าทั้งสองข้าง '
      'แล้วหันลำตัวด้านข้างเข้าหากล้อง '
      'เมื่อถึงขั้นจัดท่า ให้ยกเฉพาะแขนฝั่งที่หันเข้ากล้องไปด้านหน้า '
      'กำมือ เหยียดข้อศอก และปล่อยแขนอีกข้างไว้ข้างลำตัว';

  static const calibratedVoice =
      'คำนวณสเกลแล้ว ยกเฉพาะแขนฝั่งที่หันเข้ากล้องไปด้านหน้า '
      'ให้ต้นแขนตั้งฉากกับลำตัว กำมือ เหยียดข้อศอก และอยู่นิ่ง '
      'ปล่อยแขนอีกข้างไว้ข้างลำตัว';

  static const introSetup =
      'ยืนด้านข้างกล้อง ให้แขนข้างที่จะใช้ทดสอบอยู่ฝั่งกล้อง '
      'ยกแขนข้างนั้นไปด้านหน้าให้ต้นแขนตั้งฉากกับลำตัว '
      'กำมือ และปล่อยแขนอีกข้างไว้ข้างลำตัว';

  static const baselineDetail =
      'ยกเฉพาะแขนฝั่งกล้องไปด้านหน้า อีกแขนปล่อยไว้ข้างลำตัว';

  static const baselinePrompt =
      'ยกเฉพาะแขนฝั่งกล้องไปด้านหน้า ให้ต้นแขนตั้งฉากกับลำตัว '
      'กำมือ เหยียดข้อศอก และปล่อยแขนอีกข้างไว้ข้างลำตัว';

  static const readyPrompt =
      'ยกเฉพาะแขนฝั่งกล้องไปด้านหน้า ระบบตรวจแขนข้างนี้เพียงข้างเดียว';

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
    raiseTrackedArm,
    lowerTrackedArm,
    extendTrackedElbow,
    trackedArmReady,
  ];
}
